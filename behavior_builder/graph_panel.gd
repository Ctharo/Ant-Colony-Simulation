class_name BBGraphPanel
extends Control
## Embeddable node-graph condition editor — the pasted behavior_builder.gd
## controller adapted for in-game hosting (Batch C). Differences from the
## standalone prototype:
##   • class_name + no scene dependency: BehaviorGraphEditorPopup builds it
##     in code, per the project's runtime-UI convention.
##   • Library = BBGraphLibrary (ResourceLibrary bridge). Ctrl+G saves a
##     GraphLogic to the unified catalog (validated at gate 2); the JSON
##     library is gone.
##   • World is switchable: mock sliders (BBWorldState) or a live probe ant
##     (AntWorldAdapter). Live mode re-evaluates on a 0.2 s tick since the
##     real world has no change signals.
##   • The ⚡ node is the graph's OUTPUT marker: exactly one is required to
##     save a behavior condition (BBEval's "behavior" type passes its input
##     through, so output_id points at it directly).
##   • No demo seed; the popup loads real graph_data.
##   • Panning only while this panel's window has focus — embedded-Window
##     hosting must not pan on global key polling from other windows.
##   • `edited` signal for the host's dirty tracking.
##
## All original interactions survive: right-click add menu, wire-to-empty
## auto-attach, drop-compose, reference glow, Ctrl+G collapse, unpack,
## debug-JSON copy, copy/paste/duplicate.

signal edited

const PAN_SPEED: float = 900.0
const LIVE_TICK_S: float = 0.2
## Black beyond the grassy frame (see BBGraphFrame).
const BACKDROP_COLOR: Color = Color(0.035, 0.05, 0.045)

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
	["⚡ Output  (the behavior fires when this is true)", "behavior", {}],
	["👁 Sense  (list of ants / food)", "sense_list", {}],
	["Filter list  (keep items where …)", "filter", {}],
	["Sort list  (by distance, health, or a ◈ value)", "sort", {}],
	["Pick from list  (nearest / farthest / first)", "pick", {}],
	["Item value  (read distance / health / … of a picked item)", "item_value", {}],
	["Count list  (→ number)", "list_count", {}],
]

var world: RefCounted  # duck-typed: BBWorldState or AntWorldAdapter
var library: BBGraphLibrary = BBGraphLibrary.shared()

var graph: GraphEdit
var _frame: BBGraphFrame
var status: Label
var lib_list: ItemList
var add_menu: PopupMenu
var node_menu: PopupMenu
var name_dialog: ConfirmationDialog
var name_edit: LineEdit
var overwrite_dialog: ConfirmationDialog
var _overwrite_name: String = ""
var _suppress_cancel: bool = false

var settings: BBBuilderSettings = BBBuilderSettings.new()
var _last_show_grid: bool = true
var _last_snapping: bool = true

var _uid: int = 0
var _dirty: bool = false
var _cycle_warned: bool = false
var _menu_graph_pos: Vector2 = Vector2.ZERO
var _pending_conn: Dictionary = {}
var _pending_save: Dictionary = {}
var _clipboard: Dictionary = {}
var _ctx_node: BBNode = null
var _toast_tween: Tween
var _last_unpacked_name: String = ""
var _has_timers: bool = false
var _timer_accum: float = 0.0

## Live-preview state
var _mock_world: BBWorldState = BBWorldState.new()
var _live_world: AntWorldAdapter = null
var _live_mode: bool = false
var _live_accum: float = 0.0
var _mode_select: OptionButton
var _probe_label: Label
var _mock_box: VBoxContainer  # sliders + entity controls; hidden in live mode


func _ready() -> void:
	world = _mock_world
	settings.load_from_disk()
	_build_ui()
	var _err_lib: Error = library.changed.connect(_on_library_changed)
	var _err_val: Error = _mock_world.changed.connect(
		func(_key: String, _value: float) -> void: _mark_dirty())
	var _err_ent: Error = _mock_world.entities_changed.connect(
		func() -> void: _mark_dirty())
	_refresh_library_list()
	_mark_dirty()


func _process(delta: float) -> void:
	_process_panning(delta)
	_check_grid_snap_change()
	if _live_mode:
		_live_accum += delta
		if _live_accum >= LIVE_TICK_S:
			_live_accum = 0.0
			_refresh_probe()
			_reevaluate()
	elif _has_timers:
		_timer_accum += delta
		if _timer_accum >= LIVE_TICK_S:
			_timer_accum = 0.0
			_reevaluate()


#region Public API (for BehaviorGraphEditorPopup)
## Rebuilds the graph from serialized data (BBEval format; positions are
## centroid-relative as _serialize_nodes writes them). Node ids are remapped
## to fresh names; wires re-form through the id map.
func load_graph(data: Dictionary) -> void:
	clear_graph()
	var centroid_arr: Array = data.get("centroid", [0.0, 0.0])
	var centroid: Vector2 = Vector2(float(centroid_arr[0]), float(centroid_arr[1]))
	var idmap: Dictionary = {}
	for nd: Dictionary in data.get("nodes", []):
		var pos_arr: Array = nd.get("pos", [0.0, 0.0])
		var n: BBNode = _create_node(str(nd.type), nd.get("params", {}),
			centroid + Vector2(float(pos_arr[0]), float(pos_arr[1])))
		if n != null:
			idmap[str(nd.id)] = str(n.name)
	for c: Dictionary in data.get("connections", []):
		if idmap.has(str(c.from)) and idmap.has(str(c.to)):
			var _e: Error = graph.connect_node(
				StringName(idmap[str(c.from)]), int(c.from_port),
				StringName(idmap[str(c.to)]), int(c.to_port))
	_mark_dirty()


func clear_graph() -> void:
	for n: BBNode in _all_bb_nodes():
		_remove_node_by_name(str(n.name))


## Serializes the WHOLE graph with output_id resolved to the single ⚡
## Output node ("" when there are zero or several — callers gate on
## output_node_count()).
func serialize_graph() -> Dictionary:
	var data: Dictionary = _serialize_nodes(_all_bb_nodes())
	var outputs: Array = _output_nodes()
	data["output_id"] = str((outputs[0] as BBNode).name) if outputs.size() == 1 else ""
	return data


func output_node_count() -> int:
	return _output_nodes().size()


func is_graph_empty() -> bool:
	# An untouched graph holding only the pre-placed ⚡ Output counts as
	# empty: nothing is wired, so there is no condition to persist.
	for n: BBNode in _all_bb_nodes():
		if n.bb_type != "behavior":
			return false
	return _conns().is_empty()


## Gate 1 (live validation): current graph through BBGraphValidator.
func current_errors() -> PackedStringArray:
	return BBGraphValidator.validate(serialize_graph(), library)


## Places a fresh ⚡ Output node — the popup calls this for brand-new
## behaviors so the required terminal is already on the canvas.
func spawn_output_node() -> void:
	var _n: BBNode = _create_node("behavior", {}, _view_center_graph_pos() + Vector2(260, 0))


func set_probe_ant(ant: Ant) -> void:
	_live_world = AntWorldAdapter.new(ant) if ant != null else null
	if _live_mode:
		_apply_preview_mode()


func _output_nodes() -> Array:
	return _all_bb_nodes().filter(
		func(n: BBNode) -> bool: return n.bb_type == "behavior")
#endregion


#region Preview mode (mock sliders vs live probe ant)
func _on_mode_selected(index: int) -> void:
	_live_mode = index == 1
	_apply_preview_mode()


func _apply_preview_mode() -> void:
	if _live_mode and (_live_world == null or not _live_world.is_alive()):
		_refresh_probe()
	if _live_mode and _live_world != null and _live_world.is_alive():
		world = _live_world
	else:
		if _live_mode:
			_toast("No live ants to probe — showing mock sliders.")
			_live_mode = false
			if _mode_select != null:
				_mode_select.select(0)
		world = _mock_world
	if _mock_box != null:
		_mock_box.visible = not _live_mode
	if _probe_label != null:
		_probe_label.visible = _live_mode
	_mark_dirty()


## Live mode follows "the first live ant" (same probe policy as the
## designer); a dead probe is replaced automatically on the next tick.
func _refresh_probe() -> void:
	if _live_world != null and _live_world.is_alive():
		return
	var ants: Array[Ant] = AntManager.get_all()
	_live_world = AntWorldAdapter.new(ants[0]) if not ants.is_empty() else null
	if _live_world == null and _live_mode:
		_apply_preview_mode()  # falls back to mock with a toast
	elif _live_mode and _live_world != null:
		world = _live_world


func _on_library_changed() -> void:
	_refresh_library_list()
	for n: BBNode in _all_bb_nodes():
		var sort_node: BBSortNode = n as BBSortNode
		if sort_node != null:
			sort_node.set_params(sort_node.get_params())  # repopulate keys, keep selection
	_mark_dirty()
#endregion


func _check_grid_snap_change() -> void:
	if graph.show_grid == _last_show_grid and graph.snapping_enabled == _last_snapping:
		return
	_last_show_grid = graph.show_grid
	_last_snapping = graph.snapping_enabled
	settings.show_grid = _last_show_grid
	settings.snapping_enabled = _last_snapping
	settings.save_to_disk()


## WASD / arrow-key panning. Suppressed while a text field has focus, any
## popup/dialog is open, or — new for embedded-Window hosting — while this
## panel's window is not the focused one (Input.is_key_pressed is global;
## without the guard, typing in ANOTHER tool window would pan this graph).
func _process_panning(delta: float) -> void:
	var host: Window = get_window()
	if host == null or not host.has_focus():
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return  # editing a value (SpinBoxes focus their internal LineEdit)
	if name_dialog.visible or overwrite_dialog.visible or add_menu.visible or node_menu.visible:
		return
	var dir: Vector2 = Vector2.ZERO
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
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	var split: HSplitContainer = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)

	# Left cell stacks three layers: a black backdrop, the grassy frame that
	# hugs the nodes, and the GraphEdit itself (transparent panel so the grass
	# shows through behind its wires and nodes). See BBGraphFrame.
	var left_cell: Control = Control.new()
	left_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_cell.custom_minimum_size = Vector2(680, 0)
	left_cell.clip_contents = true
	split.add_child(left_cell)

	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = BACKDROP_COLOR
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_cell.add_child(backdrop)

	graph = GraphEdit.new()
	graph.set_anchors_preset(Control.PRESET_FULL_RECT)
	graph.minimap_enabled = true
	graph.right_disconnects = true
	graph.show_grid = settings.show_grid
	graph.snapping_enabled = settings.snapping_enabled
	_last_show_grid = graph.show_grid
	_last_snapping = graph.snapping_enabled
	graph.add_theme_color_override("activity", BBNode.COL_TRUE)
	# Transparent background + invisible built-in grid: the grass (BBGraphFrame,
	# behind) shows through, and the frame paints its own grid clipped to the
	# green so lines never bleed onto the black outside. grid_major/grid_minor
	# are the GraphEdit 4.x grid theme colors.
	graph.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	graph.add_theme_color_override("grid_major", Color(0, 0, 0, 0))
	graph.add_theme_color_override("grid_minor", Color(0, 0, 0, 0))

	# Frame is added BEFORE the graph so it draws behind it, and AFTER the
	# backdrop so it draws in front of the black.
	_frame = BBGraphFrame.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.graph = graph
	left_cell.add_child(_frame)
	left_cell.add_child(graph)

	var _e1: Error = graph.connection_request.connect(_on_connection_request)
	var _e2: Error = graph.disconnection_request.connect(_on_disconnection_request)
	var _e3: Error = graph.popup_request.connect(_on_popup_request)
	var _e4: Error = graph.delete_nodes_request.connect(_on_delete_nodes_request)
	var _e5: Error = graph.connection_to_empty.connect(_on_connection_to_empty)
	var _e6: Error = graph.connection_from_empty.connect(_on_connection_from_empty)
	var _e7: Error = graph.end_node_move.connect(_on_end_node_move)
	var _e8: Error = graph.duplicate_nodes_request.connect(_duplicate_selection)
	var _e9: Error = graph.copy_nodes_request.connect(_copy_selection)
	var _e10: Error = graph.paste_nodes_request.connect(_paste_clipboard)
	var _e11: Error = graph.node_selected.connect(_on_graph_node_selected)
	var _e12: Error = graph.node_deselected.connect(_on_graph_node_deselected)

	if graph.has_method("get_menu_hbox"):
		var toolbar: HBoxContainer = graph.get_menu_hbox()
		var json_btn: Button = Button.new()
		json_btn.text = "Copy graph JSON"
		json_btn.tooltip_text = "Copies the whole visible graph + world snapshot + library — paste it to Claude for debugging"
		var _eb1: Error = json_btn.pressed.connect(_copy_graph_json)
		toolbar.add_child(json_btn)
		var collapse_btn: Button = Button.new()
		collapse_btn.text = "Selection → Condition"
		collapse_btn.tooltip_text = "Collapse the selected nodes into a named, reusable condition or value (Ctrl+G)"
		var _eb2: Error = collapse_btn.pressed.connect(_save_selection_as_condition)
		toolbar.add_child(collapse_btn)

	# ---- side panel
	var side_scroll: ScrollContainer = ScrollContainer.new()
	side_scroll.custom_minimum_size = Vector2(330, 0)
	split.add_child(side_scroll)
	var side: VBoxContainer = VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 6)
	side_scroll.add_child(side)

	side.add_child(_header("PREVIEW"))
	_mode_select = OptionButton.new()
	_mode_select.add_item("Mock world (sliders)")
	_mode_select.add_item("Live probe ant")
	_mode_select.tooltip_text = "Mock: drag values below to test the graph. Live: read the first live ant, refreshed 5×/s."
	var _em: Error = _mode_select.item_selected.connect(_on_mode_selected)
	side.add_child(_mode_select)
	_probe_label = Label.new()
	_probe_label.text = "Reading the first live ant."
	_probe_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_probe_label.visible = false
	side.add_child(_probe_label)

	_mock_box = VBoxContainer.new()
	_mock_box.add_theme_constant_override("separation", 6)
	side.add_child(_mock_box)

	_mock_box.add_child(_header("ANT VALUES — the ant's own body & vitals"))
	for field: Dictionary in BBWorldState.fields_in_group("ant"):
		_mock_box.add_child(_make_slider_row(field))

	_mock_box.add_child(HSeparator.new())
	_mock_box.add_child(_header("WORLD VALUES — what the ant senses around it"))
	for field: Dictionary in BBWorldState.fields_in_group("world"):
		_mock_box.add_child(_make_slider_row(field))

	_mock_box.add_child(_header("Mock entities (senses)"))
	var ant_row: Control = _make_count_row("Ants in view", _mock_world.ant_count,
		func(v: int) -> void: _mock_world.set_entity_counts(v, _mock_world.food_count))
	_mock_box.add_child(ant_row)
	var food_row: Control = _make_count_row("Food in view", _mock_world.food_count,
		func(v: int) -> void: _mock_world.set_entity_counts(_mock_world.ant_count, v))
	_mock_box.add_child(food_row)

	var reroll_btn: Button = Button.new()
	reroll_btn.text = "🎲 Reroll entities"
	reroll_btn.tooltip_text = "New random positions, allegiances, and stats for all sensed items"
	reroll_btn.focus_mode = Control.FOCUS_NONE
	var _err_reroll: Error = reroll_btn.pressed.connect(
		func() -> void: _mock_world.reroll_entities())
	_mock_box.add_child(reroll_btn)

	side.add_child(HSeparator.new())
	side.add_child(_header("CONDITION LIBRARY — double-click to add to graph"))
	lib_list = ItemList.new()
	lib_list.custom_minimum_size = Vector2(0, 140)
	var _el: Error = lib_list.item_activated.connect(
		func(index: int) -> void:
			_spawn_condition(lib_list.get_item_text(index).trim_suffix("  (number)"),
				_view_center_graph_pos()))
	side.add_child(lib_list)

	var lib_btns: HBoxContainer = HBoxContainer.new()
	var add_b: Button = Button.new()
	add_b.text = "Add to graph"
	var _ea: Error = add_b.pressed.connect(
		func() -> void:
			var sel: PackedInt32Array = lib_list.get_selected_items()
			if sel.size() > 0:
				var _n: BBConditionNode = _spawn_condition(
					lib_list.get_item_text(sel[0]).trim_suffix("  (number)"),
					_view_center_graph_pos())
			else:
				_toast("Pick a condition in the list first."))
	var del_b: Button = Button.new()
	del_b.text = "Delete"
	var _ed: Error = del_b.pressed.connect(_delete_selected_library_condition)
	var exp_b: Button = Button.new()
	exp_b.text = "Copy lib JSON"
	var _ee: Error = exp_b.pressed.connect(
		func() -> void:
			DisplayServer.clipboard_set(library.export_json())
			_toast("Library JSON copied to clipboard."))
	lib_btns.add_child(add_b)
	lib_btns.add_child(del_b)
	lib_btns.add_child(exp_b)
	side.add_child(lib_btns)

	side.add_child(HSeparator.new())
	side.add_child(_header("HOW TO"))
	var help: Label = Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color(0.72, 0.72, 0.76))
	help.text = (
		"• Right-click empty space: add nodes. WASD / arrows pan the grid.\n"
		+ "• Drag between ports to wire. Drag a wire into empty space, pick a node — it auto-attaches.\n"
		+ "• Wires glow green when carrying TRUE and red when false.\n"
		+ "• Drop a node ON another node to auto-compose into a free input.\n"
		+ "• Wire the condition into the ⚡ Output node — exactly one per behavior.\n"
		+ "• MATH builds expressions (e.g. health ÷ max_health × 100 = health %). Save one with Ctrl+G to get a reusable named value.\n"
		+ "• ⏱ Hold true keeps a condition latched for N seconds before re-checking.\n"
		+ "• Selecting a ◈ condition highlights every other reference to it.\n"
		+ "• + on a condition lists what's inside; ⤢ unpacks it for editing (Ctrl+G re-saves, name pre-filled).\n"
		+ "• ⧉ on a node (or Ctrl+Shift+C) copies debug JSON to paste to Claude.\n"
		+ "• Ctrl+C/V/D copy/paste/duplicate. Del deletes.")
	side.add_child(help)

	# ---- status bar
	status = Label.new()
	status.text = "  Wire a condition into the ⚡ Output node, then Save."
	root.add_child(status)

	# ---- popups & dialogs
	add_menu = PopupMenu.new()
	add_child(add_menu)
	var _ep1: Error = add_menu.id_pressed.connect(_on_add_menu_id)

	node_menu = PopupMenu.new()
	add_child(node_menu)
	var _ep2: Error = node_menu.id_pressed.connect(_on_node_menu_id)

	name_dialog = ConfirmationDialog.new()
	name_dialog.title = "Name this condition / value"
	name_dialog.min_size = Vector2i(340, 110)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "e.g. IsLowHealth, EnemyNearby, HealthPercent"
	name_dialog.add_child(name_edit)
	name_dialog.register_text_enter(name_edit)
	var _ep3: Error = name_dialog.confirmed.connect(_on_name_confirmed)
	add_child(name_dialog)

	overwrite_dialog = ConfirmationDialog.new()
	overwrite_dialog.title = "Condition already exists"
	overwrite_dialog.ok_button_text = "Yes, update all references"
	var _btn: Button = overwrite_dialog.add_button("Save as new…", true, "save_new")
	var _ep4: Error = overwrite_dialog.confirmed.connect(_on_overwrite_confirmed)
	var _ep5: Error = overwrite_dialog.custom_action.connect(_on_overwrite_custom)
	var _ep6: Error = overwrite_dialog.canceled.connect(
		func() -> void:
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
	var l: Label = Label.new()
	l.text = t
	l.add_theme_color_override("font_color", Color(0.62, 0.74, 0.92))
	return l


func _make_slider_row(f: Dictionary) -> Control:
	var v: VBoxContainer = VBoxContainer.new()
	var top: HBoxContainer = HBoxContainer.new()
	var lab: Label = Label.new()
	lab.text = str(f.label)
	lab.tooltip_text = str(f.get("doc", ""))
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val: Label = Label.new()
	val.text = ("%.2f" % float(f.default)) if float(f.step) < 1.0 else str(int(f.default))
	top.add_child(lab)
	top.add_child(val)
	var s: HSlider = HSlider.new()
	s.min_value = float(f.min)
	s.max_value = float(f.max)
	s.step = float(f.step)
	s.value = float(f.default)
	s.focus_mode = Control.FOCUS_NONE  # so arrows keep panning, not nudging sliders
	var _err: Error = s.value_changed.connect(
		func(x: float) -> void:
			val.text = ("%.2f" % x) if float(f.step) < 1.0 else str(int(x))
			_mock_world.set_value(str(f.key), x))
	v.add_child(top)
	v.add_child(s)
	return v


# --------------------------------------------------------------- node factory

func _create_node(type: String, params: Dictionary, pos: Vector2) -> BBNode:
	var n: BBNode
	match type:
		"world_value":
			n = BBWorldValueNode.new()
		"constant":
			n = BBConstantNode.new()
		"compare":
			n = BBCompareNode.new()
		"math":
			n = BBMathNode.new()
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
		"timer":
			n = BBTimerNode.new()
		"and", "or", "not":
			n = BBLogicNode.new()
			n.bb_type = type
		"behavior":
			n = BBBehaviorNode.new()
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
	var n: BBConditionNode = BBConditionNode.new()
	n.setup(cname, library, world)
	_finalize_node(n, "condition", pos)
	var _err: Error = n.unpack_requested.connect(_unpack_condition)
	return n


func _finalize_node(n: BBNode, type: String, pos: Vector2) -> void:
	_uid += 1
	n.name = "%s_%d" % [type, _uid]
	n.position_offset = pos
	graph.add_child(n)
	var _err_params: Error = n.params_changed.connect(
		func() -> void:
			_drop_mismatched_output_wires(n)
			_mark_dirty())
	var _err_copy: Error = n.copy_debug_requested.connect(_copy_debug_node)
	var _err_ctx: Error = n.node_context_requested.connect(_open_node_menu)
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
	var n: Node = graph.get_node_or_null(NodePath(nm))
	return n as BBNode if n != null and not n.is_queued_for_deletion() else null


func _all_bb_nodes() -> Array:
	var out: Array = []
	for c: Node in graph.get_children():
		if c is BBNode and not c.is_queued_for_deletion():
			out.append(c)
	return out


func _selected_bb_nodes() -> Array:
	return _all_bb_nodes().filter(func(n: BBNode) -> bool: return n.selected)


## Normalizes connection dicts across Godot 4.x minor versions.
func _conns() -> Array:
	var out: Array = []
	for c: Dictionary in graph.get_connection_list():
		out.append({
			"from": str(c.get("from_node", c.get("from"))),
			"from_port": int(c.from_port),
			"to": str(c.get("to_node", c.get("to"))),
			"to_port": int(c.to_port),
		})
	return out


# --------------------------------------------------- condition reference glow

func _on_graph_node_selected(n: Node) -> void:
	var cn: BBConditionNode = n as BBConditionNode
	if cn == null:
		return
	var count: int = _set_reference_glow(cn.cond_name, true)
	if count > 1:
		_toast('%d references of "◈ %s" highlighted.' % [count, cn.cond_name])


func _on_graph_node_deselected(n: Node) -> void:
	var cn: BBConditionNode = n as BBConditionNode
	if cn == null:
		return
	for m: BBNode in _all_bb_nodes():
		if m is BBConditionNode and m != cn \
				and (m as BBConditionNode).cond_name == cn.cond_name and m.selected:
			return
	var _count: int = _set_reference_glow(cn.cond_name, false)


func _set_reference_glow(cname: String, glow_on: bool) -> int:
	var count: int = 0
	for m: BBNode in _all_bb_nodes():
		if m is BBConditionNode and (m as BBConditionNode).cond_name == cname:
			(m as BBConditionNode).set_reference_glow(glow_on)
			count += 1
	return count


# ----------------------------------------------------------------- wiring

func _on_connection_request(from: StringName, fp: int, to: StringName, tp: int) -> void:
	if str(from) == str(to):
		return
	for c: Dictionary in _conns():  # one wire per input port — a new wire replaces the old
		if c.to == str(to) and int(c.to_port) == tp:
			graph.disconnect_node(StringName(str(c.from)), int(c.from_port),
				StringName(str(c.to)), int(c.to_port))
	var _err: Error = graph.connect_node(from, fp, to, tp)
	_mark_dirty()


func _on_disconnection_request(from: StringName, fp: int, to: StringName, tp: int) -> void:
	graph.disconnect_node(from, fp, to, tp)
	_mark_dirty()


func _on_connection_to_empty(from_node: StringName, from_port: int, release_position: Vector2) -> void:
	var gp: Vector2 = (release_position + graph.scroll_offset) / graph.zoom
	_open_add_menu(get_global_mouse_position(), gp, {"from": str(from_node), "from_port": from_port})


func _on_connection_from_empty(to_node: StringName, to_port: int, release_position: Vector2) -> void:
	var gp: Vector2 = (release_position + graph.scroll_offset) / graph.zoom
	_open_add_menu(get_global_mouse_position(), gp, {"to": str(to_node), "to_port": to_port})


func _port_occupied(nm: String, port: int) -> bool:
	for c: Dictionary in _conns():
		if c.to == nm and int(c.to_port) == port:
			return true
	return false


func _already_connected(a: String, b: String) -> bool:
	for c: Dictionary in _conns():
		if c.from == a and c.to == b:
			return true
	return false


func _free_input_port(t: BBNode, out_type: int) -> int:
	for p: int in t.input_count():
		if t.input_type(p) == out_type and not _port_occupied(str(t.name), p):
			return p
	return -1


## Drop-compose: releasing a dragged node on top of another node wires it in.
func _on_end_node_move() -> void:
	for s: BBNode in _selected_bb_nodes():
		if s.output_type() < 0:
			continue
		var s_center: Vector2 = s.position_offset + s.size * 0.5
		for t: BBNode in _all_bb_nodes():
			if t == s or t.selected:
				continue
			if not Rect2(t.position_offset, t.size).has_point(s_center):
				continue
			if _already_connected(str(s.name), str(t.name)):
				break
			var port: int = _free_input_port(t, s.output_type())
			if port == -1 and t is BBLogicNode and (t as BBLogicNode).bb_type != "not" \
					and s.output_type() == BBNode.TYPE_BOOL:
				(t as BBLogicNode).set_input_count(t.input_count() + 1)
				port = t.input_count() - 1
			if port == -1:
				break
			for c: Dictionary in _conns():  # only free ports are used
				if c.to == str(t.name) and int(c.to_port) == port:
					graph.disconnect_node(StringName(str(c.from)), int(c.from_port),
						StringName(str(c.to)), int(c.to_port))
			var _err: Error = graph.connect_node(s.name, 0, t.name, port)
			s.position_offset = t.position_offset + Vector2(-(s.size.x + 90), port * 70.0)
			_toast("Composed: %s → %s (IN %d)" % [s.title, t.title, port + 1])
			_mark_dirty()
			break


# ------------------------------------------------------------------ menus

func _on_popup_request(at_position: Vector2) -> void:
	var gp: Vector2 = (at_position + graph.scroll_offset) / graph.zoom
	_open_add_menu(get_global_mouse_position(), gp, {})


func _open_add_menu(screen_pos: Vector2, graph_pos: Vector2, pending: Dictionary) -> void:
	_menu_graph_pos = graph_pos
	_pending_conn = pending
	add_menu.clear()
	for i: int in ADD_ITEMS.size():
		add_menu.add_item(ADD_ITEMS[i][0], i)
	var cnames: Array[String] = library.names()
	if cnames.size() > 0:
		add_menu.add_separator("Saved conditions & values")
		for j: int in cnames.size():
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
		var n: BBNode = _create_node(str(ADD_ITEMS[id][1]), ADD_ITEMS[id][2], _menu_graph_pos)
		_try_pending_connection(n)
	elif id < 900:
		var cnames: Array[String] = library.names()
		var n2: BBConditionNode = _spawn_condition(cnames[id - 100], _menu_graph_pos)
		_try_pending_connection(n2)
	elif id == 900:
		_save_selection_as_condition()
	elif id == 901:
		_copy_debug_selection()
	elif id == 902:
		_delete_selection()


## Auto-attach after "dragged a wire into empty space" node creation.
func _try_pending_connection(n: BBNode) -> void:
	if n == null or _pending_conn.is_empty():
		_pending_conn = {}
		return
	if not n.is_node_ready():
		await n.ready
	if _pending_conn.has("from"):
		var src: BBNode = _bb(str(_pending_conn.from))
		if src != null and src.output_type() >= 0:
			var port: int = _free_input_port(n, src.output_type())
			if port == -1 and n is BBLogicNode and (n as BBLogicNode).bb_type != "not" \
					and src.output_type() == BBNode.TYPE_BOOL:
				(n as BBLogicNode).set_input_count(n.input_count() + 1)
				port = n.input_count() - 1
			if port >= 0:
				_on_connection_request(StringName(str(_pending_conn.from)),
					int(_pending_conn.from_port), n.name, port)
			else:
				_toast("%s has no input that accepts a %s wire — connect it manually." % [
					n.title, "number" if src.output_type() == BBNode.TYPE_FLOAT else "true/false"])
	else:
		var dst: BBNode = _bb(str(_pending_conn.to))
		if dst != null:
			if n.output_type() == dst.input_type(int(_pending_conn.to_port)):
				_on_connection_request(n.name, 0,
					StringName(str(_pending_conn.to)), int(_pending_conn.to_port))
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
		1:
			_copy_debug_node(_ctx_node)
		2:
			if _ctx_node is BBConditionNode:
				(_ctx_node as BBConditionNode).toggle_expanded()
				(_ctx_node as BBConditionNode).refresh_preview()
		3:
			if _ctx_node is BBConditionNode:
				_unpack_condition(_ctx_node as BBConditionNode)
		4:
			_save_selection_as_condition()
		5:
			_remove_node_by_name(str(_ctx_node.name))
			_mark_dirty()


# --------------------------------------------------------------- shortcuts

func _unhandled_key_input(event: InputEvent) -> void:
	var e: InputEventKey = event as InputEventKey
	if e == null or not e.pressed or e.echo:
		return
	if e.keycode == KEY_G and e.ctrl_pressed:
		_save_selection_as_condition()
		accept_event()
	elif e.keycode == KEY_C and e.ctrl_pressed and e.shift_pressed:
		_copy_debug_selection()
		accept_event()


# ------------------------------------------------------- delete / copy / paste

func _on_delete_nodes_request(node_names: Array[StringName]) -> void:
	for nm: StringName in node_names:
		_remove_node_by_name(str(nm))
	_mark_dirty()


func _delete_selection() -> void:
	for n: BBNode in _selected_bb_nodes():
		_remove_node_by_name(str(n.name))
	_mark_dirty()


func _remove_node_by_name(nm: String) -> void:
	var n: BBNode = _bb(nm)
	if n == null:
		return
	_disconnect_all(nm)
	n.queue_free()


func _disconnect_all(nm: String) -> void:
	for c: Dictionary in _conns():
		if c.from == nm or c.to == nm:
			graph.disconnect_node(StringName(str(c.from)), int(c.from_port),
				StringName(str(c.to)), int(c.to_port))


func _copy_selection() -> void:
	var sel: Array = _selected_bb_nodes()
	if sel.is_empty():
		return
	_clipboard = _serialize_nodes(sel)
	_toast("Copied %d node(s) — Ctrl+V to paste." % sel.size())


func _paste_clipboard() -> void:
	if _clipboard.is_empty():
		return
	_instantiate_serialized(_clipboard, _view_center_graph_pos() + Vector2(40, 40))


func _duplicate_selection() -> void:
	var sel: Array = _selected_bb_nodes()
	if sel.is_empty():
		return
	var data: Dictionary = _serialize_nodes(sel)
	var centroid: Vector2 = Vector2(float(data.centroid[0]), float(data.centroid[1]))
	_instantiate_serialized(data, centroid + Vector2(60, 60))


func _instantiate_serialized(data: Dictionary, at: Vector2) -> void:
	var idmap: Dictionary = {}
	for n0: BBNode in _all_bb_nodes():
		n0.selected = false
	for nd: Dictionary in data.get("nodes", []):
		var pos_arr: Array = nd.get("pos", [0.0, 0.0])
		var n: BBNode = _create_node(str(nd.type), nd.get("params", {}),
			at + Vector2(float(pos_arr[0]), float(pos_arr[1])))
		if n != null:
			idmap[str(nd.id)] = str(n.name)
			n.selected = true
	for c: Dictionary in data.get("connections", []):
		if idmap.has(str(c.from)) and idmap.has(str(c.to)):
			var _err: Error = graph.connect_node(
				StringName(idmap[str(c.from)]), int(c.from_port),
				StringName(idmap[str(c.to)]), int(c.to_port))
	_mark_dirty()


# --------------------------------------------------- save / unpack conditions

func _serialize_nodes(nodes: Array) -> Dictionary:
	var names: Dictionary = {}
	var centroid: Vector2 = Vector2.ZERO
	for n: BBNode in nodes:
		names[str(n.name)] = true
		centroid += n.position_offset
	centroid /= maxi(nodes.size(), 1)
	var out_nodes: Array = []
	for n: BBNode in nodes:
		out_nodes.append({
			"id": str(n.name),
			"type": n.bb_type,
			"params": n.get_params(),
			"in_count": n.input_count(),
			"pos": [n.position_offset.x - centroid.x, n.position_offset.y - centroid.y],
		})
	var out_conns: Array = []
	for c: Dictionary in _conns():
		if names.has(c.from) and names.has(c.to):
			out_conns.append(c)
	return {"nodes": out_nodes, "connections": out_conns, "centroid": [centroid.x, centroid.y]}


func _save_selection_as_condition() -> void:
	var sel: Array = _selected_bb_nodes().filter(
		func(n: BBNode) -> bool: return n.bb_type != "behavior")
	if sel.is_empty():
		_toast("Select the nodes that make up the condition first (box-drag or Ctrl+click).")
		return
	var names: Dictionary = {}
	for n: BBNode in sel:
		names[str(n.name)] = true
	var consumed: Dictionary = {}
	for c: Dictionary in _conns():
		if names.has(c.from) and names.has(c.to):
			consumed[c.from] = true
	# A saved entry needs exactly one terminal output. Bool terminal = a
	# condition; float terminal = a reusable named VALUE (expression).
	var terminals: Array = sel.filter(
		func(n: BBNode) -> bool:
			return n.output_type() >= 0 and not consumed.has(str(n.name)))
	if terminals.size() != 1:
		_toast("A condition needs exactly ONE final output node in the selection (found %d)." % terminals.size())
		return
	if (terminals[0] as BBNode).output_type() >= BBNode.TYPE_LIST:
		_toast("A saved condition/value must end in a true/false or number node — add a PICK + ITEM VALUE, or a COUNT, after the list.")
		return

	_pending_save = {"sel": sel, "output": terminals[0]}
	name_edit.text = _last_unpacked_name
	name_dialog.popup_centered()
	name_edit.grab_focus()
	name_edit.select_all()


func _on_name_confirmed() -> void:
	var cname: String = name_edit.text.strip_edges()
	if cname == "":
		_toast("Condition needs a name.")
		return
	if library.has_condition(cname):
		var count: int = 0
		for n: BBNode in _all_bb_nodes():
			if n is BBConditionNode and (n as BBConditionNode).cond_name == cname:
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
	var i: int = 2
	while library.has_condition("%s_%d" % [base, i]):
		i += 1
	return "%s_%d" % [base, i]


func _commit_save(cname: String) -> void:
	var sel: Array = _pending_save.get("sel", []).filter(
		func(n: BBNode) -> bool: return is_instance_valid(n))
	var out_node: BBNode = _pending_save.get("output") as BBNode
	_pending_save = {}
	if sel.is_empty() or out_node == null or not is_instance_valid(out_node):
		_toast("Selection changed — try again.")
		return

	var overwrote: bool = library.has_condition(cname)
	var is_value: bool = out_node.output_type() == BBNode.TYPE_FLOAT
	var data: Dictionary = _serialize_nodes(sel)
	data["output_id"] = str(out_node.name)
	data["output_type"] = "float" if is_value else "bool"
	data["name"] = cname
	# ResourceLibrary persistence (gate 2 validates via validate_logic →
	# BBGraphValidator). A rejected save leaves the graph untouched.
	if library.save_condition(cname, data) != OK:
		_toast('Saving "%s" failed — see log (validation or write error).' % cname)
		return
	if cname == _last_unpacked_name:
		_last_unpacked_name = ""

	var names: Dictionary = {}
	for n: BBNode in sel:
		names[str(n.name)] = true

	# Selected nodes (other than the terminal) that ALSO feed nodes outside
	# the selection are "shared": they stay in the graph with their external
	# wires intact; the condition keeps its own internal copy of them.
	var shared: Dictionary = {}
	for c: Dictionary in _conns():
		if names.has(c.from) and not names.has(c.to) and c.from != str(out_node.name):
			shared[c.from] = true

	var external_out: Array = []
	var dropped_in: int = 0
	for c: Dictionary in _conns():
		var fi: bool = names.has(c.from)
		var ti: bool = names.has(c.to)
		if fi and not ti:
			if c.from == str(out_node.name):
				external_out.append(c)
				graph.disconnect_node(StringName(str(c.from)), int(c.from_port),
					StringName(str(c.to)), int(c.to_port))
		elif ti and not fi:
			if not shared.has(c.to):
				dropped_in += 1
				graph.disconnect_node(StringName(str(c.from)), int(c.from_port),
					StringName(str(c.to)), int(c.to_port))

	var centroid: Vector2 = Vector2(float(data.centroid[0]), float(data.centroid[1]))
	var cnode: BBConditionNode = _spawn_condition(cname, centroid)
	for c: Dictionary in external_out:
		var _err: Error = graph.connect_node(cnode.name, 0,
			StringName(str(c.to)), int(c.to_port))

	for n: BBNode in sel:
		n.selected = false
		if shared.has(str(n.name)):
			continue
		_disconnect_all(str(n.name))
		var tw: Tween = create_tween()
		tw.set_parallel(true)
		var _t1: PropertyTweener = tw.tween_property(n, "position_offset", centroid, 0.25) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		var _t2: PropertyTweener = tw.tween_property(n, "modulate:a", 0.0, 0.25)
		var _t3: CallbackTweener = tw.chain().tween_callback(n.queue_free)

	var extras: String = ""
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
	var data: Variant = library.get_condition(cnode.cond_name)
	if data == null:
		_toast('"%s" is no longer in the library.' % cnode.cond_name)
		return
	_last_unpacked_name = cnode.cond_name
	var base: Vector2 = cnode.position_offset
	var idmap: Dictionary = {}
	for nd: Dictionary in (data as Dictionary).get("nodes", []):
		var pos_arr: Array = nd.get("pos", [0.0, 0.0])
		var n: BBNode = _create_node(str(nd.type), nd.get("params", {}),
			base + Vector2(float(pos_arr[0]), float(pos_arr[1])))
		if n != null:
			idmap[str(nd.id)] = str(n.name)
	for c: Dictionary in (data as Dictionary).get("connections", []):
		if idmap.has(str(c.from)) and idmap.has(str(c.to)):
			var _err: Error = graph.connect_node(
				StringName(idmap[str(c.from)]), int(c.from_port),
				StringName(idmap[str(c.to)]), int(c.to_port))
	var out_id: String = str((data as Dictionary).get("output_id", ""))
	for c: Dictionary in _conns():
		if c.from == str(cnode.name) and idmap.has(out_id):
			graph.disconnect_node(StringName(str(c.from)), int(c.from_port),
				StringName(str(c.to)), int(c.to_port))
			var _err2: Error = graph.connect_node(StringName(idmap[out_id]), 0,
				StringName(str(c.to)), int(c.to_port))
	_remove_node_by_name(str(cnode.name))
	_toast('Unpacked "%s" for editing — Ctrl+G re-saves it (name pre-filled).' % str((data as Dictionary).get("name", "?")))
	_mark_dirty()


func _delete_selected_library_condition() -> void:
	var sel: PackedInt32Array = lib_list.get_selected_items()
	if sel.is_empty():
		_toast("Pick a condition in the list first.")
		return
	var cname: String = lib_list.get_item_text(sel[0]).trim_suffix("  (number)")
	library.remove_condition(cname)
	_toast('Deleted "%s" from the library. Existing references now evaluate as unknown.' % cname)
	_mark_dirty()


func _refresh_library_list() -> void:
	if lib_list == null:
		return
	lib_list.clear()
	for cname: String in library.names():
		var data: Variant = library.get_condition(cname)
		var suffix: String = "  (number)" \
			if data is Dictionary and str((data as Dictionary).get("output_type", "bool")) == "float" else ""
		lib_list.add_item(cname + suffix)
	if graph != null:
		for n: BBNode in _all_bb_nodes():
			if n is BBConditionNode:
				(n as BBConditionNode).rebuild_preview()


# ---------------------------------------------------------------- evaluation

func _mark_dirty() -> void:
	_scan_for_timers()
	edited.emit()
	if _dirty:
		return
	_dirty = true
	call_deferred("_reevaluate")


## Enables the periodic tick when any ⏱ node exists in the graph or inside
## any saved condition, so holds count down and expire without user input.
func _scan_for_timers() -> void:
	_has_timers = false
	if graph != null:
		for n: BBNode in _all_bb_nodes():
			if n is BBTimerNode:
				_has_timers = true
				return
	for cname: String in library.names():
		var data: Variant = library.get_condition(cname)
		if not (data is Dictionary):
			continue
		for nd: Dictionary in (data as Dictionary).get("nodes", []):
			if str(nd.get("type", "")) == "timer":
				_has_timers = true
				return


func _reevaluate() -> void:
	_dirty = false
	var conns: Array = _conns()
	var incoming: Dictionary = {}
	for c: Dictionary in conns:
		if not incoming.has(c.to):
			incoming[c.to] = {}
		incoming[c.to][int(c.to_port)] = [c.from, int(c.from_port)]
	var memo: Dictionary = {}
	var cycle: Dictionary = {"hit": false}
	for n: BBNode in _all_bb_nodes():
		var _v: Variant = _eval_live(str(n.name), incoming, memo, {}, cycle)
	for c: Dictionary in conns:
		var wv: Variant = memo.get(c.from)
		graph.set_connection_activity(StringName(str(c.from)), int(c.from_port),
			StringName(str(c.to)), int(c.to_port),
			1.0 if (wv is bool and bool(wv)) else 0.0)
	for n: BBNode in _all_bb_nodes():
		if n is BBConditionNode:
			(n as BBConditionNode).refresh_preview()
	if bool(cycle.hit) and not _cycle_warned:
		_cycle_warned = true
		_toast("Cycle detected — looped wires evaluate as unknown.")
	elif not bool(cycle.hit):
		_cycle_warned = false


func _eval_live(nm: String, incoming: Dictionary, memo: Dictionary,
		visiting: Dictionary, cycle: Dictionary) -> Variant:
	if memo.has(nm):
		return memo[nm]
	if visiting.has(nm):
		cycle.hit = true
		return null
	var node: BBNode = _bb(nm)
	if node == null:
		memo[nm] = null
		return null
	visiting[nm] = true
	var cnt: int = node.input_count()
	var values: Array = []
	var connected: Array = []
	var inc: Dictionary = incoming.get(nm, {})
	for p: int in cnt:
		if inc.has(p):
			connected.append(true)
			values.append(_eval_live(inc[p][0], incoming, memo, visiting, cycle))
		else:
			connected.append(false)
			values.append(null)
	var v: Variant = BBEval.compute(node.bb_type, node.get_params(), values,
		world, library, [], node.eval_state)
	visiting.erase(nm)
	memo[nm] = v
	node.on_inputs(values, connected)
	node.on_value(v)
	return v


# --------------------------------------------------------------- debug export

func _copy_debug_node(n: BBNode) -> void:
	var incoming: Dictionary = _incoming_map()
	var payload: Dictionary = {
		"node": _debug_dict(str(n.name), incoming, 0),
		"world": world.snapshot(),
	}
	DisplayServer.clipboard_set(JSON.stringify(payload, "  "))
	_toast("Debug JSON for %s copied — paste it into a chat with Claude." % n.title)


func _copy_debug_selection() -> void:
	var sel: Array = _selected_bb_nodes()
	if sel.is_empty():
		_toast("Select node(s) first, then Ctrl+Shift+C.")
		return
	var incoming: Dictionary = _incoming_map()
	var payload: Dictionary = {
		"nodes": sel.map(func(n: BBNode) -> Dictionary:
			return _debug_dict(str(n.name), incoming, 0)),
		"world": world.snapshot(),
	}
	DisplayServer.clipboard_set(JSON.stringify(payload, "  "))
	_toast("Debug JSON for %d node(s) copied." % sel.size())


func _copy_graph_json() -> void:
	var data: Dictionary = _serialize_nodes(_all_bb_nodes())
	var payload: Dictionary = {
		"graph": data,
		"world": world.snapshot(),
		"library": library.all_condition_data(),
	}
	DisplayServer.clipboard_set(JSON.stringify(payload, "  "))
	_toast("Whole graph + world + library copied as JSON.")


func _incoming_map() -> Dictionary:
	var incoming: Dictionary = {}
	for c: Dictionary in _conns():
		if not incoming.has(c.to):
			incoming[c.to] = {}
		incoming[c.to][int(c.to_port)] = [c.from, int(c.from_port)]
	return incoming


func _debug_dict(nm: String, incoming: Dictionary, depth: int) -> Dictionary:
	var n: BBNode = _bb(nm)
	if n == null or depth > 24:
		return {"id": nm, "note": "missing or too deep"}
	var d: Dictionary = {
		"id": nm,
		"type": n.bb_type,
		"params": n.get_params(),
		"value": n.last_value,
	}
	if n is BBConditionNode:
		d["condition_name"] = (n as BBConditionNode).cond_name
		d["definition"] = library.get_condition((n as BBConditionNode).cond_name)
	var ins: Array = []
	var inc: Dictionary = incoming.get(nm, {})
	for p: int in n.input_count():
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
	if _toast_tween != null:
		_toast_tween.kill()
	status.modulate = Color(1.0, 1.0, 0.55)
	_toast_tween = create_tween()
	var _t: PropertyTweener = _toast_tween.tween_property(status, "modulate", Color.WHITE, 1.4)
