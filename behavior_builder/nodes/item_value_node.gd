class_name BBItemValueNode
extends BBNode
## ITEM VALUE — reads one property off a picked item (ENTITY in). The output
## port RETYPES with the property: float props (distance, health, …) output
## a number, bool props (is_ally, …) output true/false, so "picked ant is
## NOT an ally" is just ITEM VALUE(is_ally) → NOT.
##
## Because changing the property can change the output type, the builder
## drops any outgoing wire whose destination no longer matches (see the
## params_changed handler in behavior_builder.gd). Null item in → unknown out.

var prop_btn: OptionButton

var _props: Array[Dictionary] = []
var _out_type: int = TYPE_FLOAT


func _init() -> void:
	bb_type = "item_value"
	title = "ITEM VALUE"


func _build() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var read_lab: Label = Label.new()
	read_lab.text = "of the item, read"
	read_lab.tooltip_text = "Wire a picked item (teal) into the port on the left"
	row.add_child(read_lab)
	prop_btn = OptionButton.new()
	prop_btn.focus_mode = Control.FOCUS_NONE
	var _err: Error = prop_btn.item_selected.connect(
		func(_index: int) -> void:
			_sync_output_type()
			params_changed.emit())
	row.add_child(prop_btn)
	add_child(row)  # slot 0 — input port 0 (entity), output port 0 (float|bool)

	set_slot(0, true, TYPE_ENTITY, COL_ENTITY, true, TYPE_FLOAT, COL_FLOAT)
	_make_value_footer()
	_populate_props()
	_sync_output_type()


func _populate_props() -> void:
	_props = BBWorldState.ITEM_PROPS.duplicate()
	prop_btn.clear()
	for prop: Dictionary in _props:
		prop_btn.add_item(str(prop.label))
	if not _props.is_empty():
		prop_btn.select(0)


func _selected_prop_key() -> String:
	if prop_btn.selected >= 0 and prop_btn.selected < _props.size():
		return str(_props[prop_btn.selected].key)
	return "distance"


func _sync_output_type() -> void:
	var is_bool: bool = BBWorldState.prop_type(_selected_prop_key()) == "bool"
	_out_type = TYPE_BOOL if is_bool else TYPE_FLOAT
	set_slot(0, true, TYPE_ENTITY, COL_ENTITY, true, _out_type, port_color(_out_type))


func input_count() -> int:
	return 1


func input_type(_port: int) -> int:
	return TYPE_ENTITY


func output_type() -> int:
	return _out_type


func get_params() -> Dictionary:
	return {"prop": _selected_prop_key()}


func set_params(p: Dictionary) -> void:
	var prop_key: String = str(p.get("prop", "distance"))
	for i: int in _props.size():
		if str(_props[i].key) == prop_key:
			prop_btn.select(i)
			break
	_sync_output_type()
