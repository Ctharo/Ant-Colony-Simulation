extends Control
## Behavior Builder — node-graph "do ACTION if CONDITION" prototyping UI.
##
## Interactions:
##   • Right-click empty graph space          → add-node menu
##   • Right-click a node                     → node menu (debug copy, unpack, ...)
##   • Drag port → port                       → wire (one wire per input; new wire replaces)
##   • Drag a wire into empty space           → add-node menu; the chosen node auto-attaches to the wire
##   • Drag a node ON TOP of another node     → auto-compose (connects to a free input)
##   • WASD / arrow keys                      → pan the grid (disabled while typing in a field)
##   • Box-drag / Ctrl+click                  → multi-select
##   • Selecting a ◈ condition                → highlights every other reference to it (gold)
##   • Ctrl+G                                 → save selection as a named, reusable condition or value
##   • Ctrl+Shift+C                           → copy debug JSON of selection
##   • Ctrl+C / Ctrl+V / Ctrl+D / Delete      → copy / paste / duplicate / delete
##   • + on a condition node                  → expand an organized list of its contents
##   • ⤢ on a condition node                  → unpack into editable nodes (Ctrl+G re-saves, name pre-filled)
##   • ⧉ on any node                          → copy that node's debug JSON

var world := BBWorldState.new()
var library := BBConditionLibrary.new()

var graph: GraphEdit
var status: Label
var lib_list: ItemList
var add_menu: PopupMenu
var node_menu: PopupMenu
var name_dialog: ConfirmationDialog
var name_edit: LineEdit
var overwrite_dialog: ConfirmationDialog
var _overwrite_name := ""
var _suppress_cancel := false

var settings: BBBuilderSettings = BBBuilderSettings.new()
var _last_show_grid: bool = true
var _last_snapping: bool = true

var _uid := 0
var _dirty := false
var _cycle_warned := false
var _menu_graph_pos := Vector2.ZERO
var _pending_conn := {}
var _pending_save := {}
var _clipboard := {}
var _ctx_node: BBNode = null
var _toast_tween: Tween
## Name of the condition most recently unpacked — pre-fills the save dialog
## so re-saving under the same name is one Enter away.
var _last_unpacked_name := ""
## True when any ⏱ timer node exists (graph or library) — enables the
## periodic re-evaluation tick so holds expire visibly.
var _has_timers := false
var _timer_accum := 0.0

const PAN_SPEED := 900.0

## [label, node type, params]
const ADD_ITEMS: Array[Array] = [
	["Ant value  (health, energy, …)", "world_value", {"group": "ant"}],
	["World value  (distances, pheromones, …)", "world_value", {"group": "world"}],
	["Constant", "constant", {}],
	["Compare  (\"value is less than 30\" → true/false)", "compare", {}],
	["Math  (\"value divided by 100\" → number)", "math", {}],
	["AND", "and", {}],
	["OR", "or", {}],
	["NOT", "not", {}],
	["⏱ Hold true  (timer)", "timer", {}],
	["⚡ Behavior (fires when true)", "behavior", {}],
	["👁 Sense  (list of ants / food)", "sense_list", {}],
	["Filter list  (keep items where …)", "filter", {}],
	["Sort list  (by distance, health, or a ◈ value)", "sort", {}],
	["Pick from list  (nearest / farthest / first)", "pick", {}],
	["Item value  (read distance / health / … of a picked item)", "item_value", {}],
	["Count list  (→ number)", "list_count", {}],
]


func _ready() -> void:
	settings.load_from_disk()
	library.load_from_disk()
	_build_ui()
	var _err_lib: Error = library.changed.connect(
		func() -> void:
			for n: BBNode in _all_bb_nodes():
				var sort_node: BBSortNode = n as BBSortNode
				if sort_node != null:
					sort_node.set_params(sort_node.get_params())  # repopulates keys, keeps selection
	)
	world.changed.connect(func(_k, _v): _mark_dirty())
	var _err_ent: Error = world.entities_changed.connect(
		func() -> void: _mark_dirty())
	_refresh_library_list()
	_seed_demo()
	_mark_dirty()


func _process(delta: float) -> void:
	_process_panning(delta)
	_check_grid_snap_change()
	if _has_timers:
		_timer_accum += delta
		if _timer_accum >= 0.2:
			_timer_accum = 0.0
			_reevaluate()


func _check_grid_snap_change() -> void:
	if graph.show_grid == _last_show_grid and graph.snapping_enabled == _last_snapping:
		return
	_last_show_grid = graph.show_grid
	_last_snapping = graph.snapping_enabled
	settings.show_grid = _last_show_grid
	settings.snapping_enabled = _last_snapping
	settings.save_to_disk()

## WASD / arrow-key panning. Suppressed while a text field has focus or any
## popup/dialog is open, so typing values never moves the grid. Uses raw key
## polling; if you'd rather reuse the project's mapped direction actions,
## swap the is_key_pressed calls for Input.is_action_pressed("your_action").
func _process_panning(delta: float) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return  # editing a value (SpinBoxes focus their internal LineEdit)
	if name_dialog.visible or overwrite_dialog.visible or add_menu.visible or node_menu.visible:
		return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if dir != Vector2.ZERO:
		graph.scroll_offset += dir.normalized() * PAN_SPEED * delta


# ---------------------------------------------------------------- UI assembly

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)

	graph = GraphEdit.new()
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph.custom_minimum_size = Vector2(680, 0)
	graph.minimap_enabled = true
	graph.right_disconnects = true
	graph.show_grid = settings.show_grid
	graph.snapping_enabled = settings.snapping_enabled
	_last_show_grid = graph.show_grid
	_last_snapping = graph.snapping_enabled
	# Activity glow (pulses on wires carrying TRUE) — green to match ports.
	graph.add_theme_color_override("activity", BBNode.COL_TRUE)
	split.add_child(graph)

	graph.connection_request.connect(_on_connection_request)
	graph.disconnection_request.connect(_on_disconnection_request)
	graph.popup_request.connect(_on_popup_request)
	graph.delete_nodes_request.connect(_on_delete_nodes_request)
	graph.connection_to_empty.connect(_on_connection_to_empty)
	graph.connection_from_empty.connect(_on_connection_from_empty)
	graph.end_node_move.connect(_on_end_node_move)
	graph.duplicate_nodes_request.connect(_duplicate_selection)
	graph.copy_nodes_request.connect(_copy_selection)
	graph.paste_nodes_request.connect(_paste_clipboard)
	graph.node_selected.connect(_on_graph_node_selected)
	graph.node_deselected.connect(_on_graph_node_deselected)

	if graph.has_method("get_menu_hbox"):
		var tb: HBoxContainer = graph.get_menu_hbox()
		var b1 := Button.new()
		b1.text = "Copy graph JSON"
		b1.tooltip_text = "Copies the whole visible graph + world snapshot + library — paste it to Claude for debugging"
		b1.pressed.connect(_copy_graph_json)
		tb.add_child(b1)
		var b2 := Button.new()
		b2.text = "Selection → Condition"
		b2.tooltip_text = "Collapse the selected nodes into a named, reusable condition or value (Ctrl+G)"
		b2.pressed.connect(_save_selection_as_condition)
		tb.add_child(b2)

	# ---- side panel
	var side_scroll := ScrollContainer.new()
	side_scroll.custom_minimum_size = Vector2(330, 0)
	split.add_child(side_scroll)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 6)
	side_scroll.add_child(side)

	side.add_child(_header("ANT VALUES — the ant's own body & vitals"))
	for f in BBWorldState.fields_in_group("ant"):
		side.add_child(_make_slider_row(f))

	side.add_child(HSeparator.new())
	side.add_child(_header("WORLD VALUES — what the ant senses around it"))
	for f in BBWorldState.fields_in_group("world"):
		side.add_child(_make_slider_row(f))

	side.add_child(_header("Mock entities (senses)"))

	var ant_row: Control = _make_count_row("Ants in view", world.ant_count,
		func(v: int) -> void: world.set_entity_counts(v, world.food_count)
		)
	side.add_child(ant_row)

	var food_row: Control = _make_count_row("Food in view", world.food_count,
		func(v: int) -> void: world.set_entity_counts(world.ant_count, v)
		)
	side.add_child(food_row)

	var reroll_btn: Button = Button.new()
	reroll_btn.text = "🎲 Reroll entities"
	reroll_btn.tooltip_text = "New random positions, allegiances, and stats for all sensed items"
	reroll_btn.focus_mode = Control.FOCUS_NONE
	var _err_reroll: Error = reroll_btn.pressed.connect(
		func() -> void: world.reroll_entities()
	)
	side.add_child(reroll_btn)

	side.add_child(HSeparator.new())
	side.add_child(_header("CONDITION LIBRARY — double-click to add to graph"))
	lib_list = ItemList.new()
	lib_list.custom_minimum_size = Vector2(0, 140)
	lib_list.item_activated.connect(func(i):
		_spawn_condition(lib_list.get_item_text(i).trim_suffix("  (number)"), _view_center_graph_pos()))
	side.add_child(lib_list)

	var lib_btns := HBoxContainer.new()
	var add_b := Button.new()
	add_b.text = "Add to graph"
	add_b.pressed.connect(func():
		var sel := lib_list.get_selected_items()
		if sel.size() > 0:
			_spawn_condition(lib_list.get_item_text(sel[0]).trim_suffix("  (number)"), _view_center_graph_pos())
		else:
			_toast("Pick a condition in the list first."))
	var del_b := Button.new()
	del_b.text = "Delete"
	del_b.pressed.connect(_delete_selected_library_condition)
	var exp_b := Button.new()
	exp_b.text = "Copy lib JSON"
	exp_b.pressed.connect(func():
		DisplayServer.clipboard_set(library.export_json())
		_toast("Library JSON copied to clipboard."))
	lib_btns.add_child(add_b)
	lib_btns.add_child(del_b)
	lib_btns.add_child(exp_b)
	side.add_child(lib_btns)

	side.add_child(HSeparator.new())
	side.add_child(_header("HOW TO"))
	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color(0.72, 0.72, 0.76))
	help.text = (
		"• Right-click empty space: add nodes. WASD / arrows pan the grid.\n"
		+ "• Drag between ports to wire. Drag a wire into empty space, pick a node — it auto-attaches.\n"
		+ "• Wires glow green when carrying TRUE and red when false.\n"
		+ "• Drop a node ON another node to auto-compose into a free input.\n"
		+ "• MATH builds expressions (e.g. health ÷ max_health × 100 = health %). Save one with Ctrl+G to get a reusable named value.\n"
		+ "• ⏱ Hold true keeps a condition latched for N seconds before re-checking.\n"
		+ "• Selecting a ◈ condition highlights every other reference to it.\n"
		+ "• + on a condition lists what's inside; ⤢ unpacks it for editing (Ctrl+G re-saves, name pre-filled).\n"
		+ "• ⧉ on a node (or Ctrl+Shift+C) copies debug JSON to paste to Claude.\n"
		+ "• Ctrl+C/V/D copy/paste/duplicate. Del deletes.\n"
		+ "• ⚡ BEHAVIOR flashes when its condition flips true.")
	side.add_child(help)

	# ---- status bar
	status = Label.new()
	status.text = "  Ready — try dragging Health below 30 and Enemy distance below 25."
	root.add_child(status)

	# ---- popups & dialogs
	add_menu = PopupMenu.new()
	add_child(add_menu)
	add_menu.id_pressed.connect(_on_add_menu_id)

	node_menu = PopupMenu.new()
	add_child(node_menu)
	node_menu.id_pressed.connect(_on_node_menu_id)

	name_dialog = ConfirmationDialog.new()
	name_dialog.title = "Name this condition / value"
	name_dialog.min_size = Vector2i(340, 110)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "e.g. IsLowHealth, EnemyNearby, HealthPercent"
	name_dialog.add_child(name_edit)
	name_dialog.register_text_enter(name_edit)
	name_dialog.confirmed.connect(_on_name_confirmed)
	add_child(name_dialog)

	overwrite_dialog = ConfirmationDialog.new()
	overwrite_dialog.title = "Condition already exists"
	overwrite_dialog.ok_button_text = "Yes, update all references"
	overwrite_dialog.add_button("Save as new…", true, "save_new")
	overwrite_dialog.confirmed.connect(_on_overwrite_confirmed)
	overwrite_dialog.custom_action.connect(_on_overwrite_custom)
	overwrite_dialog.canceled.connect(func():
		if _suppress_cancel:
			_suppress_cancel = false
			return
		_pending_save = {}
		_toast("Save cancelled."))
	add_child(overwrite_dialog)

func _make_count_row(label_text: String, initial: int, on_change: Callable) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	var top: HBoxContainer = HBoxContainer.new()
	var lab: Label = Label.new()
	lab.text = label_text
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val: Label = Label.new()
	val.text = str(initial)
	top.add_child(lab)
	top.add_child(val)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 12.0
	slider.step = 1.0
	slider.value = float(initial)
	slider.focus_mode = Control.FOCUS_NONE
	var _err: Error = slider.value_changed.connect(
		func(x: float) -> void:
			val.text = str(int(x))
			on_change.call(int(x)))
	box.add_child(top)
	box.add_child(slider)
	return box


func _header(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", Color(0.62, 0.74, 0.92))
	return l


func _make_slider_row(f: Dictionary) -> Control:
	var v := VBoxContainer.new()
	var top := HBoxContainer.new()
	var lab := Label.new()
	lab.text = f.label
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val := Label.new()
	val.text = ("%.2f" % f.default) if f.step < 1.0 else str(int(f.default))
	top.add_child(lab)
	top.add_child(val)
	var s := HSlider.new()
	s.min_value = f.min
	s.max_value = f.max
	s.step = f.step
	s.value = f.default
	s.focus_mode = Control.FOCUS_NONE  # so arrows keep panning, not nudging sliders
	s.value_changed.connect(func(x):
		val.text = ("%.2f" % x) if f.step < 1.0 else str(int(x))
		world.set_value(f.key, x))
	v.add_child(top)
	v.add_child(s)
	return v


func _seed_demo() -> void:
	var wv := _create_node("world_value", {"key": "health", "group": "ant"}, Vector2(80, 120))
	var cmp := _create_node("compare", {"op": "<", "b": 30}, Vector2(380, 100))
	var wv2 := _create_node("world_value", {"key": "enemy_dist", "group": "world"}, Vector2(80, 340))
	var cmp2 := _create_node("compare", {"op": "<", "b": 25}, Vector2(380, 320))
	var andn := _create_node("and", {}, Vector2(700, 200))
	var beh := _create_node("behavior", {}, Vector2(960, 200))
	graph.connect_node(wv.name, 0, cmp.name, 0)
	graph.connect_node(wv2.name, 0, cmp2.name, 0)
	graph.connect_node(cmp.name, 0, andn.name, 0)
	graph.connect_node(cmp2.name, 0, andn.name, 1)
	graph.connect_node(andn.name, 0, beh.name, 0)


# --------------------------------------------------------------- node factory

func _create_node(type: String, params: Dictionary, pos: Vector2) -> BBNode:
	var n: BBNode
	match type:
		"world_value": n = BBWorldValueNode.new()
		"constant": n = BBConstantNode.new()
		"compare": n = BBCompareNode.new()
		"math": n = BBMathNode.new()
		"sense_list":
			n = BBSenseListNode.new()
		"filter":
			n = BBFilterNode.new()
		"sort":
			var sort_node: BBSortNode = BBSortNode.new()
			sort_node.setup_library(library)  # exposes ◈ float values as sort keys
			n = sort_node
		"pick":
			n = BBPickNode.new()
		"item_value":
			n = BBItemValueNode.new()
		"list_count":
			n = BBListCountNode.new()
		"timer": n = BBTimerNode.new()
		"and", "or", "not":
			n = BBLogicNode.new()
			n.bb_type = type
		"behavior": n = BBBehaviorNode.new()
		"condition":
			return _spawn_condition(str(params.get("name", "")), pos)
		_:
			push_warning("Unknown node type: " + type)
			return null
	_finalize_node(n, type, pos)
	if not params.is_empty():
		n.set_params(params)
	return n


func _spawn_condition(cname: String, pos: Vector2) -> BBConditionNode:
	var n := BBConditionNode.new()
	n.setup(cname, library, world)
	_finalize_node(n, "condition", pos)
	n.unpack_requested.connect(_unpack_condition)
	return n


func _finalize_node(n: BBNode, type: String, pos: Vector2) -> void:
	_uid += 1
	n.name = "%s_%d" % [type, _uid]
	n.position_offset = pos
	graph.add_child(n)
	var _err_params: Error = n.params_changed.connect(
		func() -> void:
			_drop_mismatched_output_wires(n)
			_mark_dirty()
	)
	n.copy_debug_requested.connect(_copy_debug_node)
	n.node_context_requested.connect(_open_node_menu)
	_mark_dirty()

## Disconnects outgoing wires whose destination port no longer matches this
## node's output type (ITEM VALUE retypes float ⇄ bool with its property).
func _drop_mismatched_output_wires(n: BBNode) -> void:
	if n.output_type() < 0:
		return
	for c: Dictionary in _conns():
		if str(c.from) != str(n.name):
			continue
		var dst: BBNode = _bb(str(c.to))
		if dst != null and dst.input_type(int(c.to_port)) != n.output_type():
			graph.disconnect_node(
				StringName(str(c.from)), int(c.from_port),
				StringName(str(c.to)), int(c.to_port))
			_toast("Disconnected a wire — %s now outputs a different type." % n.title)

func _bb(nm: String) -> BBNode:
	var n := graph.get_node_or_null(NodePath(nm))
	return n as BBNode if n and not n.is_queued_for_deletion() else null


func _all_bb_nodes() -> Array:
	var out := []
	for c in graph.get_children():
		if c is BBNode and not c.is_queued_for_deletion():
			out.append(c)
	return out


func _selected_bb_nodes() -> Array:
	return _all_bb_nodes().filter(func(n): return n.selected)


## Normalizes connection dicts across Godot 4.x minor versions.
func _conns() -> Array:
	var out := []
	for c in graph.get_connection_list():
		out.append({
			"from": str(c.get("from_node", c.get("from"))),
			"from_port": int(c.from_port),
			"to": str(c.get("to_node", c.get("to"))),
			"to_port": int(c.to_port),
		})
	return out


# --------------------------------------------------- condition reference glow

func _on_graph_node_selected(n: Node) -> void:
	var cn := n as BBConditionNode
	if cn == null:
		return
	var count := _set_reference_glow(cn.cond_name, true)
	if count > 1:
		_toast('%d references of "◈ %s" highlighted.' % [count, cn.cond_name])


func _on_graph_node_deselected(n: Node) -> void:
	var cn := n as BBConditionNode
	if cn == null:
		return
	# Keep the glow while any other instance of the same name is selected.
	for m in _all_bb_nodes():
		if m is BBConditionNode and m != cn and m.cond_name == cn.cond_name and m.selected:
			return
	_set_reference_glow(cn.cond_name, false)


func _set_reference_glow(cname: String, on: bool) -> int:
	var count := 0
	for m in _all_bb_nodes():
		if m is BBConditionNode and m.cond_name == cname:
			m.set_reference_glow(on)
			count += 1
	return count


# ----------------------------------------------------------------- wiring

func _on_connection_request(from: StringName, fp: int, to: StringName, tp: int) -> void:
	if str(from) == str(to):
		return
	for c in _conns():  # one wire per input port — a new wire replaces the old one
		if c.to == str(to) and c.to_port == tp:
			graph.disconnect_node(c.from, c.from_port, c.to, c.to_port)
	graph.connect_node(from, fp, to, tp)
	_mark_dirty()


func _on_disconnection_request(from: StringName, fp: int, to: StringName, tp: int) -> void:
	graph.disconnect_node(from, fp, to, tp)
	_mark_dirty()


func _on_connection_to_empty(from_node: StringName, from_port: int, release_position: Vector2) -> void:
	var gp := (release_position + graph.scroll_offset) / graph.zoom
	_open_add_menu(get_global_mouse_position(), gp, {"from": str(from_node), "from_port": from_port})


func _on_connection_from_empty(to_node: StringName, to_port: int, release_position: Vector2) -> void:
	var gp := (release_position + graph.scroll_offset) / graph.zoom
	_open_add_menu(get_global_mouse_position(), gp, {"to": str(to_node), "to_port": to_port})


func _port_occupied(nm: String, port: int) -> bool:
	for c in _conns():
		if c.to == nm and c.to_port == port:
			return true
	return false


func _already_connected(a: String, b: String) -> bool:
	for c in _conns():
		if c.from == a and c.to == b:
			return true
	return false


func _free_input_port(t: BBNode, out_type: int) -> int:
	for p in t.input_count():
		if t.input_type(p) == out_type and not _port_occupied(str(t.name), p):
			return p
	return -1


## Drop-compose: releasing a dragged node on top of another node wires it in.
func _on_end_node_move() -> void:
	for s in _selected_bb_nodes():
		if s.output_type() < 0:
			continue
		var s_center: Vector2 = s.position_offset + s.size * 0.5
		for t in _all_bb_nodes():
			if t == s or t.selected:
				continue
			if not Rect2(t.position_offset, t.size).has_point(s_center):
				continue
			if _already_connected(str(s.name), str(t.name)):
				break
			var port := _free_input_port(t, s.output_type())
			if port == -1 and t is BBLogicNode and t.bb_type != "not" and s.output_type() == BBNode.TYPE_BOOL:
				t.set_input_count(t.input_count() + 1)
				port = t.input_count() - 1
			if port == -1:
				break
			for c in _conns():  # dropping in replaces nothing; only free ports are used
				if c.to == str(t.name) and c.to_port == port:
					graph.disconnect_node(c.from, c.from_port, c.to, c.to_port)
			graph.connect_node(s.name, 0, t.name, port)
			s.position_offset = t.position_offset + Vector2(-(s.size.x + 90), port * 70.0)
			_toast("Composed: %s → %s (IN %d)" % [s.title, t.title, port + 1])
			_mark_dirty()
			break


# ------------------------------------------------------------------ menus

func _on_popup_request(at_position: Vector2) -> void:
	var gp := (at_position + graph.scroll_offset) / graph.zoom
	_open_add_menu(get_global_mouse_position(), gp, {})


func _open_add_menu(screen_pos: Vector2, graph_pos: Vector2, pending: Dictionary) -> void:
	_menu_graph_pos = graph_pos
	_pending_conn = pending
	add_menu.clear()
	for i in ADD_ITEMS.size():
		add_menu.add_item(ADD_ITEMS[i][0], i)
	var cnames := library.names()
	if cnames.size() > 0:
		add_menu.add_separator("Saved conditions & values")
		for j in cnames.size():
			add_menu.add_item("◈ " + cnames[j], 100 + j)
	if _selected_bb_nodes().size() > 0:
		add_menu.add_separator()
		add_menu.add_item("Save selection as condition   Ctrl+G", 900)
		add_menu.add_item("Copy debug JSON of selection   Ctrl+Shift+C", 901)
		add_menu.add_item("Delete selection   Del", 902)
	add_menu.reset_size()
	add_menu.popup(Rect2(screen_pos, Vector2.ZERO))


func _on_add_menu_id(id: int) -> void:
	if id < 100:
		var n := _create_node(ADD_ITEMS[id][1], ADD_ITEMS[id][2], _menu_graph_pos)
		_try_pending_connection(n)
	elif id < 900:
		var cnames := library.names()
		var n2 := _spawn_condition(cnames[id - 100], _menu_graph_pos)
		_try_pending_connection(n2)
	elif id == 900:
		_save_selection_as_condition()
	elif id == 901:
		_copy_debug_selection()
	elif id == 902:
		_delete_selection()


## Auto-attach: after picking a node from the "dragged a wire into empty
## space" menu, wire the new node onto the dangling connection. Grows AND/OR
## nodes if they have no free port, and toasts if the types just can't match
## (e.g. dragging a number wire and picking AND).
func _try_pending_connection(n: BBNode) -> void:
	if n == null or _pending_conn.is_empty():
		_pending_conn = {}
		return
	# Let the new node build its slots before we inspect its ports.
	if not n.is_node_ready():
		await n.ready
	if _pending_conn.has("from"):
		var src := _bb(_pending_conn.from)
		if src and src.output_type() >= 0:
			var port := _free_input_port(n, src.output_type())
			if port == -1 and n is BBLogicNode and n.bb_type != "not" and src.output_type() == BBNode.TYPE_BOOL:
				(n as BBLogicNode).set_input_count(n.input_count() + 1)
				port = n.input_count() - 1
			if port >= 0:
				_on_connection_request(StringName(_pending_conn.from), int(_pending_conn.from_port), n.name, port)
			else:
				_toast("%s has no input that accepts a %s wire — connect it manually." % [
					n.title, "number" if src.output_type() == BBNode.TYPE_FLOAT else "true/false"])
	else:
		var dst := _bb(_pending_conn.to)
		if dst:
			if n.output_type() == dst.input_type(int(_pending_conn.to_port)):
				_on_connection_request(n.name, 0, StringName(_pending_conn.to), int(_pending_conn.to_port))
			else:
				_toast("%s outputs the wrong type for that port — connect it manually." % n.title)
	_pending_conn = {}
	_mark_dirty()


func _open_node_menu(n: BBNode, at_screen: Vector2) -> void:
	_ctx_node = n
	node_menu.clear()
	node_menu.add_item("Copy debug JSON  ⧉", 1)
	if n is BBConditionNode:
		node_menu.add_item("Show contents  +", 2)
		node_menu.add_item("Unpack into graph (edit)  ⤢", 3)
	if _selected_bb_nodes().size() > 0:
		node_menu.add_item("Save selection as condition   Ctrl+G", 4)
	node_menu.add_separator()
	node_menu.add_item("Delete", 5)
	node_menu.reset_size()
	node_menu.popup(Rect2(at_screen, Vector2.ZERO))


func _on_node_menu_id(id: int) -> void:
	if _ctx_node == null or not is_instance_valid(_ctx_node):
		return
	match id:
		1: _copy_debug_node(_ctx_node)
		2:
			if _ctx_node is BBConditionNode:
				(_ctx_node as BBConditionNode).toggle_expanded()
				(_ctx_node as BBConditionNode).refresh_preview()
		3:
			if _ctx_node is BBConditionNode:
				_unpack_condition(_ctx_node as BBConditionNode)
		4: _save_selection_as_condition()
		5:
			_remove_node_by_name(str(_ctx_node.name))
			_mark_dirty()


# --------------------------------------------------------------- shortcuts

func _unhandled_key_input(event: InputEvent) -> void:
	var e := event as InputEventKey
	if e == null or not e.pressed or e.echo:
		return
	if e.keycode == KEY_G and e.ctrl_pressed:
		_save_selection_as_condition()
		accept_event()
	elif e.keycode == KEY_C and e.ctrl_pressed and e.shift_pressed:
		_copy_debug_selection()
		accept_event()


# ------------------------------------------------------- delete / copy / paste

func _on_delete_nodes_request(nodes) -> void:
	for nm in nodes:
		_remove_node_by_name(str(nm))
	_mark_dirty()


func _delete_selection() -> void:
	for n in _selected_bb_nodes():
		_remove_node_by_name(str(n.name))
	_mark_dirty()


func _remove_node_by_name(nm: String) -> void:
	var n := _bb(nm)
	if n == null:
		return
	_disconnect_all(nm)
	n.queue_free()


func _disconnect_all(nm: String) -> void:
	for c in _conns():
		if c.from == nm or c.to == nm:
			graph.disconnect_node(c.from, c.from_port, c.to, c.to_port)


func _copy_selection() -> void:
	var sel := _selected_bb_nodes()
	if sel.is_empty():
		return
	_clipboard = _serialize_nodes(sel)
	_toast("Copied %d node(s) — Ctrl+V to paste." % sel.size())


func _paste_clipboard() -> void:
	if _clipboard.is_empty():
		return
	_instantiate_serialized(_clipboard, _view_center_graph_pos() + Vector2(40, 40))


func _duplicate_selection() -> void:
	var sel := _selected_bb_nodes()
	if sel.is_empty():
		return
	var data := _serialize_nodes(sel)
	var centroid := Vector2(data.centroid[0], data.centroid[1])
	_instantiate_serialized(data, centroid + Vector2(60, 60))


func _instantiate_serialized(data: Dictionary, at: Vector2) -> void:
	var idmap := {}
	for n0 in _all_bb_nodes():
		n0.selected = false
	for nd in data.get("nodes", []):
		var n := _create_node(str(nd.type), nd.get("params", {}), at + Vector2(float(nd.pos[0]), float(nd.pos[1])))
		if n:
			idmap[str(nd.id)] = str(n.name)
			n.selected = true
	for c in data.get("connections", []):
		if idmap.has(str(c.from)) and idmap.has(str(c.to)):
			graph.connect_node(idmap[str(c.from)], int(c.from_port), idmap[str(c.to)], int(c.to_port))
	_mark_dirty()


# --------------------------------------------------- save / unpack conditions

func _serialize_nodes(nodes: Array) -> Dictionary:
	var names := {}
	var centroid := Vector2.ZERO
	for n in nodes:
		names[str(n.name)] = true
		centroid += n.position_offset
	centroid /= maxi(nodes.size(), 1)
	var out_nodes := []
	for n in nodes:
		out_nodes.append({
			"id": str(n.name),
			"type": n.bb_type,
			"params": n.get_params(),
			"in_count": n.input_count(),
			"pos": [n.position_offset.x - centroid.x, n.position_offset.y - centroid.y],
		})
	var out_conns := []
	for c in _conns():
		if names.has(c.from) and names.has(c.to):
			out_conns.append(c)
	return {"nodes": out_nodes, "connections": out_conns, "centroid": [centroid.x, centroid.y]}


func _save_selection_as_condition() -> void:
	var sel := _selected_bb_nodes().filter(func(n): return n.bb_type != "behavior")
	if sel.is_empty():
		_toast("Select the nodes that make up the condition first (box-drag or Ctrl+click).")
		return
	var names := {}
	for n in sel:
		names[str(n.name)] = true
	var consumed := {}
	for c in _conns():
		if names.has(c.from) and names.has(c.to):
			consumed[c.from] = true
	# A saved entry needs exactly one terminal output. Bool terminal = a
	# condition; float terminal = a reusable named VALUE (expression), e.g.
	# health percentage.
	var terminals := sel.filter(func(n):
		return n.output_type() >= 0 and not consumed.has(str(n.name)))
	if terminals.size() != 1:
		_toast("A condition needs exactly ONE final output node in the selection (found %d)." % terminals.size())
		return
		
	if terminals[0].output_type() >= BBNode.TYPE_LIST:
		_toast("A saved condition/value must end in a true/false or number node — add a PICK + ITEM VALUE, or a COUNT, after the list.")
		return
		
	_pending_save = {"sel": sel, "output": terminals[0]}
	# Pre-fill with the name of the condition we last unpacked, so re-saving
	# it under the same name is a single Enter.
	name_edit.text = _last_unpacked_name
	name_dialog.popup_centered()
	name_edit.grab_focus()
	name_edit.select_all()


func _on_name_confirmed() -> void:
	var cname := name_edit.text.strip_edges()
	if cname == "":
		_toast("Condition needs a name.")
		return
	if library.has_condition(cname):
		var count := 0
		for n in _all_bb_nodes():
			if n is BBConditionNode and n.cond_name == cname:
				count += 1
		_overwrite_name = cname
		overwrite_dialog.dialog_text = (
			'Are you sure you want to save it with the same name?\n\n'
			+ 'Doing this will apply the changes to all %d reference(s) of "%s" in this graph, plus any uses nested inside other conditions.'
			% [count, cname])
		overwrite_dialog.popup_centered()
		return
	_commit_save(cname)


func _on_overwrite_confirmed() -> void:
	_commit_save(_overwrite_name)


func _on_overwrite_custom(action: StringName) -> void:
	if action == &"save_new":
		_suppress_cancel = true
		overwrite_dialog.hide()
		name_edit.text = _unique_cond_name(_overwrite_name)
		name_dialog.popup_centered()
		name_edit.grab_focus()
		name_edit.select_all()


func _unique_cond_name(base: String) -> String:
	var i := 2
	while library.has_condition("%s_%d" % [base, i]):
		i += 1
	return "%s_%d" % [base, i]


func _commit_save(cname: String) -> void:
	var sel: Array = _pending_save.get("sel", []).filter(func(n): return is_instance_valid(n))
	var out_node = _pending_save.get("output")
	_pending_save = {}
	if sel.is_empty() or out_node == null or not is_instance_valid(out_node):
		_toast("Selection changed — try again.")
		return

	var overwrote := library.has_condition(cname)
	var is_value: bool = out_node.output_type() == BBNode.TYPE_FLOAT
	var data := _serialize_nodes(sel)
	data["output_id"] = str(out_node.name)
	data["output_type"] = "float" if is_value else "bool"
	data["name"] = cname
	library.save_condition(cname, data)
	if cname == _last_unpacked_name:
		_last_unpacked_name = ""

	var names := {}
	for n in sel:
		names[str(n.name)] = true

	# Selected nodes (other than the terminal) that ALSO feed nodes outside the
	# selection are "shared": they stay in the graph with their external wires
	# intact, and the condition keeps its own internal copy of them.
	var shared := {}
	for c in _conns():
		if names.has(c.from) and not names.has(c.to) and c.from != str(out_node.name):
			shared[c.from] = true

	var external_out := []
	var dropped_in := 0
	for c in _conns():
		var fi: bool = names.has(c.from)
		var ti: bool = names.has(c.to)
		if fi and not ti:
			if c.from == str(out_node.name):
				external_out.append(c)
				graph.disconnect_node(c.from, c.from_port, c.to, c.to_port)
			# shared nodes keep their outgoing external wires
		elif ti and not fi:
			if not shared.has(c.to):
				dropped_in += 1
				graph.disconnect_node(c.from, c.from_port, c.to, c.to_port)
			# shared nodes keep their incoming external wires too

	var centroid := Vector2(data.centroid[0], data.centroid[1])
	var cnode := _spawn_condition(cname, centroid)
	for c in external_out:
		graph.connect_node(cnode.name, 0, c.to, c.to_port)

	# Shrink the consumed source nodes into the new condition node.
	for n in sel:
		n.selected = false
		if shared.has(str(n.name)):
			continue
		_disconnect_all(str(n.name))
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(n, "position_offset", centroid, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(n, "modulate:a", 0.0, 0.25)
		tw.chain().tween_callback(n.queue_free)

	var extras := ""
	if is_value:
		extras += " Saved as a named VALUE (number output) — wire it into any compare or math node."
	if shared.size() > 0:
		extras += " %d node(s) also feed things outside the selection, so they stayed in the graph — the condition has its own copy." % shared.size()
	if dropped_in > 0:
		extras += " %d incoming wire(s) from outside were dropped (conditions are self-contained)." % dropped_in
	if overwrote:
		_toast('Overwrote "%s" — every reference updated.%s' % [cname, extras])
	else:
		_toast('Saved "%s".%s' % [cname, extras])
	_mark_dirty()


func _unpack_condition(cnode: BBConditionNode) -> void:
	var data = library.get_condition(cnode.cond_name)
	if data == null:
		_toast('"%s" is no longer in the library.' % cnode.cond_name)
		return
	_last_unpacked_name = cnode.cond_name
	var base: Vector2 = cnode.position_offset
	var idmap := {}
	for nd in data.get("nodes", []):
		var n := _create_node(str(nd.type), nd.get("params", {}), base + Vector2(float(nd.pos[0]), float(nd.pos[1])))
		if n:
			idmap[str(nd.id)] = str(n.name)
	for c in data.get("connections", []):
		if idmap.has(str(c.from)) and idmap.has(str(c.to)):
			graph.connect_node(idmap[str(c.from)], int(c.from_port), idmap[str(c.to)], int(c.to_port))
	var out_id := str(data.get("output_id", ""))
	for c in _conns():
		if c.from == str(cnode.name) and idmap.has(out_id):
			graph.disconnect_node(c.from, c.from_port, c.to, c.to_port)
			graph.connect_node(idmap[out_id], 0, c.to, c.to_port)
	_remove_node_by_name(str(cnode.name))
	_toast('Unpacked "%s" for editing — Ctrl+G re-saves it (name pre-filled).' % data.get("name", "?"))
	_mark_dirty()


func _delete_selected_library_condition() -> void:
	var sel := lib_list.get_selected_items()
	if sel.is_empty():
		_toast("Pick a condition in the list first.")
		return
	var cname := lib_list.get_item_text(sel[0]).trim_suffix("  (number)")
	library.remove_condition(cname)
	_toast('Deleted "%s" from the library. Existing instances now evaluate as unknown.' % cname)
	_mark_dirty()


func _refresh_library_list() -> void:
	lib_list.clear()
	for cname in library.names():
		var data = library.get_condition(cname)
		var suffix := "  (number)" if data is Dictionary and str(data.get("output_type", "bool")) == "float" else ""
		lib_list.add_item(cname + suffix)
	if graph:
		for n in _all_bb_nodes():
			if n is BBConditionNode:
				n.rebuild_preview()


# ---------------------------------------------------------------- evaluation

func _mark_dirty() -> void:
	_scan_for_timers()
	if _dirty:
		return
	_dirty = true
	call_deferred("_reevaluate")


## Enables the periodic tick when any ⏱ node exists in the graph or inside
## any saved condition, so holds count down and expire without user input.
func _scan_for_timers() -> void:
	_has_timers = false
	if graph:
		for n in _all_bb_nodes():
			if n is BBTimerNode:
				_has_timers = true
				return
	for cname in library.conditions:
		for nd in library.conditions[cname].get("nodes", []):
			if str(nd.get("type", "")) == "timer":
				_has_timers = true
				return


func _reevaluate() -> void:
	_dirty = false
	var conns := _conns()
	var incoming := {}
	for c in conns:
		if not incoming.has(c.to):
			incoming[c.to] = {}
		incoming[c.to][c.to_port] = [c.from, c.from_port]
	var memo := {}
	var cycle := {"hit": false}
	for n in _all_bb_nodes():
		_eval_live(str(n.name), incoming, memo, {}, cycle)
	# Wires: node port colors (set in on_inputs/on_value) already paint the
	# gradient green/red for bools; activity adds the glow on TRUE wires.
	for c in conns:
		var wv = memo.get(c.from)
		graph.set_connection_activity(c.from, c.from_port, c.to, c.to_port,
			1.0 if (wv is bool and wv) else 0.0)
	for n in _all_bb_nodes():
		if n is BBConditionNode:
			n.refresh_preview()
	if cycle.hit and not _cycle_warned:
		_cycle_warned = true
		_toast("Cycle detected — looped wires evaluate as unknown.")
	elif not cycle.hit:
		_cycle_warned = false


func _eval_live(nm: String, incoming: Dictionary, memo: Dictionary, visiting: Dictionary, cycle: Dictionary) -> Variant:
	if memo.has(nm):
		return memo[nm]
	if visiting.has(nm):
		cycle.hit = true
		return null
	var node := _bb(nm)
	if node == null:
		memo[nm] = null
		return null
	visiting[nm] = true
	var cnt := node.input_count()
	var values := []
	var connected := []
	var inc: Dictionary = incoming.get(nm, {})
	for p in cnt:
		if inc.has(p):
			connected.append(true)
			values.append(_eval_live(inc[p][0], incoming, memo, visiting, cycle))
		else:
			connected.append(false)
			values.append(null)
	var v = BBEval.compute(node.bb_type, node.get_params(), values, world, library, [], node.eval_state)
	visiting.erase(nm)
	memo[nm] = v
	node.on_inputs(values, connected)
	node.on_value(v)
	return v


# --------------------------------------------------------------- debug export

func _copy_debug_node(n: BBNode) -> void:
	var incoming := {}
	for c in _conns():
		if not incoming.has(c.to):
			incoming[c.to] = {}
		incoming[c.to][c.to_port] = [c.from, c.from_port]
	var payload := {
		"node": _debug_dict(str(n.name), incoming, 0),
		"world": world.snapshot(),
	}
	DisplayServer.clipboard_set(JSON.stringify(payload, "  "))
	_toast("Debug JSON for %s copied — paste it into a chat with Claude." % n.title)


func _copy_debug_selection() -> void:
	var sel := _selected_bb_nodes()
	if sel.is_empty():
		_toast("Select node(s) first, then Ctrl+Shift+C.")
		return
	var incoming := {}
	for c in _conns():
		if not incoming.has(c.to):
			incoming[c.to] = {}
		incoming[c.to][c.to_port] = [c.from, c.from_port]
	var payload := {
		"nodes": sel.map(func(n): return _debug_dict(str(n.name), incoming, 0)),
		"world": world.snapshot(),
	}
	DisplayServer.clipboard_set(JSON.stringify(payload, "  "))
	_toast("Debug JSON for %d node(s) copied." % sel.size())


func _copy_graph_json() -> void:
	var data := _serialize_nodes(_all_bb_nodes())
	var payload := {
		"graph": data,
		"world": world.snapshot(),
		"library": library.conditions,
	}
	DisplayServer.clipboard_set(JSON.stringify(payload, "  "))
	_toast("Whole graph + world + library copied as JSON.")


func _debug_dict(nm: String, incoming: Dictionary, depth: int) -> Dictionary:
	var n := _bb(nm)
	if n == null or depth > 24:
		return {"id": nm, "note": "missing or too deep"}
	var d := {
		"id": nm,
		"type": n.bb_type,
		"params": n.get_params(),
		"value": n.last_value,
	}
	if n is BBConditionNode:
		d["condition_name"] = n.cond_name
		d["definition"] = library.get_condition(n.cond_name)
	var ins := []
	var inc: Dictionary = incoming.get(nm, {})
	for p in n.input_count():
		if inc.has(p):
			ins.append(_debug_dict(inc[p][0], incoming, depth + 1))
		else:
			ins.append(null)
	if ins.size() > 0:
		d["inputs"] = ins
	return d


# -------------------------------------------------------------------- helpers

func _view_center_graph_pos() -> Vector2:
	return (graph.scroll_offset + graph.size * 0.5) / graph.zoom


func _toast(msg: String) -> void:
	status.text = "  " + msg
	if _toast_tween:
		_toast_tween.kill()
	status.modulate = Color(1.0, 1.0, 0.55)
	_toast_tween = create_tween()
	_toast_tween.tween_property(status, "modulate", Color.WHITE, 1.4)
