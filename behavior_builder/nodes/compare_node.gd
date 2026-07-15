class_name BBCompareNode
extends BBNode
## Compares two floats -> bool. B can be an inline value OR a wired float
## (wire wins; the spinbox greys out while B is connected).
## Input ports: 0 = A (float), 1 = B (float). Output port 0: bool.

const OPS := [">", "<", ">=", "<=", "==", "!="]

var op_btn: OptionButton
var b_spin: SpinBox
var out_label: Label


func _init() -> void:
	bb_type = "compare"
	title = "COMPARE"


func _build() -> void:
	var a_label := Label.new()
	a_label.text = "A  (number)"
	add_child(a_label)  # slot 0 — input port 0

	op_btn = OptionButton.new()
	op_btn.focus_mode = Control.FOCUS_NONE
	for o in OPS:
		op_btn.add_item(o)
	op_btn.select(1)
	op_btn.item_selected.connect(func(_i): params_changed.emit())
	add_child(op_btn)  # slot 1 — no ports

	var b_row := HBoxContainer.new()
	var b_label := Label.new()
	b_label.text = "B "
	b_spin = SpinBox.new()
	b_spin.min_value = -1000.0
	b_spin.max_value = 1000.0
	b_spin.step = 0.1
	b_spin.custom_minimum_size = Vector2(100, 0)
	b_spin.value_changed.connect(func(_v): params_changed.emit())
	b_row.add_child(b_label)
	b_row.add_child(b_spin)
	add_child(b_row)  # slot 2 — input port 1

	out_label = Label.new()
	out_label.text = "OUT ▸ —"
	out_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(out_label)  # slot 3 — output port 0

	set_slot(0, true, TYPE_FLOAT, COL_FLOAT, false, 0, Color.WHITE)
	set_slot(2, true, TYPE_FLOAT, COL_FLOAT, false, 0, Color.WHITE)
	set_slot(3, false, 0, Color.WHITE, true, TYPE_BOOL, COL_BOOL)
	_make_value_footer()


func input_count() -> int:
	return 2


func input_type(_port: int) -> int:
	return TYPE_FLOAT


func output_type() -> int:
	return TYPE_BOOL


func get_params() -> Dictionary:
	return {"op": OPS[op_btn.selected], "b": b_spin.value}


func set_params(p: Dictionary) -> void:
	var i := OPS.find(str(p.get("op", "<")))
	if i >= 0:
		op_btn.select(i)
	b_spin.value = float(p.get("b", 0.0))


func on_inputs(_values: Array, connected: Array) -> void:
	var b_wired: bool = connected.size() > 1 and connected[1]
	b_spin.editable = not b_wired
	b_spin.tooltip_text = "B is wired — the connection overrides this value" if b_wired else "Inline value (or wire any float into the B port)"


func on_value(v) -> void:
	super.on_value(v)
	if out_label:
		out_label.text = "OUT ▸ %s" % fmt(v)
		out_label.add_theme_color_override("font_color", val_color(v))
