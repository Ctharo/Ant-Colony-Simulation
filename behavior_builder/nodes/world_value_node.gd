class_name BBWorldValueNode
extends BBNode
## Reads one field of the world state. Output: float.
## Comes in two flavours via [member group]: "world" (sensed surroundings)
## and "ant" (own body & vitals). Same underlying storage, but each flavour
## only lists its own keys and gets its own titlebar color, so authored
## graphs read clearly: ANT VALUE(health) vs WORLD VALUE(enemy_dist).

var option: OptionButton
var group := "world"
var _fields: Array = []


func _init() -> void:
	bb_type = "world_value"
	title = "WORLD VALUE"


func _build() -> void:
	option = OptionButton.new()
	option.custom_minimum_size = Vector2(180, 0)
	option.focus_mode = Control.FOCUS_NONE
	option.item_selected.connect(func(_i): params_changed.emit())
	add_child(option)
	set_slot(0, false, 0, Color.WHITE, true, TYPE_FLOAT, COL_FLOAT)
	_make_value_footer()
	_populate()


func _populate() -> void:
	_fields = BBWorldState.fields_in_group(group)
	option.clear()
	for f in _fields:
		option.add_item(f.label)
	if _fields.size() > 0:
		option.select(0)
	title = "ANT VALUE" if group == "ant" else "WORLD VALUE"


func _titlebar_color() -> Color:
	return TITLE_COLORS.get("ant_value" if group == "ant" else "world_value", Color(0.2, 0.22, 0.28))


func output_type() -> int:
	return TYPE_FLOAT


func get_params() -> Dictionary:
	var key: String = _fields[option.selected].key if option.selected >= 0 and option.selected < _fields.size() else "health"
	return {"key": key, "group": group}


func set_params(p: Dictionary) -> void:
	var key := str(p.get("key", "health"))
	# Old saves have no "group" — derive it from the key so they still load.
	var g := str(p.get("group", BBWorldState.group_of(key)))
	if g != group:
		group = g
		if option:
			_populate()
			if is_inside_tree():
				refresh_style()
	for i in _fields.size():
		if _fields[i].key == key:
			option.select(i)
			return
