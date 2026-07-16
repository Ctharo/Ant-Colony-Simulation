class_name BBLogicNode
extends BBNode
## AND / OR / NOT. Bool inputs, one bool output on the clearly-labelled OUT row.
## AND/OR grow a fresh free input whenever all ports are wired, and shrink back
## when trailing ports free up — so there's always exactly one open slot ready.
## Unwired inputs are simply ignored during evaluation.
##
## Set bb_type to "and" / "or" / "not" BEFORE adding to the tree.

var out_label: Label
var add_btn: Button
var _input_labels: Array = []


func _build() -> void:
	title = bb_type.to_upper()
	var start := 1 if bb_type == "not" else 2
	for i in start:
		_append_input_row()

	out_label = Label.new()
	out_label.text = "OUT ▸ —"
	out_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(out_label)

	if bb_type != "not":
		add_btn = Button.new()
		add_btn.text = "+ input"
		add_btn.flat = true
		add_btn.focus_mode = Control.FOCUS_NONE
		add_btn.tooltip_text = "Add another input port (also happens automatically when all ports are wired)"
		add_btn.pressed.connect(func():
			set_input_count(_input_labels.size() + 1)
			params_changed.emit())
		add_child(add_btn)

	_make_value_footer()
	_refresh_slots()


func input_count() -> int:
	return _input_labels.size()


func input_type(_port: int) -> int:
	return TYPE_BOOL


func output_type() -> int:
	return TYPE_BOOL


func get_params() -> Dictionary:
	return {"inputs": _input_labels.size()}


func set_params(p: Dictionary) -> void:
	set_input_count(int(p.get("inputs", 2)))


func set_input_count(n: int) -> void:
	var lo := 1 if bb_type == "not" else 2
	n = clampi(n, lo, 8)
	while _input_labels.size() < n:
		_append_input_row()
	while _input_labels.size() > n:
		var l: Label = _input_labels.pop_back()
		remove_child(l)
		l.queue_free()
	for i in _input_labels.size():
		_input_labels[i].text = "IN %d" % (i + 1)
	_refresh_slots()
	size = Vector2.ZERO  # shrink-to-fit


func on_inputs(values: Array, connected: Array) -> void:
	if bb_type != "not":
		var last_wired := -1
		var all_wired := connected.size() > 0
		for i in connected.size():
			if connected[i]:
				last_wired = i
			else:
				all_wired = false
		var target := connected.size() + 1 if all_wired else maxi(2, last_wired + 2)
		target = mini(target, 8)
		if target != _input_labels.size():
			set_input_count(target)
	# Base class colors each connected input port from the value flowing in
	# (green/red for bools), so the wires light up. Runs AFTER any resize.
	super.on_inputs(values, connected)


func on_value(v) -> void:
	super.on_value(v)
	if out_label:
		out_label.text = "OUT ▸ %s" % fmt(v)
		out_label.add_theme_color_override("font_color", val_color(v))


func _append_input_row() -> void:
	var l := Label.new()
	l.text = "IN %d" % (_input_labels.size() + 1)
	_input_labels.append(l)
	add_child(l)
	move_child(l, _input_labels.size() - 1)  # keep inputs as the first rows


func _refresh_slots() -> void:
	clear_all_slots()
	for i in _input_labels.size():
		set_slot(i, true, TYPE_BOOL, COL_BOOL, false, 0, Color.WHITE)
	set_slot(_input_labels.size(), false, 0, Color.WHITE, true, TYPE_BOOL, COL_BOOL)
