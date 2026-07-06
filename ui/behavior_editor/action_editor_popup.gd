class_name ActionEditorPopup
extends ManagedWindow
## Runtime editor for AntAction resources. Method choices come straight from
## Ant.ACTION_API — the UI physically cannot author a non-whitelisted call.

signal saved(resource: AntAction)

var editing: AntAction
var _previous_path: String = ""
var _params: Array[Logic] = []

var _name_edit: LineEdit
var _method_select: OptionButton
var _desc_edit: LineEdit
var _param_list: ItemList
var _param_picker: OptionButton
var _status: Label


func _init() -> void:
	setup_window("action_editor", "Action Editor",
		Vector2i(440, 520), Vector2i(380, 420))


func open_for(res: Resource, path: String, writable: bool) -> void:
	_previous_path = path if writable else ""
	editing = ResourceLibrary.duplicate_for_edit(res) if not path.is_empty() else res
	_params.assign(editing.params)
	_build_ui(not path.is_empty() and not writable)
	present()


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

	_method_select = OptionButton.new()
	for method in Ant.ACTION_API:
		_method_select.add_item(method)
		if method == editing.method:
			_method_select.select(_method_select.item_count - 1)
	vbox.add_child(_labeled_row("Method:", _method_select))

	_desc_edit = LineEdit.new()
	_desc_edit.text = editing.description
	vbox.add_child(_labeled_row("Description:", _desc_edit))

	var params_label := Label.new()
	params_label.text = "Parameters (Logic, passed positionally — order matters):"
	params_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(params_label)

	_param_list = ItemList.new()
	_param_list.custom_minimum_size = Vector2(0, 90)
	_param_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_param_list)

	var param_row := HBoxContainer.new()
	param_row.add_theme_constant_override("separation", 6)
	_param_picker = OptionButton.new()
	_param_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	param_row.add_child(_param_picker)
	param_row.add_child(_btn("Add", _on_add_param))
	param_row.add_child(_btn("Remove", _on_remove_param))
	param_row.add_child(_btn("▲", func() -> void: _move_param(-1)))
	param_row.add_child(_btn("▼", func() -> void: _move_param(1)))
	vbox.add_child(param_row)

	_status = Label.new()
	_status.add_theme_color_override("font_color", Color.INDIAN_RED)
	vbox.add_child(_status)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 6)
	button_row.add_child(_btn("Save", _on_save))
	button_row.add_child(_btn("Cancel", queue_free))
	vbox.add_child(button_row)

	_name_edit.tooltip_text = "Unique name; the id is derived from it"
	_method_select.tooltip_text = "Whitelisted Ant method this action invokes (Ant.ACTION_API)"
	_desc_edit.tooltip_text = "Shown in library lists and rule editors"
	_param_list.tooltip_text = "Logic expressions passed as arguments, in order"
	_param_picker.tooltip_text = "Pick an expression to append as a parameter"

	watch([_name_edit, _method_select, _desc_edit])

	_refresh_params()


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


func _btn(text: String, handler: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(handler)
	return btn


func _refresh_params() -> void:
	_param_list.clear()
	for param in _params:
		_param_list.add_item("%s  (%s)" % [param.id, param.name])

	_param_picker.clear()
	for entry: ResourceLibrary.Entry in ResourceLibrary.get_entries(ResourceLibrary.KIND_LOGIC):
		_param_picker.add_item(entry.display_name())
		_param_picker.set_item_metadata(_param_picker.item_count - 1, entry.resource)


func _on_add_param() -> void:
	var idx := _param_picker.selected
	if idx < 0:
		return
	_params.append(_param_picker.get_item_metadata(idx))
	mark_dirty()
	_refresh_params()


func _on_remove_param() -> void:
	var sel := _param_list.get_selected_items()
	if sel.is_empty():
		return
	_params.remove_at(sel[0])
	mark_dirty()
	_refresh_params()


func _move_param(offset: int) -> void:
	var sel := _param_list.get_selected_items()
	if sel.is_empty():
		return
	var from: int = sel[0]
	var to := clampi(from + offset, 0, _params.size() - 1)
	if from == to:
		return
	var param := _params[from]
	_params.remove_at(from)
	_params.insert(to, param)
	_refresh_params()
	_param_list.select(to)


func _on_save() -> void:
	editing.name = _name_edit.text.strip_edges()
	if editing.id.is_empty():
		_status.text = "Name is required."
		return
	if ResourceLibrary.has_id_conflict(ResourceLibrary.KIND_ACTION, editing.id, editing):
		_status.text = "Another action already uses the id '%s'." % editing.id
		return
	if _method_select.selected < 0:
		_status.text = "Pick a method."
		return

	editing.method = _method_select.get_item_text(_method_select.selected)
	editing.description = _desc_edit.text
	editing.params.assign(_params)

	if ResourceLibrary.save_resource(editing, ResourceLibrary.KIND_ACTION, _previous_path) != OK:
		_status.text = "Save failed — see log."
		toast_error("Save failed — see log.")
		return
	saved.emit(editing)
	clear_dirty()
	Toast.success(get_parent(), "Saved action '%s'" % editing.name)
	_request_close()

func _confirm_shortcut() -> bool:
	_on_save()
	return true
