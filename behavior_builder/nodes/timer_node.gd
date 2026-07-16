class_name BBTimerNode
extends BBNode
## ⏱ HOLD TRUE: once the input turns TRUE, the output stays TRUE for N
## seconds regardless of the input; only after the hold expires does it
## re-consider the input. Great for de-flickering conditions ("commit to
## fleeing for 3 seconds instead of flip-flopping every tick").
##
## State lives in [member BBNode.eval_state] (live nodes) or BBEval's shared
## state store (saved conditions) — see BBEval "timer" for the semantics.

var seconds_spin: SpinBox
var out_label: Label


func _init() -> void:
	bb_type = "timer"
	title = "⏱ HOLD TRUE"


func _build() -> void:
	var when := Label.new()
	when.text = "WHEN (true/false)"
	add_child(when)  # slot 0 — input port 0 (bool)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var pre := Label.new()
	pre.text = "stay TRUE for"
	row.add_child(pre)
	seconds_spin = SpinBox.new()
	seconds_spin.min_value = 0.1
	seconds_spin.max_value = 600.0
	seconds_spin.step = 0.1
	seconds_spin.value = 3.0
	seconds_spin.custom_minimum_size = Vector2(85, 0)
	seconds_spin.value_changed.connect(func(_v): params_changed.emit())
	row.add_child(seconds_spin)
	var post := Label.new()
	post.text = "s"
	row.add_child(post)
	add_child(row)  # slot 1 — no ports

	out_label = Label.new()
	out_label.text = "OUT ▸ —"
	out_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(out_label)  # slot 2 — output port 0 (bool)

	set_slot(0, true, TYPE_BOOL, COL_BOOL, false, 0, Color.WHITE)
	set_slot(2, false, 0, Color.WHITE, true, TYPE_BOOL, COL_BOOL)
	_make_value_footer()


func input_count() -> int:
	return 1


func input_type(_port: int) -> int:
	return TYPE_BOOL


func output_type() -> int:
	return TYPE_BOOL


func get_params() -> Dictionary:
	return {"seconds": seconds_spin.value}


func set_params(p: Dictionary) -> void:
	seconds_spin.value = float(p.get("seconds", 3.0))


func on_value(v) -> void:
	super.on_value(v)
	if out_label == null:
		return
	var until := int(eval_state.get("hold_until", 0))
	var remaining := (until - Time.get_ticks_msec()) / 1000.0
	if v is bool and v and remaining > 0.0:
		out_label.text = "OUT ▸ TRUE  (%.1fs held)" % remaining
	else:
		out_label.text = "OUT ▸ %s" % fmt(v)
	out_label.add_theme_color_override("font_color", val_color(v))
