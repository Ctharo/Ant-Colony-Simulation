class_name BBConstantNode
extends BBNode
## Literal number. Output: float. Handy for wiring into COMPARE's B port.

var spin: SpinBox


func _init() -> void:
	bb_type = "constant"
	title = "CONSTANT"


func _build() -> void:
	spin = SpinBox.new()
	spin.min_value = -1000.0
	spin.max_value = 1000.0
	spin.step = 0.1
	spin.custom_minimum_size = Vector2(120, 0)
	spin.value_changed.connect(func(_v): params_changed.emit())
	add_child(spin)
	set_slot(0, false, 0, Color.WHITE, true, TYPE_FLOAT, COL_FLOAT)
	_make_value_footer()


func output_type() -> int:
	return TYPE_FLOAT


func get_params() -> Dictionary:
	return {"value": spin.value}


func set_params(p: Dictionary) -> void:
	spin.value = float(p.get("value", 0.0))
