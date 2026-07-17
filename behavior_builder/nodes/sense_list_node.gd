class_name BBSenseListNode
extends BBNode
## 👁 SENSE — the entry point of the list pipeline. Reads one sensed list
## from the world state (mock entities in the builder; AntPerception-derived
## dictionaries in-game). Output: LIST (violet).
##
## Typical chain:  SENSE → FILTER → SORT → PICK → ITEM VALUE / BEHAVIOR target.

var option: OptionButton

var _sources: Array[Dictionary] = []


func _init() -> void:
	bb_type = "sense_list"
	title = "👁 SENSE"


func _build() -> void:
	option = OptionButton.new()
	option.custom_minimum_size = Vector2(180.0, 0.0)
	option.focus_mode = Control.FOCUS_NONE
	var _err: Error = option.item_selected.connect(
		func(_index: int) -> void: params_changed.emit())
	add_child(option)  # slot 0 — output port 0 (list)
	set_slot(0, false, 0, Color.WHITE, true, TYPE_LIST, COL_LIST)
	_make_value_footer()
	_populate()


func _populate() -> void:
	_sources = BBWorldState.LIST_SOURCES.duplicate()
	option.clear()
	for src: Dictionary in _sources:
		option.add_item(str(src.label))
	if not _sources.is_empty():
		option.select(0)


func output_type() -> int:
	return TYPE_LIST


func get_params() -> Dictionary:
	var source_key: String = "ants_in_view"
	if option.selected >= 0 and option.selected < _sources.size():
		source_key = str(_sources[option.selected].key)
	return {"source": source_key}


func set_params(p: Dictionary) -> void:
	var source_key: String = str(p.get("source", "ants_in_view"))
	for i: int in _sources.size():
		if str(_sources[i].key) == source_key:
			option.select(i)
			return
