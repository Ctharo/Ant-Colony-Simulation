class_name BBWorldValueNode
extends BBNode
## Reads one field of the world state. Output: float.

var option: OptionButton


func _init() -> void:
	bb_type = "world_value"
	title = "WORLD VALUE"


func _build() -> void:
	option = OptionButton.new()
	option.custom_minimum_size = Vector2(180, 0)
	option.focus_mode = Control.FOCUS_NONE
	for f in BBWorldState.FIELDS:
		option.add_item(f.label)
	option.select(0)
	option.item_selected.connect(func(_i): params_changed.emit())
	add_child(option)
	set_slot(0, false, 0, Color.WHITE, true, TYPE_FLOAT, COL_FLOAT)
	_make_value_footer()


func output_type() -> int:
	return TYPE_FLOAT


func get_params() -> Dictionary:
	return {"key": BBWorldState.FIELDS[option.selected].key}


func set_params(p: Dictionary) -> void:
	var key := str(p.get("key", "health"))
	for i in BBWorldState.FIELDS.size():
		if BBWorldState.FIELDS[i].key == key:
			option.select(i)
			return
