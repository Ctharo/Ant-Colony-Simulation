extends Control
## Behavior Builder — node-graph "do ACTION if CONDITION" prototyping UI.
##
## Interactions:
##   • Right-click empty graph space          → add-node menu
##   • Right-click a node                     → node menu (debug copy, unpack, ...)
##   • Drag port → port                       → wire (one wire per input; new wire replaces)
##   • Drag a wire into empty space           → add-node menu, auto-connects the new node
##   • Drag a node ON TOP of another node     → auto-compose (connects to a free input)
##   • Box-drag / Ctrl+click                  → multi-select
##   • Ctrl+G                                 → save selection as a named, reusable condition
##   • Ctrl+Shift+C                           → copy debug JSON of selection
##   • Ctrl+C / Ctrl+V / Ctrl+D / Delete      → copy / paste / duplicate / delete
##   • 👁 on a condition node                 → expand/collapse its internals
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

var _uid := 0
var _dirty := false
var _cycle_warned := false
var _menu_graph_pos := Vector2.ZERO
var _pending_conn := {}
var _pending_save := {}
var _clipboard := {}
var _ctx_node: BBNode = null
var _toast_tween: Tween

const ADD_ITEMS := [
	["World value", "world_value"],
	["Constant", "constant"],
	["Compare  (A op B → bool)", "compare"],
	["AND", "and"],
	["OR", "or"],
	["NOT", "not"],
	["⚡ Behavior (fires when true)", "behavior"],
]


func _ready() -> void:
	library.load_from_disk()
	_build_ui()
	library.changed.connect(_refresh_library_list)
	world.changed.connect(func(_k, _v): _mark_dirty())
	_refresh_library_list()
	_seed_demo()
	_mark_dirty()


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

	if graph.has_method("get_menu_hbox"):
		var tb: HBoxContainer = graph.get_menu_hbox()
		var b1 := Button.new()
		b1.text = "Copy graph JSON"
		b1.tooltip_text = "Copies the whole visible graph + world snapshot + library — paste it to Claude for debugging"
		b1.pressed.connect(_copy_graph_json)
		tb.add_child(b1)
		var b2 := Button.new()
		b2.text = "Selection → Condition"
		b2.tooltip_text = "Collapse the selected nodes into a named, reusable condition (Ctrl+G)"
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

	side.add_child(_header("WORLD STATE — drag a slider, watch the graph react"))
	for f in BBWorldState.FIELDS:
		side.add_child(_make_slider_row(f))

	side.add_child(HSeparator.new())
	side.add_child(_header("CONDITION LIBRARY — double-click to add to graph"))
	lib_list = ItemList.new()
	lib_list.custom_minimum_size = Vector2(0, 140)
	lib_list.item_activated.connect(func(i):
		_spawn_condition(lib_list.get_item_text(i), _view_center_graph_pos()))
	side.add_child(lib_list)

	var lib_btns := HBoxContainer.new()
	var add_b := Button.new()
	add_b.text = "Add to graph"
	add_b.pressed.connect(func():
		var sel := lib_list.get_selected_items()
		if sel.size() > 0:
			_spawn_condition(lib_list.get_item_text(sel[0]), _view_center_graph_pos())
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
		"• Right-click empty space: add nodes.\n"
		+ "• Drag between ports to wire. Drag a wire into empty space to create + auto-connect a node.\n"
		+ "• Drop a node ON another node to auto-compose into a free input.\n"
		+ "• Box-drag or Ctrl+click to multi-select, then Ctrl+G to collapse the selection into a named condition.\n"
		+ "• 👁 on a condition peeks inside; right-click → Unpack to edit it.\n"
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
	name_dialog.title = "Name this condition"
	name_dialog.min_size = Vector2i(340, 110)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "e.g. IsLowHealth, EnemyNearby, IsCarryingFood"
	name_dialog.add_child(name_edit)
	name_dialog.register_text_enter(name_edit)
	name_dialog.confirmed.connect(_on_name_confirmed)
	add_child(name_dialog)


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
	s.value_changed.connect(func(x):
		val.text = ("%.2f" % x) if f.step < 1.0 else str(int(x))
		world.set_value(f.key, x))
	v.add_child(top)
	v.add_child(s)
	return v


func _seed_demo() -> void:
	var wv := _create_node("world_value", {"key": "health"}, Vector2(80, 120))
	var cmp := _create_node("compare", {"op": "<", "b": 30}, Vector2(380, 100))
	var wv2 := _create_node("world_value", {"key": "enemy_dist"}, Vector2(80, 340))
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
	return n


func _finalize_node(n: BBNode, type: String, pos: Vector2) -> void:
	_uid += 1
	n.name = "%s_%d" % [type, _uid]
	n.position_offset = pos
	graph.add_child(n)
	n.params_changed.connect(_mark_dirty)
	n.copy_debug_requested.connect(_copy_debug_node)
	n.node_context_requested.connect(_open_node_menu)
	_mark_dirty()


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
		add_menu.add_separator("Saved conditions")
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
		var n := _create_node(ADD_ITEMS[id][1], {}, _menu_graph_pos)
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


func _try_pending_connection(n: BBNode) -> void:
	if n == null or _pending_conn.is_empty():
		_pending_conn = {}
		return
	if _pending_conn.has("from"):
		var src := _bb(_pending_conn.from)
		if src:
			for p in n.input_count():
				if n.input_type(p) == src.output_type() and not _port_occupied(str(n.name), p):
					graph.connect_node(_pending_conn.from, _pending_conn.from_port, n.name, p)
					break
	else:
		var dst := _bb(_pending_conn.to)
		if dst and n.output_type() == dst.input_type(_pending_conn.to_port):
			_on_connection_request(n.name, 0, _pending_conn.to, _pending_conn.to_port)
	_pending_conn = {}
	_mark_dirty()


func _open_node_menu(n: BBNode, at_screen: Vector2) -> void:
	_ctx_node = n
	node_menu.clear()
	node_menu.add_item("Copy debug JSON  ⧉", 1)
	if n is BBConditionNode:
		node_menu.add_item("Peek inside  👁", 2)
		node_menu.add_item("Unpack into graph (edit)", 3)
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
				_ctx_node.toggle_expanded()
				(_ctx_node as BBConditionNode).refresh_preview()
		3:
			if _ctx_node is BBConditionNode:
				_unpack_condition(_ctx_node)
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
	var terminals := sel.filter(func(n):
		return n.output_type() == BBNode.TYPE_BOOL and not consumed.has(str(n.name)))
	if terminals.size() != 1:
		_toast("A condition needs exactly ONE final true/false node in the selection (found %d)." % terminals.size())
		return
	_pending_save = {"sel": sel, "output": terminals[0]}
	name_edit.text = ""
	name_dialog.popup_centered()
	name_edit.grab_focus()


func _on_name_confirmed() -> void:
	var cname := name_edit.text.strip_edges()
	if cname == "":
		_toast("Condition needs a name.")
		return
	var sel: Array = _pending_save.get("sel", []).filter(func(n): return is_instance_valid(n))
	var out_node = _pending_save.get("output")
	_pending_save = {}
	if sel.is_empty() or out_node == null or not is_instance_valid(out_node):
		_toast("Selection changed — try again.")
		return

	var overwrote := library.has_condition(cname)
	var data := _serialize_nodes(sel)
	data["output_id"] = str(out_node.name)
	data["name"] = cname
	library.save_condition(cname, data)

	var names := {}
	for n in sel:
		names[str(n.name)] = true
	var external_out := []
	var dropped_in := 0
	for c in _conns():
		var fi: bool = names.has(c.from)
		var ti: bool = names.has(c.to)
		if fi and not ti:
			if c.from == str(out_node.name):
				external_out.append(c)
			graph.disconnect_node(c.from, c.from_port, c.to, c.to_port)
		elif ti and not fi:
			dropped_in += 1
			graph.disconnect_node(c.from, c.from_port, c.to, c.to_port)

	var centroid := Vector2(data.centroid[0], data.centroid[1])
	var cnode := _spawn_condition(cname, centroid)
	for c in external_out:
		graph.connect_node(cnode.name, 0, c.to, c.to_port)

	# Shrink the source nodes into the new condition node.
	for n in sel:
		_disconnect_all(str(n.name))
		n.selected = false
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(n, "position_offset", centroid, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(n, "modulate:a", 0.0, 0.25)
		tw.chain().tween_callback(n.queue_free)

	if dropped_in > 0:
		_toast('Saved "%s" — %d incoming wire(s) from outside the selection were dropped (conditions must be self-contained).' % [cname, dropped_in])
	elif overwrote:
		_toast('Overwrote condition "%s".' % cname)
	else:
		_toast('Saved condition "%s" — reuse it from the library or the right-click menu.' % cname)
	_mark_dirty()


func _unpack_condition(cnode: BBConditionNode) -> void:
	var data = library.get_condition(cnode.cond_name)
	if data == null:
		_toast('"%s" is no longer in the library.' % cnode.cond_name)
		return
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
	_toast('Unpacked "%s" for editing — Ctrl+G to re-save it.' % data.get("name", "?"))
	_mark_dirty()


func _delete_selected_library_condition() -> void:
	var sel := lib_list.get_selected_items()
	if sel.is_empty():
		_toast("Pick a condition in the list first.")
		return
	var cname := lib_list.get_item_text(sel[0])
	library.remove_condition(cname)
	_toast('Deleted "%s" from the library. Existing instances now evaluate as unknown.' % cname)
	_mark_dirty()


func _refresh_library_list() -> void:
	lib_list.clear()
	for cname in library.names():
		lib_list.add_item(cname)


# ---------------------------------------------------------------- evaluation

func _mark_dirty() -> void:
	if _dirty:
		return
	_dirty = true
	call_deferred("_reevaluate")


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
	for c in conns:  # light up wires carrying TRUE
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
	var v = BBEval.compute(node.bb_type, node.get_params(), values, world, library)
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
