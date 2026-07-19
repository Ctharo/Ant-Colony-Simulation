class_name BehaviorLibraryPanel
extends ManagedWindow
## Browser for Logic / AntAction / AntRule resources: create, edit,
## duplicate, delete. Editing a built-in forks it to user://.

var _kind_select: OptionButton
var _item_list: ItemList
var _edit_btn: Button
var _dup_btn: Button
var _del_btn: Button
var _confirm: ConfirmationDialog

const KINDS: Array[String] = ["logic", "action", "rule"]
const KIND_LABELS: Array[String] = ["Expressions", "Actions", "Rules"]


func _init() -> void:
	setup_window("behavior_library", "Behavior Library", 
	Vector2i(420, 520), Vector2i(340, 380))


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 10)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_kind_select = OptionButton.new()
	for label in KIND_LABELS:
		_kind_select.add_item(label)
	_kind_select.item_selected.connect(func(_i: int) -> void: _refresh())
	vbox.add_child(_kind_select)

	_item_list = ItemList.new()
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list.item_selected.connect(func(_i: int) -> void: _update_buttons())
	_item_list.item_activated.connect(func(_i: int) -> void: _on_edit())
	vbox.add_child(_item_list)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	vbox.add_child(buttons)

	buttons.add_child(_make_button("New", _on_new))
	_edit_btn = _make_button("Edit", _on_edit)
	buttons.add_child(_edit_btn)
	_dup_btn = _make_button("Duplicate", _on_duplicate)
	buttons.add_child(_dup_btn)
	_del_btn = _make_button("Delete", _on_delete)
	buttons.add_child(_del_btn)

	_kind_select.tooltip_text = "Which resource kind to browse"
	_edit_btn.tooltip_text = "Edit the selection (built-ins fork to user:// on save)"
	_dup_btn.tooltip_text = "Copy the selection as a new editable resource"
	_del_btn.tooltip_text = "Delete from user:// (built-ins can't be deleted)"

	_confirm = ConfirmationDialog.new()
	add_child(_confirm)

	ResourceLibrary.library_changed.connect(func(_k: String) -> void: _refresh())
	_refresh()


func _make_button(text: String, handler: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(handler)
	return btn


func _current_kind() -> String:
	return KINDS[_kind_select.selected]


func _selected_entry() -> ResourceLibrary.Entry:
	var sel := _item_list.get_selected_items()
	if sel.is_empty():
		return null
	return _item_list.get_item_metadata(sel[0])


func _refresh() -> void:
	_item_list.clear()
	for entry: ResourceLibrary.Entry in ResourceLibrary.get_entries(_current_kind()):
		var idx := _item_list.add_item(entry.display_name())
		_item_list.set_item_metadata(idx, entry)
		_item_list.set_item_tooltip(idx, entry.path)
	_update_buttons()


func _update_buttons() -> void:
	var entry := _selected_entry()
	_edit_btn.disabled = entry == null
	_dup_btn.disabled = entry == null
	_del_btn.disabled = entry == null or not entry.writable


func _on_new() -> void:
	match _current_kind():
		"logic":
			_open_editor(LogicEditorPopup.new(), Logic.new(), "", true)
		"action":
			_open_editor(ActionEditorPopup.new(), AntAction.new(), "", true)
		"rule":
			_open_editor(RuleEditorPopup.new(), AntRule.new(), "", true)


func _on_edit() -> void:
	var entry := _selected_entry()
	if not entry:
		return
	var p_popup: Window
	match _current_kind():
		"logic": p_popup = LogicEditorPopup.new()
		"action": p_popup = ActionEditorPopup.new()
		"rule": p_popup = RuleEditorPopup.new()
	_open_editor(p_popup, entry.resource, entry.path, entry.writable)


func _on_duplicate() -> void:
	var entry := _selected_entry()
	if not entry:
		return
	var copy: Resource = ResourceLibrary.duplicate_for_edit(entry.resource)
	copy.name = "%s copy" % copy.name
	var p_popup: Window
	match _current_kind():
		"logic": p_popup = LogicEditorPopup.new()
		"action": p_popup = ActionEditorPopup.new()
		"rule":
			_open_editor(BehaviorGraphEditorPopup.new(), AntRule.new(), "", true)
	_open_editor(p_popup, copy, "", true)


func _on_delete() -> void:
	var entry := _selected_entry()
	if not entry or not entry.writable:
		return
	_confirm.dialog_text = "Delete '%s'?\nAnts currently referencing it keep the in-memory copy until restart." % entry.resource.name
	# Reconnect confirmed for this specific entry
	for conn in _confirm.confirmed.get_connections():
		_confirm.confirmed.disconnect(conn.callable)
	_confirm.confirmed.connect(func() -> void:
		var deleted_name: String = entry.resource.name
		ResourceLibrary.delete_resource(entry)
		toast_info("Deleted '%s'" % deleted_name)
	)
	_confirm.popup_centered()


func _open_editor(p_popup: Window, res: Resource, path: String, writable: bool) -> void:
	add_child(p_popup)
	p_popup.open_for(res, path, writable)
