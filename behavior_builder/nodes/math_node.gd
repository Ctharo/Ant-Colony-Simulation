class_name BBMathNode
extends BBNode
## A op B -> float, written as a sentence like the compare node:
##     (A ▸) "divided by" [100]  ▸ number
## Lets you build derived values ("expressions"), e.g. health percentage:
##     ANT VALUE(health) → MATH "divided by" ← ANT VALUE(max_health) → MATH "times 100"
## Save the result with Ctrl+G to get a reusable named VALUE (◈ node with a
## float output) you can wire into any compare.
## B can be inline or wired; wired B replaces the spinbox with a live
## "(wired)" read-out, same as COMPARE.

const OPS := ["+", "-", "*", "/", "min", "max"]
const OP_LABELS := ["plus", "minus", "times", "divided by", "min of A and", "max of A and"]

var op_btn: OptionButton
var b_spin: SpinBox
var b_wired_label: Label
var _b_wired := false


func _init() -> void:
	bb_type = "math"
	title = "MATH"


func _build() -> void:
	var sentence := HBoxContainer.new()
	sentence.add_theme_constant_override("separation", 6)

	var a_lab := Label.new()
	a_lab.text = "value"
	a_lab.tooltip_text = "Wire any number (A) into the port on the left"
	sentence.add_child(a_lab)

	op_btn = OptionButton.new()
	op_btn.focus_mode = Control.FOCUS_NONE
	for o in OP_LABELS:
		op_btn.add_item(o)
	op_btn.select(0)
	op_btn.item_selected.connect(func(_i): params_changed.emit())
	sentence.add_child(op_btn)

	b_spin = SpinBox.new()
	b_spin.min_value = -100000.0
	b_spin.max_value = 100000.0
	b_spin.step = 0.1
	b_spin.custom_minimum_size = Vector2(90, 0)
	b_spin.value_changed.connect(func(_v): params_changed.emit())
	sentence.add_child(b_spin)

	b_wired_label = Label.new()
	b_wired_label.visible = false
	b_wired_label.add_theme_color_override("font_color", COL_FLOAT)
	b_wired_label.tooltip_text = "B is wired — this is the live value coming in on the B port below.\nDisconnect the wire to go back to typing a number."
	sentence.add_child(b_wired_label)

	add_child(sentence)  # slot 0 — input port 0 (A), output port 0 (float)

	var b_row := Label.new()
	b_row.text = "▸ or wire a number in here as B"
	b_row.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66))
	add_child(b_row)  # slot 1 — input port 1 (B)

	set_slot(0, true, TYPE_FLOAT, COL_FLOAT, true, TYPE_FLOAT, COL_FLOAT)
	set_slot(1, true, TYPE_FLOAT, COL_FLOAT, false, 0, Color.WHITE)
	_make_value_footer()


func input_count() -> int:
	return 2


func input_type(_port: int) -> int:
	return TYPE_FLOAT


func output_type() -> int:
	return TYPE_FLOAT


func get_params() -> Dictionary:
	return {"op": OPS[op_btn.selected], "b": b_spin.value}


func set_params(p: Dictionary) -> void:
	var i := OPS.find(str(p.get("op", "+")))
	if i >= 0:
		op_btn.select(i)
	b_spin.value = float(p.get("b", 0.0))


func on_inputs(values: Array, connected: Array) -> void:
	super.on_inputs(values, connected)
	var b_wired: bool = connected.size() > 1 and connected[1]
	if b_wired:
		b_wired_label.text = "%s  (wired)" % fmt(values[1] if values.size() > 1 else null)
	if b_wired != _b_wired:
		_b_wired = b_wired
		b_spin.visible = not b_wired
		b_wired_label.visible = b_wired
		size = Vector2.ZERO
