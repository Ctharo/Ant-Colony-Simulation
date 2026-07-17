class_name BBPickNode
extends BBNode
## PICK — list in, ONE item out (teal ENTITY port). Empty list → null,
## which degrades safely downstream: ITEM VALUE of null is unknown, and a
## COMPARE on unknown is unknown — the same contract as Vector2.INF in
## AntSenses, so no separate emptiness check is ever required (though you
## can gate on COUNT explicitly if you want the graph to read that way).
##
## "nearest"/"farthest" use the item's distance property directly; use
## SORT (by any key, including ◈ values) + "first in list" for everything else.

const MODES: Array[String] = ["nearest", "farthest", "first"]
const MODE_LABELS: Array[String] = ["nearest", "farthest", "first in list"]

var mode_btn: OptionButton


func _init() -> void:
	bb_type = "pick"
	title = "PICK"


func _build() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var take_lab: Label = Label.new()
	take_lab.text = "take the"
	take_lab.tooltip_text = "Wire a list into the port on the left"
	row.add_child(take_lab)
	mode_btn = OptionButton.new()
	mode_btn.focus_mode = Control.FOCUS_NONE
	for mode_label: String in MODE_LABELS:
		mode_btn.add_item(mode_label)
	mode_btn.select(0)
	var _err: Error = mode_btn.item_selected.connect(
		func(_index: int) -> void: params_changed.emit())
	row.add_child(mode_btn)
	add_child(row)  # slot 0 — input port 0 (list), output port 0 (entity)

	set_slot(0, true, TYPE_LIST, COL_LIST, true, TYPE_ENTITY, COL_ENTITY)
	_make_value_footer()


func input_count() -> int:
	return 1


func input_type(_port: int) -> int:
	return TYPE_LIST


func output_type() -> int:
	return TYPE_ENTITY


func get_params() -> Dictionary:
	var mode: String = MODES[mode_btn.selected] if mode_btn.selected >= 0 else "nearest"
	return {"mode": mode}


func set_params(p: Dictionary) -> void:
	var mode_index: int = MODES.find(str(p.get("mode", "nearest")))
	if mode_index >= 0:
		mode_btn.select(mode_index)
