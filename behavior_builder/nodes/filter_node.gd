class_name BBFilterNode
extends BBNode
## FILTER — list in, smaller list out. Reads as a sentence:
##     keep items where [is_ally] [is FALSE]            (bool property)
##     keep items where [distance] [is less than] [50]  (float property)
## The float threshold can be typed inline or wired in as B (port 2), same
## contract as COMPARE/MATH. Items missing the chosen property are dropped —
## e.g. filtering a food list by "health" keeps nothing, on purpose.
##
## "nearest enemy" = SENSE(ants) → FILTER is_ally is FALSE → PICK nearest.

const FLOAT_OPS: Array[String] = ["<", ">", "<=", ">=", "=="]
const FLOAT_OP_LABELS: Array[String] = ["is less than", "is greater than", "is at most", "is at least", "equals"]

var prop_btn: OptionButton
var op_btn: OptionButton
var truth_btn: OptionButton
var b_spin: SpinBox
var b_wired_label: Label

var _props: Array[Dictionary] = []
var _b_wired: bool = false


func _init() -> void:
	bb_type = "filter"
	title = "FILTER"


func _build() -> void:
	var row0: HBoxContainer = HBoxContainer.new()
	row0.add_theme_constant_override("separation", 6)
	var keep_lab: Label = Label.new()
	keep_lab.text = "keep items where"
	keep_lab.tooltip_text = "Wire a list into the port on the left"
	row0.add_child(keep_lab)
	prop_btn = OptionButton.new()
	prop_btn.focus_mode = Control.FOCUS_NONE
	var _err0: Error = prop_btn.item_selected.connect(
		func(_index: int) -> void:
			_sync_mode()
			params_changed.emit())
	row0.add_child(prop_btn)
	add_child(row0)  # slot 0 — input port 0 (list), output port 0 (list)

	var row1: HBoxContainer = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	op_btn = OptionButton.new()
	op_btn.focus_mode = Control.FOCUS_NONE
	for op_label: String in FLOAT_OP_LABELS:
		op_btn.add_item(op_label)
	op_btn.select(0)
	var _err1: Error = op_btn.item_selected.connect(
		func(_index: int) -> void: params_changed.emit())
	row1.add_child(op_btn)

	b_spin = SpinBox.new()
	b_spin.min_value = -100000.0
	b_spin.max_value = 100000.0
	b_spin.step = 0.1
	b_spin.custom_minimum_size = Vector2(90.0, 0.0)
	var _err2: Error = b_spin.value_changed.connect(
		func(_value: float) -> void: params_changed.emit())
	row1.add_child(b_spin)

	b_wired_label = Label.new()
	b_wired_label.visible = false
	b_wired_label.add_theme_color_override("font_color", COL_FLOAT)
	b_wired_label.tooltip_text = "B is wired — this is the live threshold coming in on the port below.\nDisconnect the wire to go back to typing a number."
	row1.add_child(b_wired_label)

	truth_btn = OptionButton.new()
	truth_btn.focus_mode = Control.FOCUS_NONE
	truth_btn.add_item("is TRUE")
	truth_btn.add_item("is FALSE")
	truth_btn.select(0)
	truth_btn.visible = false
	var _err3: Error = truth_btn.item_selected.connect(
		func(_index: int) -> void: params_changed.emit())
	row1.add_child(truth_btn)
	add_child(row1)  # slot 1 — input port 1 (float threshold B)

	set_slot(0, true, TYPE_LIST, COL_LIST, true, TYPE_LIST, COL_LIST)
	set_slot(1, true, TYPE_FLOAT, COL_FLOAT, false, 0, Color.WHITE)
	_make_value_footer()
	_populate_props()
	_sync_mode()


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


func _is_bool_mode() -> bool:
	return BBWorldState.prop_type(_selected_prop_key()) == "bool"


## Bool properties show "is TRUE / is FALSE"; float ones show op + threshold.
func _sync_mode() -> void:
	var bool_mode: bool = _is_bool_mode()
	truth_btn.visible = bool_mode
	op_btn.visible = not bool_mode
	b_spin.visible = not bool_mode and not _b_wired
	b_wired_label.visible = not bool_mode and _b_wired
	size = Vector2.ZERO


func input_count() -> int:
	return 2


func input_type(port: int) -> int:
	return TYPE_LIST if port == 0 else TYPE_FLOAT


func output_type() -> int:
	return TYPE_LIST


func get_params() -> Dictionary:
	return {
		"prop": _selected_prop_key(),
		"mode": "bool" if _is_bool_mode() else "float",
		"op": FLOAT_OPS[op_btn.selected] if op_btn.selected >= 0 else "<",
		"value": b_spin.value,
		"want_true": truth_btn.selected == 0,
	}


func set_params(p: Dictionary) -> void:
	var prop_key: String = str(p.get("prop", "distance"))
	for i: int in _props.size():
		if str(_props[i].key) == prop_key:
			prop_btn.select(i)
			break
	var op_index: int = FLOAT_OPS.find(str(p.get("op", "<")))
	if op_index >= 0:
		op_btn.select(op_index)
	b_spin.value = float(p.get("value", 0.0))
	truth_btn.select(0 if bool(p.get("want_true", true)) else 1)
	_sync_mode()


func on_inputs(values: Array, connected: Array) -> void:
	super.on_inputs(values, connected)
	var b_wired: bool = connected.size() > 1 and bool(connected[1])
	if b_wired:
		b_wired_label.text = "%s  (wired)" % fmt(values[1] if values.size() > 1 else null)
	if b_wired != _b_wired:
		_b_wired = b_wired
		_sync_mode()
