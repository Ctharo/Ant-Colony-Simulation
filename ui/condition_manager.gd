class_name ConditionManager
extends Window

signal condition_updated

var conditions: Dictionary
var property_browser: PropertyBrowser
var condition_list: ItemList
var edit_button: Button
var delete_button: Button
var condition_editor: ConditionEditor

func _ready() -> void:
	title = "Condition Manager"
	min_size = Vector2(600, 400)
	
	create_ui()
	
	# Setup property browser
	property_browser = PropertyBrowser.new()
	property_browser.visible = false
	add_child(property_browser)
	
	# Setup condition editor
	condition_editor = ConditionEditor.new()
	condition_editor.visible = false
	condition_editor.condition_saved.connect(_on_condition_saved)
	add_child(condition_editor)

func create_ui() -> void:
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	add_child(main_container)
	
	# Toolbar
	var toolbar = HBoxContainer.new()
	main_container.add_child(toolbar)
	
	var new_button = Button.new()
	new_button.text = "New Condition"
	new_button.connect("pressed", Callable(self, "_on_new_pressed"))
	toolbar.add_child(new_button)
	
	edit_button = Button.new()
	edit_button.text = "Edit"
	edit_button.disabled = true
	edit_button.connect("pressed", Callable(self, "_on_edit_pressed"))
	toolbar.add_child(edit_button)
	
	delete_button = Button.new()
	delete_button.text = "Delete"
	delete_button.disabled = true
	delete_button.connect("pressed", Callable(self, "_on_delete_pressed"))
	toolbar.add_child(delete_button)
	
	# Condition List
	var list_container = VBoxContainer.new()
	list_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(list_container)
	
	var list_label = Label.new()
	list_label.text = "Defined Conditions:"
	list_container.add_child(list_label)
	
	condition_list = ItemList.new()
	condition_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	condition_list.connect("item_selected", Callable(self, "_on_item_selected"))
	condition_list.connect("item_activated", Callable(self, "_on_item_activated"))
	list_container.add_child(condition_list)
	
	# Details Panel
	var details_panel = VBoxContainer.new()
	details_panel.custom_minimum_size.y = 150
	main_container.add_child(details_panel)
	
	var details_label = Label.new()
	details_label.text = "Details:"
	details_panel.add_child(details_label)

func set_conditions(p_conditions: Dictionary) -> void:
	conditions = p_conditions
	refresh_list()

func refresh_list() -> void:
	condition_list.clear()
	for condition_name in conditions:
		var condition = conditions[condition_name]
		var desc = condition.get("description", "No description")
		condition_list.add_item("%s - %s" % [condition_name, desc])

func _on_item_selected(_index: int) -> void:
	edit_button.disabled = false
	delete_button.disabled = false

func _on_item_activated(_index: int) -> void:
	_on_edit_pressed()

func _on_new_pressed() -> void:
	condition_editor.clear()  # Add this method to ConditionEditor
	condition_editor.popup_centered()

func _on_edit_pressed() -> void:
	var selected_items = condition_list.get_selected_items()
	if selected_items.is_empty():
		return
		
	var condition_name = conditions.keys()[selected_items[0]]
	var condition_data = conditions[condition_name]
	
	condition_editor.set_condition(condition_name, condition_data)
	condition_editor.popup_centered()

func _on_delete_pressed() -> void:
	var selected_items = condition_list.get_selected_items()
	if selected_items.is_empty():
		return
	
	var condition_name = conditions.keys()[selected_items[0]]
	
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Delete condition '%s'?" % condition_name
	confirm_dialog.confirmed.connect(
		func():
			conditions.erase(condition_name)
			refresh_list()
			condition_updated.emit()
	)
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()

func _on_condition_saved(condition_name: String, condition_data: Dictionary) -> void:
	conditions[condition_name] = condition_data
	refresh_list()
	condition_updated.emit()

func show_error(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
