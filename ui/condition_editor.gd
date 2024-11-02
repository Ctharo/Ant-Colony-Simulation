class_name ConditionEditor
extends Window

signal condition_saved(condition_name: String, condition_data: Dictionary)

var name_field: LineEdit
var description_field: TextEdit
var property_field: LineEdit
var operator_button: OptionButton
var value_container: HBoxContainer
var value_field: LineEdit
var value_from_field: LineEdit
var property_browser: PropertyBrowser
var save_button: Button

var current_property_type: String = "Property"

func _ready() -> void:
	title = "Condition Editor"
	create_ui()
	min_size = Vector2(600, 400)

func create_ui() -> void:
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	add_child(main_container)
	
	# Name field
	var name_container = HBoxContainer.new()
	main_container.add_child(name_container)
	
	var name_label = Label.new()
	name_label.text = "Condition Name:"
	name_container.add_child(name_label)
	
	name_field = LineEdit.new()
	name_field.placeholder_text = "Enter unique condition name"
	name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_container.add_child(name_field)
	
	# Description field
	var desc_label = Label.new()
	desc_label.text = "Description:"
	main_container.add_child(desc_label)
	
	description_field = TextEdit.new()
	description_field.custom_minimum_size.y = 60
	main_container.add_child(description_field)
	
	# Property selection
	var property_container = HBoxContainer.new()
	main_container.add_child(property_container)
	
	var property_label = Label.new()
	property_label.text = "Property:"
	property_container.add_child(property_label)
	
	property_field = LineEdit.new()
	property_field.placeholder_text = "Select Property"
	property_field.editable = false
	property_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	property_container.add_child(property_field)
	
	var browse_button = Button.new()
	browse_button.text = "Browse"
	browse_button.connect("pressed", Callable(self, "_on_browse_property"))
	property_container.add_child(browse_button)
	
	# Operator selection
	var operator_container = HBoxContainer.new()
	main_container.add_child(operator_container)
	
	var operator_label = Label.new()
	operator_label.text = "Operator:"
	operator_container.add_child(operator_label)
	
	operator_button = OptionButton.new()
	operator_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	operator_container.add_child(operator_button)
	
	# Value container
	value_container = HBoxContainer.new()
	main_container.add_child(value_container)
	
	var value_label = Label.new()
	value_label.text = "Value:"
	value_container.add_child(value_label)
	
	# Value options
	var value_options = HBoxContainer.new()
	value_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_container.add_child(value_options)
	
	var value_type = OptionButton.new()
	value_type.add_item("Fixed Value")
	value_type.add_item("Property Value")
	value_type.connect("item_selected", Callable(self, "_on_value_type_changed"))
	value_options.add_child(value_type)
	
	value_field = LineEdit.new()
	value_field.placeholder_text = "Enter value"
	value_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_options.add_child(value_field)
	
	value_from_field = LineEdit.new()
	value_from_field.placeholder_text = "Select property for value"
	value_from_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_from_field.visible = false
	value_options.add_child(value_from_field)
	
	var value_browse = Button.new()
	value_browse.text = "Browse"
	value_browse.visible = false
	value_browse.connect("pressed", Callable(self, "_on_browse_value_from"))
	value_options.add_child(value_browse)
	
	# Buttons
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_END
	main_container.add_child(button_container)
	
	save_button = Button.new()
	save_button.text = "Save Condition"
	save_button.connect("pressed", Callable(self, "_on_save"))
	button_container.add_child(save_button)
	
	var cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.connect("pressed", Callable(self, "_on_cancel"))
	button_container.add_child(cancel_button)
	
	# Property browser setup
	property_browser = PropertyBrowser.new()
	property_browser.visible = false
	add_child(property_browser)
	property_browser.property_selected.connect(_on_property_selected)

func set_condition(condition_name: String, data: Dictionary) -> void:
	name_field.text = condition_name
	description_field.text = data.get("description", "")
	
	var evaluation = data.get("evaluation", {})
	property_field.text = evaluation.get("property", "")
	
	_update_operators_for_property(property_field.text)
	var operator_value = evaluation.get("operator", "EQUALS")
	
	# Find the index of the operator in the option button
	for i in operator_button.item_count:
		if operator_button.get_item_text(i) == operator_value:
			operator_button.select(i)
			break
	
	if "value" in evaluation:
		value_field.text = str(evaluation.value)
		value_from_field.visible = false
		value_field.visible = true
	elif "value_from" in evaluation:
		value_from_field.text = evaluation.value_from
		value_from_field.visible = true
		value_field.visible = false

func _on_browse_property() -> void:
	property_browser.visible = true
	property_browser.popup_centered(Vector2(800, 600))

func _on_property_selected(property_path: String) -> void:
	property_browser.visible = false
	property_field.text = property_path
	
	# Get the type from PropertyBrowser
	var type_info = property_browser.get_property_type(property_path)
	current_property_type = type_info if type_info else "Property"
	
	# Update operators based on the actual type
	_update_operators_for_property(current_property_type)

func _on_value_type_changed(index: int) -> void:
	value_field.visible = (index == 0)  # Fixed value
	value_from_field.visible = (index == 1)  # Property value

func _on_save() -> void:
	if name_field.text.is_empty():
		_show_error("Please enter a condition name")
		return
	
	if property_field.text.is_empty():
		_show_error("Please select a property")
		return
	
	var condition_data = {
		"description": description_field.text,
		"evaluation": {
			"type": "PropertyCheck",
			"property": property_field.text,
			"operator": operator_button.get_item_text(operator_button.selected)
		}
	}
	
	# Add either value or value_from based on selection
	if value_field.visible:
		condition_data.evaluation["value"] = _parse_value(value_field.text)
	else:
		condition_data.evaluation["value_from"] = value_from_field.text
	
	condition_saved.emit(name_field.text, condition_data)
	hide()
	
func _on_cancel() -> void:
	hide()

func _show_error(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()

func _update_operators_for_property(property_path: String) -> void:
	operator_button.clear()
	current_property_type = "Property"  # Default type
	# Here you would determine the actual type from the property_path
	var operators = AntBehaviorEditor.TYPE_OPERATORS[current_property_type]
	for op in operators:
		operator_button.add_item(op)

func _parse_value(value_text: String, property_type: String = "Property"):
	match property_type:
		"Boolean":
			return value_text.to_lower() == "true"
		"Integer":
			return value_text.to_int()
		"Float":
			return value_text.to_float()
		_:
			return value_text

# Helper function to determine property type
func _get_property_type(property_path: String) -> String:
	# This should match your actual property types
	if property_path.ends_with("_count"):
		return "Integer"
	elif property_path.begins_with("is_"):
		return "Boolean"
	elif property_path in ["distance_to_colony", "carried_food_mass"]:
		return "Float"
	return "Property"
