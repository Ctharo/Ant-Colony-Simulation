class_name BBSortNode
extends BBNode
## SORT — list in, same list reordered out. The key is either a built-in
## item property (distance, health, amount, …) or ANY saved ◈ VALUE from
## the library: the value expression is evaluated once per item, with
## world-value reads resolving against the item's own properties first
## (see BBEval.ItemContext). That is the "sort by a function" feature —
## author "threat = 100 / distance * health" as a ◈ value, then sort by it.
##
## SORT + PICK "first in list" ≡ picking min/max of the key.
##
## Call setup_library(library) after _create_node so saved values appear in
## the key dropdown; without it, only built-in properties are listed.

const DIR_LABELS: Array[String] = ["lowest first", "highest first"]

var key_btn: OptionButton
var dir_btn: OptionButton

var _keys: Array[Dictionary] = []  ## [{key, label}]
var _library: Variant = null


func _init() -> void:
	bb_type = "sort"
	title = "SORT"


func setup_library(p_library: Variant) -> void:
	_library = p_library
	if key_btn:
		_populate_keys(_selected_key())


func _build() -> void:
	var row0: HBoxContainer = HBoxContainer.new()
	row0.add_theme_constant_override("separation", 6)
	var by_lab: Label = Label.new()
	by_lab.text = "sort by"
	by_lab.tooltip_text = "Wire a list into the port on the left"
	row0.add_child(by_lab)
	key_btn = OptionButton.new()
	key_btn.focus_mode = Control.FOCUS_NONE
	key_btn.custom_minimum_size = Vector2(150.0, 0.0)
	var _err0: Error = key_btn.item_selected.connect(
		func(_index: int) -> void: params_changed.emit())
	row0.add_child(key_btn)
	add_child(row0)  # slot 0 — input port 0 (list), output port 0 (list)

	dir_btn = OptionButton.new()
	dir_btn.focus_mode = Control.FOCUS_NONE
	for dir_label: String in DIR_LABELS:
		dir_btn.add_item(dir_label)
	dir_btn.select(0)
	var _err1: Error = dir_btn.item_selected.connect(
		func(_index: int) -> void: params_changed.emit())
	add_child(dir_btn)  # slot 1 — no ports

	set_slot(0, true, TYPE_LIST, COL_LIST, true, TYPE_LIST, COL_LIST)
	set_slot(1, false, 0, Color.WHITE, false, 0, Color.WHITE)
	_make_value_footer()
	_populate_keys("distance")


## Built-in float/bool item properties + every float-output ◈ value.
func _populate_keys(preserve_key: String) -> void:
	_keys.clear()
	for prop: Dictionary in BBWorldState.ITEM_PROPS:
		_keys.append({"key": str(prop.key), "label": str(prop.label)})
	if _library != null:
		for cond_name: String in _library.names():
			var data: Dictionary = _library.get_condition(cond_name)
			if str(data.get("output_type", "bool")) == "float":
				_keys.append({"key": "lib:%s" % cond_name, "label": "◈ %s" % cond_name})
	key_btn.clear()
	var select_index: int = 0
	for i: int in _keys.size():
		key_btn.add_item(str(_keys[i].label))
		if str(_keys[i].key) == preserve_key:
			select_index = i
	if not _keys.is_empty():
		key_btn.select(select_index)
	size = Vector2.ZERO


func _selected_key() -> String:
	if key_btn and key_btn.selected >= 0 and key_btn.selected < _keys.size():
		return str(_keys[key_btn.selected].key)
	return "distance"


func input_count() -> int:
	return 1


func input_type(_port: int) -> int:
	return TYPE_LIST


func output_type() -> int:
	return TYPE_LIST


func get_params() -> Dictionary:
	return {"key": _selected_key(), "descending": dir_btn.selected == 1}


func set_params(p: Dictionary) -> void:
	var key: String = str(p.get("key", "distance"))
	_populate_keys(key)
	dir_btn.select(1 if bool(p.get("descending", false)) else 0)
