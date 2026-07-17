class_name BBConditionNode
extends BBNode
## A saved, named condition (or named value/expression) collapsed into one node.
## Output: bool for conditions, float for saved value expressions.
##
## Titlebar buttons:
##   +/−  expands/collapses an organized LIST of the nodes inside — one row
##        per node, indented by how it feeds the output, with live values.
##   ⤢    unpacks the condition back into editable nodes in the graph
##        (same as right-click → Unpack). Re-save with Ctrl+G; the save
##        dialog pre-fills the same name so re-saving is one Enter away.
##
## Call setup(name, library, world) BEFORE adding to the tree.

signal unpack_requested(node: BBConditionNode)

var cond_name := ""
var library  # BBConditionLibrary
var world    # BBWorldState
var expanded := false

var _out_type := TYPE_BOOL
var _expand_btn: Button
var _list: VBoxContainer
var _preview_value_labels := {}
var _name_label: Label
var _ref_glow := false


func _init() -> void:
	bb_type = "condition"


func setup(p_name: String, p_library, p_world) -> void:
	cond_name = p_name
	library = p_library
	world = p_world
	if is_inside_tree():
		title = "◈ " + cond_name
		if _name_label:
			_name_label.text = "OUT ▸ —"
		_sync_output_type()


func _build() -> void:
	title = "◈ " + cond_name
	_name_label = Label.new()
	_name_label.text = "OUT ▸ —"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_name_label)
	_sync_output_type()
	_make_value_footer()


## Reads the saved output type ("bool"/"float") and retypes the output port.
func _sync_output_type() -> void:
	var t := "bool"
	if library and library.has_condition(cond_name):
		t = str(library.get_condition(cond_name).get("output_type", "bool"))
	_out_type = TYPE_FLOAT if t == "float" else TYPE_BOOL
	set_slot(0, false, 0, Color.WHITE, true, _out_type,
		COL_FLOAT if _out_type == TYPE_FLOAT else COL_BOOL)


func output_type() -> int:
	return _out_type


func get_params() -> Dictionary:
	return {"name": cond_name}


func set_params(p: Dictionary) -> void:
	cond_name = str(p.get("name", cond_name))
	title = "◈ " + cond_name
	_sync_output_type()


func on_value(v) -> void:
	super.on_value(v)
	if _name_label:
		_name_label.text = "OUT ▸ %s" % fmt(v)
		_name_label.add_theme_color_override("font_color", val_color(v))


## Golden tint used by the builder to highlight every instance (reference)
## of the same condition when one of them is selected.
func set_reference_glow(on: bool) -> void:
	if _ref_glow == on:
		return
	_ref_glow = on
	refresh_style()


## Gold border on the UNSELECTED style marks "another reference of the
## selected ◈ condition". Selection itself stays white via the base class.
func _style_extra(panel: StyleBoxFlat, tbar: StyleBoxFlat) -> void:
	if _ref_glow:
		BBNode.apply_reference_border(panel, tbar)


func _add_title_buttons() -> void:
	var hb := get_titlebar_hbox()
	_expand_btn = Button.new()
	_expand_btn.text = GLYPH_EXPAND
	_expand_btn.flat = true
	_expand_btn.focus_mode = Control.FOCUS_NONE
	_expand_btn.tooltip_text = "Show what's inside — expands an organized list of the contained nodes with live values"
	_expand_btn.pressed.connect(toggle_expanded)
	hb.add_child(_expand_btn)

	var unpack_btn := Button.new()
	unpack_btn.text = GLYPH_UNPACK
	unpack_btn.flat = true
	unpack_btn.focus_mode = Control.FOCUS_NONE
	unpack_btn.tooltip_text = "Unpack into the graph for editing (Ctrl+G afterwards re-saves it under the same name)"
	unpack_btn.pressed.connect(func(): unpack_requested.emit(self))
	hb.add_child(unpack_btn)

	super._add_title_buttons()


func toggle_expanded() -> void:
	expanded = not expanded
	_expand_btn.text = GLYPH_COLLAPSE if expanded else GLYPH_EXPAND
	if expanded:
		_build_list()
		refresh_preview()
	elif _list:
		remove_child(_list)
		_list.queue_free()
		_list = null
		_preview_value_labels.clear()
	size = Vector2.ZERO  # refit to contents


## Rebuilds the list from the (possibly changed) library definition.
## Called when the library changes so expanded instances don't show stale structure.
func rebuild_preview() -> void:
	_sync_output_type()
	if not expanded:
		return
	if _list:
		remove_child(_list)
		_list.queue_free()
		_list = null
		_preview_value_labels.clear()
	_build_list()
	refresh_preview()
	size = Vector2.ZERO


## Re-evaluates the internal subgraph and pushes live values into the list.
## Called by the main controller on every evaluation pass while expanded.
func refresh_preview() -> void:
	if not expanded or _list == null or library == null:
		return
	var data = library.get_condition(cond_name)
	if data == null:
		return
	var memo := BBEval.eval_graph(data, world, library, [cond_name])
	for id in _preview_value_labels:
		var lbl: Label = _preview_value_labels[id]
		lbl.text = "= %s" % fmt(memo.get(id))
		lbl.add_theme_color_override("font_color", val_color(memo.get(id)))


# --------------------------------------------------------------- list view

func _build_list() -> void:
	if library == null or not library.has_condition(cond_name):
		return
	var data: Dictionary = library.get_condition(cond_name)

	var nodes: Dictionary = {}
	for nd: Dictionary in data.get("nodes", []):
		nodes[str(nd.id)] = nd
	var incoming: Dictionary = {}
	for c: Dictionary in data.get("connections", []):
		var to_id: String = str(c.to)
		if not incoming.has(to_id):
			incoming[to_id] = {}
		incoming[to_id][int(c.to_port)] = str(c.from)

	var rows: Array = []
	var seen: Dictionary = {}
	var output_id: String = str(data.get("output_id", ""))
	_collect_rows(output_id, nodes, incoming, 0, rows, seen)
	var leftovers: Array = []
	for leftover_id: String in nodes:
		if not seen.has(leftover_id):
			leftovers.append(leftover_id)
	if not leftovers.is_empty():
		rows.append({"separator": "not wired to the output"})
		for leftover_id: String in leftovers:
			if not seen.has(leftover_id):
				_collect_rows(leftover_id, nodes, incoming, 1, rows, seen)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.custom_minimum_size = Vector2(260, 0)

	for r: Dictionary in rows:
		if r.has("separator"):
			var sep: Label = Label.new()
			sep.text = "— %s —" % r.separator
			sep.add_theme_color_override("font_color", Color(0.55, 0.5, 0.5))
			_list.add_child(sep)
			continue
		var row_id: String = str(r.id)
		var nd: Dictionary = nodes[row_id]
		var is_repeat: bool = bool(r.get("repeat", false))
		# The root row's value is already shown by this node's own OUT
		# header, so don't re-render it here — that's what caused the
		# "twice as many falses" count.
		var is_root: bool = not is_repeat and row_id == output_id
		var hb: HBoxContainer = HBoxContainer.new()
		var lab: Label = Label.new()
		var indent: String = "    ".repeat(int(r.depth))
		var branch: String = "└ " if int(r.depth) > 0 else ""
		if is_repeat:
			lab.text = "%s%s↺ %s (shown above)" % [indent, branch, _title_for(nd)]
			lab.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		else:
			lab.text = "%s%s%s" % [indent, branch, _row_text(row_id, nd, nodes, incoming)]
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(lab)
		if not is_root:
			var vl: Label = Label.new()
			vl.text = "= —"
			vl.add_theme_color_override("font_color", COL_NULL)
			hb.add_child(vl)
			if not is_repeat and not _preview_value_labels.has(row_id):
				_preview_value_labels[row_id] = vl
		_list.add_child(hb)

	add_child(_list)
	move_child(_list, 1)


static func _row_text(id: String, nd: Dictionary, nodes: Dictionary, incoming: Dictionary) -> String:
	var node_type: String = str(nd.type)
	if node_type == "compare" or node_type == "math":
		return _sentence_for(id, nd, nodes, incoming)
	var s: String = _summary_for(nd)
	if s.strip_edges().is_empty():
		return _title_for(nd)
	return "%s  %s" % [_title_for(nd), s]


## Builds a single natural-language sentence with the wired variable's name
## in place of the generic "A" — e.g. "Compare enemy_dist is less than 30.0".
static func _sentence_for(id: String, nd: Dictionary, nodes: Dictionary, incoming: Dictionary) -> String:
	var p: Dictionary = nd.get("params", {})
	var a_text: String = _variable_name_for(id, 0, incoming, nodes)
	var b_text: String = _b_text_for(id, incoming, nodes, p)
	if str(nd.type) == "compare":
		var i: int = BBCompareNode.OPS.find(str(p.get("op", "<")))
		var opl: String = BBCompareNode.OP_LABELS[i] if i >= 0 else str(p.get("op", "?"))
		return "Compare %s %s %s" % [a_text, opl, b_text]
	var j: int = BBMathNode.OPS.find(str(p.get("op", "+")))
	var opl2: String = BBMathNode.OP_LABELS[j] if j >= 0 else str(p.get("op", "?"))
	return "%s %s %s" % [a_text, opl2, b_text]


static func _b_text_for(id: String, incoming: Dictionary, nodes: Dictionary, p: Dictionary) -> String:
	var inc: Dictionary = incoming.get(id, {})
	if inc.has(1):
		return _variable_name_for(id, 1, incoming, nodes)
	return str(p.get("b", 0.0))


## Resolves what's wired into a given port to a readable name: a world/ant
## value's key, a constant's literal, a nested condition's name, or —
## recursively — a math node's own sentence. Falls back to "value" for
## anything unwired or unrecognized.
static func _variable_name_for(id: String, port: int, incoming: Dictionary, nodes: Dictionary) -> String:
	var inc: Dictionary = incoming.get(id, {})
	if not inc.has(port):
		return "value"
	var src_id: String = str(inc[port])
	if not nodes.has(src_id):
		return "value"
	var src: Dictionary = nodes[src_id]
	var sp: Dictionary = src.get("params", {})
	match str(src.type):
		"world_value":
			return str(sp.get("key", "value"))
		"constant":
			return str(sp.get("value", 0))
		"condition":
			return "◈ " + str(sp.get("name", "condition"))
		"math":
			return _sentence_for(src_id, src, nodes, incoming)
		_:
			return "value"

func _collect_rows(id: String, nodes: Dictionary, incoming: Dictionary, depth: int, rows: Array, seen: Dictionary) -> void:
	if id == "" or not nodes.has(id) or depth > 24:
		return
	if seen.has(id):
		rows.append({"id": id, "depth": depth, "repeat": true})
		return
	seen[id] = true
	rows.append({"id": id, "depth": depth})
	var inc: Dictionary = incoming.get(id, {})
	var ports := inc.keys()
	ports.sort()
	for p in ports:
		_collect_rows(str(inc[p]), nodes, incoming, depth + 1, rows, seen)

static func _title_for(nd: Dictionary) -> String:
	var t := str(nd.type)
	if t == "condition":
		return "◈ " + str(nd.get("params", {}).get("name", "?"))
	if t == "world_value":
		var g := str(nd.get("params", {}).get("group", BBWorldState.group_of(str(nd.get("params", {}).get("key", "")))))
		return "ANT VALUE" if g == "ant" else "WORLD VALUE"
	if t == "timer":
		return "⏱ HOLD"
	return t.to_upper()


static func _summary_for(nd: Dictionary) -> String:
	var p: Dictionary = nd.get("params", {})
	match str(nd.type):
		"world_value":
			return str(p.get("key", ""))
		"compare":
			var i := BBCompareNode.OPS.find(str(p.get("op", "<")))
			var opl: String = BBCompareNode.OP_LABELS[i] if i >= 0 else str(p.get("op", "?"))
			return "A %s %s" % [opl, p.get("b", "B")]
		"math":
			var j := BBMathNode.OPS.find(str(p.get("op", "+")))
			var opl2: String = BBMathNode.OP_LABELS[j] if j >= 0 else str(p.get("op", "?"))
			return "A %s %s" % [opl2, p.get("b", "B")]
		"timer":
			return "for %.1fs" % float(p.get("seconds", 3.0))
		"constant":
			return str(p.get("value", 0))
		"condition":
			return ""
	return ""
