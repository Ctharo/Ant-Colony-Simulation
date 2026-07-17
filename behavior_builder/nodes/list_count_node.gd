class_name BBListCountNode
extends BBNode
## COUNT — list in, number of items out. The bridge from the list pipeline
## back into plain float logic: "enemies_in_view_count > 2" becomes
## SENSE(ants) → FILTER is_ally is FALSE → COUNT → COMPARE > 2.

func _init() -> void:
	bb_type = "list_count"
	title = "COUNT"


func _build() -> void:
	var lab: Label = Label.new()
	lab.text = "number of items"
	lab.tooltip_text = "Wire a list into the port on the left"
	add_child(lab)  # slot 0 — input port 0 (list), output port 0 (float)
	set_slot(0, true, TYPE_LIST, COL_LIST, true, TYPE_FLOAT, COL_FLOAT)
	_make_value_footer()


func input_count() -> int:
	return 1


func input_type(_port: int) -> int:
	return TYPE_LIST


func output_type() -> int:
	return TYPE_FLOAT
