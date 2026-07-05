class_name RuleEditorPopup
extends Window
## Runtime editor for AntRule resources.

signal saved(resource: AntRule)

var editing: AntRule
var _previous_path: String = ""

var _name_edit: LineEdit
var _condition_select: OptionButton
var _action_select: OptionButton
var _priority_spin: SpinBox
var _enabled_check: CheckBox
var _desc_edit: LineEdit
var _status: Label


func _init() -> void:
	title = "Rule Editor"
	size = Vector2i(420, 380)
	min_size = Vector2i(380, 340)
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_requested.connect(queue_free)


func open_for(res: Resource, path: String, writable: bool) -> void:
	_previous_path = path if writable else ""
	editing = ResourceLibrary.duplicate_for_edit(res) if not path.is_empty() else res
	_build_ui(not path.is_empty() and not writable)
	popup_centered()


func _build_ui(is_builtin: bool) -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 10)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	if is_builtin:
		var banner := Label.new()
		banner.text = "Built-in resource — saving creates an editable copy in user://"
		banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		banner.add_theme_color_override("font_color", Color.GOLD)
		vbox.add_child(banner)

	_name_edit = LineEdit.new()
	_name_edit.text = editing.name
	vbox.add_child(_labeled_row("Name:", _name_edit))

	_condition_select = OptionButton.new()
	_condition_select.add_item("(none — always fires)")
	_condition_select.set_item_metadata(0, null)
	for entry: ResourceLibrary.Entry in ResourceLibrary.get_entries(ResourceLibrary.KIND_LOGIC):
		_condition_select.add_item(entry.display_name())
		_condition_select.set_item_metadata(_condition_select.item_count - 1, entry.resource)
		if editing.condition and entry.resource.id == editing.condition.id:
			_condition_select.select(_condition_select.item_count - 1)
	vbox.add_child(_labeled_row("Condition:", _condition_select))

	_action_select = OptionButton.new()
	for entry: ResourceLibrary.Entry in ResourceLibrary.get_entries(ResourceLibrary.KIND_ACTION):
		_action_select.add_item(entry.display_name())
		_action_select.set_item_metadata(_action_select.item_count - 1, entry.resource)
		if editing.action and entry.resource.id == editing.action.id:
			_action_select.select(_action_select.item_count - 1)
	vbox.add_child(_labeled_row("Action:", _action_select))

	_priority_spin = SpinBox.new()
	_priority_spin.min_value = -100
	_priority_spin.max_value = 100
	_priority_spin.value = editing.priority
	vbox.add_child(_labeled_row("Priority:", _priority_spin))

	_enabled_check = CheckBox.new()
	_enabled_check.button_pressed = editing.enabled
	vbox.add_child(_labeled_row("Enabled:", _enabled_check))

	_desc_edit = LineEdit.new()
	_desc_edit.text = editing.description
	vbox.add_child(_labeled_row("Description:", _desc_edit))

	_status = Label.new()
	_status.add_theme_color_override("font_color", Color.INDIAN_RED)
	vbox.add_child(_status)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 6)
	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_on_save)
	button_row.add_child(save_btn)
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(queue_free)
	button_row.add_child(cancel_btn)
	vbox.add_child(button_row)


func _labeled_row(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(90, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _on_save() -> void:
	editing.name = _name_edit.text.strip_edges()
	if editing.id.is_empty():
		_status.text = "Name is required."
		return
	if ResourceLibrary.has_id_conflict(ResourceLibrary.KIND_RULE, editing.id, editing):
		_status.text = "Another rule already uses the id '%s'." % editing.id
		return
	if _action_select.selected < 0:
		_status.text = "A rule needs an action."
		return

	editing.condition = _condition_select.get_item_metadata(_condition_select.selected)
	editing.action = _action_select.get_item_metadata(_action_select.selected)
	editing.priority = int(_priority_spin.value)
	editing.enabled = _enabled_check.button_pressed
	editing.description = _desc_edit.text

	if ResourceLibrary.save_resource(editing, ResourceLibrary.KIND_RULE, _previous_path) != OK:
		_status.text = "Save failed — see log."
		return

	# Priority may have changed: re-sort live behavior managers
	for ant: Ant in AntManager.get_all():
		if ant.behavior_manager:
			ant.behavior_manager.resort()

	saved.emit(editing)
	queue_free()
