class_name BBConditionNode
extends BBNode
## A saved, named condition collapsed into one node. Output: bool.
## The 👁 titlebar button expands an embedded read-only mini-graph showing the
## nodes that make up the condition — with live values and wire activity — and
## collapses it again. Right-click → "Unpack" restores editable nodes.
##
## Call setup(name, library, world) BEFORE adding to the tree.

var cond_name := ""
var library  # BBConditionLibrary
var world    # BBWorldState
var expanded := false

var _eye_btn: Button
var _preview: GraphEdit
var _preview_value_labels := {}
var _name_label: Label


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


func _build() -> void:
	title = "◈ " + cond_name
	_name_label = Label.new()
	_name_label.text = "OUT ▸ —"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_name_label)
	set_slot(0, false, 0, Color.WHITE, true, TYPE_BOOL, COL_BOOL)
	_make_value_footer()


func output_type() -> int:
	return TYPE_BOOL


func get_params() -> Dictionary:
	return {"name": cond_name}


func set_params(p: Dictionary) -> void:
	cond_name = str(p.get("name", cond_name))
	title = "◈ " + cond_name


func on_value(v) -> void:
	super.on_value(v)
	if _name_label:
		_name_label.text = "OUT ▸ %s" % fmt(v)
		_name_label.add_theme_color_override("font_color", val_color(v))


func _add_title_buttons() -> void:
	var hb := get_titlebar_hbox()
	_eye_btn = Button.new()
	_eye_btn.text = GLYPH_EYE
	_eye_btn.flat = true
	_eye_btn.focus_mode = Control.FOCUS_NONE
	_eye_btn.tooltip_text = "Peek inside — expand/collapse the nodes this condition is made of"
	_eye_btn.pressed.connect(toggle_expanded)
	hb.add_child(_eye_btn)
	super._add_title_buttons()


func toggle_expanded() -> void:
	expanded = not expanded
	if expanded:
		_build_preview()
		refresh_preview()
	elif _preview:
		remove_child(_preview)
		_preview.queue_free()
		_preview = null
		_preview_value_labels.clear()
	size = Vector2.ZERO  # refit to contents


## Re-evaluates the internal subgraph and pushes values into the preview.
## Called by the main controller on every evaluation pass while expanded.
func refresh_preview() -> void:
	if not expanded or _preview == null or library == null:
		return
	var data = library.get_condition(cond_name)
	if data == null:
		return
	var memo := BBEval.eval_graph(data, world, library, [cond_name])
	for id in _preview_value_labels:
		var lbl: Label = _preview_value_labels[id]
		lbl.text = "= %s" % fmt(memo.get(id))
		lbl.add_theme_color_override("font_color", val_color(memo.get(id)))
	for c in data.get("connections", []):
		_preview.set_connection_activity(
			"P_" + str(c.from), 0, "P_" + str(c.to), int(c.to_port),
			1.0 if memo.get(str(c.from)) == true else 0.0)


func _build_preview() -> void:
	if library == null or not library.has_condition(cond_name):
		return
	var data: Dictionary = library.get_condition(cond_name)
	_preview = GraphEdit.new()
	_preview.custom_minimum_size = Vector2(460, 300)
	_preview.minimap_enabled = false
	if _preview.has_method("get_menu_hbox"):
		_preview.get_menu_hbox().visible = false
	_preview_value_labels.clear()

	var minp := Vector2(INF, INF)
	for nd in data.get("nodes", []):
		var gn := GraphNode.new()
		gn.name = "P_" + str(nd.id)
		gn.title = _title_for(nd)
		var pos := Vector2(float(nd.pos[0]), float(nd.pos[1])) * 0.85
		gn.position_offset = pos
		minp = minp.min(pos)
		gn.draggable = false
		gn.selectable = false
		var cnt := int(nd.get("in_count", 0))
		for p in maxi(cnt, 1):
			var l := Label.new()
			l.text = _summary_for(nd) if p == 0 else "·"
			gn.add_child(l)
		var vl := Label.new()
		vl.text = "= —"
		gn.add_child(vl)
		for p in maxi(cnt, 1):
			gn.set_slot(p, p < cnt, 0, Color(0.7, 0.7, 0.7), p == 0, 0, Color(0.7, 0.7, 0.7))
		_preview_value_labels[str(nd.id)] = vl
		_preview.add_child(gn)

	for c in data.get("connections", []):
		_preview.connect_node("P_" + str(c.from), 0, "P_" + str(c.to), int(c.to_port))

	add_child(_preview)
	move_child(_preview, 1)  # between the OUT row and the value footer
	if minp.x != INF:
		_preview.set_deferred("scroll_offset", (minp - Vector2(40, 40)) * _preview.zoom)


static func _title_for(nd: Dictionary) -> String:
	var t := str(nd.type)
	if t == "condition":
		return "◈ " + str(nd.get("params", {}).get("name", "?"))
	return t.to_upper()


static func _summary_for(nd: Dictionary) -> String:
	var p: Dictionary = nd.get("params", {})
	match str(nd.type):
		"world_value":
			return str(p.get("key", ""))
		"compare":
			return "A %s %s" % [p.get("op", "?"), p.get("b", "B")]
		"constant":
			return str(p.get("value", 0))
		"condition":
			return "(nested condition)"
	return " "
