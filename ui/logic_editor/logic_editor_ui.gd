class_name LogicEditorUI
extends Control

#region Constants
const BASE_PATH := "res://resources/expressions/"
const FILE_EXTENSION := ".tres"
## Last directory used for save/load operations
var _last_path: String = BASE_PATH
#endregion

#region Node References
@onready var expression_edit: TextEdit = %ExpressionEdit
@onready var name_edit: LineEdit = %NameEdit
@onready var type_option: OptionButton = %TypeOption
@onready var description_edit: TextEdit = %DescriptionEdit
@onready var nested_expressions_list: ItemList = %NestedExpressionsList
@onready var save_dialog: FileDialog = %SaveDialog
@onready var load_dialog: FileDialog = %LoadDialog
@onready var error_label: Label = %ErrorLabel
#endregion

#region Properties
## Currently edited logic resource
var current_logic: Logic:
	set(value):
		if current_logic != value:
			current_logic = value
			_update_ui_from_logic()

## Reference to the evaluation system for validating expressions
var eval_system: EvaluationSystem

## Dictionary of available methods/properties for validation
var _available_members: Dictionary = {
	"position": TYPE_VECTOR2,
	"rotation": TYPE_FLOAT,
	"global_position": TYPE_VECTOR2,
	"global_rotation": TYPE_FLOAT,
	"colony": TYPE_OBJECT,  ## Reference to colony
	"food": TYPE_OBJECT,  ## Reference to carried food
	"speed": TYPE_FLOAT,
	"randf_range": [TYPE_FLOAT, [TYPE_FLOAT, TYPE_FLOAT]],  ## Function with param types
	"Vector2": [TYPE_VECTOR2, [TYPE_FLOAT, TYPE_FLOAT]],  ## Constructor
	"PI": TYPE_FLOAT,
	"sin": [TYPE_FLOAT, [TYPE_FLOAT]],
	"cos": [TYPE_FLOAT, [TYPE_FLOAT]],
}
#endregion

#region Lifecycle Methods
func _ready() -> void:
	_setup_type_options()
	_connect_signals()
	_setup_file_dialogs()
	
	# Initialize with empty Logic resource
	current_logic = Logic.new()
	
func _setup_file_dialogs() -> void:
	# Configure save dialog
	save_dialog.access = FileDialog.ACCESS_RESOURCES
	save_dialog.root_subfolder = BASE_PATH
	save_dialog.current_dir = BASE_PATH
	
	# Configure load dialog
	load_dialog.access = FileDialog.ACCESS_RESOURCES
	load_dialog.root_subfolder = BASE_PATH
	load_dialog.current_dir = BASE_PATH
#endregion

#region Setup Methods
func _setup_type_options() -> void:
	# Add type options matching the enum in Logic class
	type_option.add_item("BOOL", 0)
	type_option.add_item("INT", 1)
	type_option.add_item("FLOAT", 2)
	type_option.add_item("STRING", 3)
	type_option.add_item("VECTOR2", 4)
	type_option.add_item("VECTOR3", 5)
	type_option.add_item("ARRAY", 6)
	type_option.add_item("DICTIONARY", 7)
	type_option.add_item("FOOD", 8)
	type_option.add_item("ANT", 9)
	type_option.add_item("COLONY", 10)
	type_option.add_item("PHEROMONE", 11)
	type_option.add_item("ITERATOR", 12)
	type_option.add_item("FOODS", 13)
	type_option.add_item("PHEROMONES", 14)
	type_option.add_item("COLONIES", 15)
	type_option.add_item("ANTS", 16)
	type_option.add_item("OBJECT", 17)
	type_option.add_item("UNKNOWN", 18)

func _connect_signals() -> void:
	name_edit.text_changed.connect(_on_name_changed)
	expression_edit.text_changed.connect(_on_expression_changed)
	type_option.item_selected.connect(_on_type_selected)
	description_edit.text_changed.connect(_on_description_changed)
#endregion

#region UI Update Methods
func _update_ui_from_logic() -> void:
	if not current_logic:
		return
		
	name_edit.text = current_logic.name
	expression_edit.text = current_logic.expression_string
	type_option.selected = current_logic.type
	description_edit.text = current_logic.description
	_update_nested_expressions_list()


#endregion

#region Validation Methods
func _validate_expression() -> void:
	if not current_logic or current_logic.expression_string.is_empty():
		error_label.text = ""
		return
		
	if not eval_system:
		error_label.text = "No evaluation system available"
		return
		
	var validation_result := _validate_syntax(current_logic.expression_string)
	if not validation_result.is_empty():
		error_label.text = validation_result
		return
		
	var type_validation := _validate_return_type()
	if not type_validation.is_empty():
		error_label.text = type_validation
		return
		
	error_label.text = ""

func _validate_syntax(expression: String) -> String:
	var expression_tokens := expression.split(" ")
	var stack := []
	
	for token in expression_tokens:
		# Check for valid member access
		if "." in token:
			var parts := token.split(".")
			if parts[0] in _available_members:
				if not _validate_member_access(parts):
					return "Invalid member access: " + token
			
		# Check for function calls
		if "(" in token:
			var func_name := token.split("(")[0]
			if func_name in _available_members:
				if not _validate_function_call(token):
					return "Invalid function call: " + token
			stack.append("(")
			
		if ")" in token:
			if stack.is_empty():
				return "Mismatched parentheses"
			stack.pop_back()
			
	if not stack.is_empty():
		return "Unclosed parentheses"
		
	return ""

func _validate_member_access(parts: Array) -> bool:
	var current_type = _available_members[parts[0]]
	
	for i in range(1, parts.size()):
		if current_type != TYPE_OBJECT:
			return false
			
		# Check if the member exists in the next object type
		# This would need to be expanded based on the actual object types
		if not parts[i] in _available_members:
			return false
			
		current_type = _available_members[parts[i]]
		
	return true

func _validate_function_call(token: String) -> bool:
	var func_name := token.split("(")[0]
	var params := token.split("(")[1].trim_suffix(")").split(",")
	
	if not func_name in _available_members:
		return false
		
	var func_info = _available_members[func_name]
	if not func_info is Array:
		return false
		
	# Check parameter count and types
	var expected_params = func_info[1]
	if params.size() != expected_params.size():
		return false
		
	return true

func _validate_return_type() -> String:
	var expected_type := current_logic.type
	# This would need to connect with the EvaluationSystem to validate
	# the actual return type of the expression
	
	# For now, we'll do basic type checking based on common patterns
	var expr := current_logic.expression_string.to_lower()
	
	match expected_type:
		0: # BOOL
			if not ("true" in expr or "false" in expr or "==" in expr or ">" in expr or "<" in expr):
				return "Expression may not return a boolean"
		4: # VECTOR2
			if not ("vector2" in expr or "position" in expr or "direction" in expr):
				return "Expression may not return a Vector2"
		2: # FLOAT
			if not (expr.is_valid_float() or "randf" in expr or "sin" in expr or "cos" in expr):
				return "Expression may not return a float"
	
	return ""
func _on_name_changed(new_text: String) -> void:
	if current_logic:
		current_logic.name = new_text

func _on_expression_changed() -> void:
	if current_logic:
		current_logic.expression_string = expression_edit.text
		_validate_expression()

func _on_type_selected(index: int) -> void:
	if current_logic:
		current_logic.type = index
		_validate_expression()

func _on_description_changed() -> void:
	if current_logic:
		current_logic.description = description_edit.text

func _on_add_nested_pressed() -> void:
	var new_logic := Logic.new()
	new_logic.name = "New Expression"
	current_logic.nested_expressions.append(new_logic)
	_update_nested_expressions_list()

func _on_remove_nested_pressed() -> void:
	var selected_items := nested_expressions_list.get_selected_items()
	if selected_items.is_empty():
		return
		
	var index := selected_items[0]
	current_logic.nested_expressions.remove_at(index)
	_update_nested_expressions_list()

func _on_nested_expression_selected(index: int) -> void:
	if index >= 0 and index < current_logic.nested_expressions.size():
		var selected_logic := current_logic.nested_expressions[index]
		_show_nested_expression_editor(selected_logic)

func _on_save_button_pressed() -> void:
	if not current_logic or current_logic.name.is_empty():
		error_label.text = "Please enter a name before saving"
		return
	
	save_dialog.current_dir = _last_path
	if current_logic.resource_path:
		save_dialog.current_file = current_logic.resource_path.get_file()
	else:
		save_dialog.current_file = current_logic.name.to_snake_case() + FILE_EXTENSION
	
	save_dialog.popup_centered()

func _on_load_button_pressed() -> void:
	load_dialog.current_dir = _last_path
	load_dialog.popup_centered()
#endregion

#region Nested Expression Methods
func _show_nested_expression_editor(logic: Logic) -> void:
	# Create a popup for editing nested expression
	var popup := Window.new()
	popup.title = "Edit Nested Expression"
	popup.size = Vector2(800, 600)
	
	var editor := LogicEditorUI.new()
	editor.current_logic = logic
	editor.eval_system = eval_system
	
	popup.add_child(editor)
	add_child(popup)
	
	popup.popup_centered()
	
func _update_nested_expressions_list() -> void:
	nested_expressions_list.clear()
	
	for expression in current_logic.nested_expressions:
		nested_expressions_list.add_item(expression.name)
		
	# Update the enable state of the remove button
	%RemoveNestedButton.disabled = nested_expressions_list.get_selected_items().is_empty()
func save_logic(path: String) -> void:
	if not path.ends_with(FILE_EXTENSION):
		path += FILE_EXTENSION
	
	if not path.begins_with(BASE_PATH):
		error_label.text = "Cannot save outside of expressions directory"
		return
		
	var error := ResourceSaver.save(current_logic, path)
	if error:
		error_label.text = "Error saving logic: " + str(error)
	else:
		_last_path = path.get_base_dir()
		error_label.text = "Logic saved successfully"

func load_logic(path: String) -> void:
	if not path.begins_with(BASE_PATH):
		error_label.text = "Cannot load from outside of expressions directory"
		return
		
	var loaded_resource = ResourceLoader.load(path)
	if not loaded_resource is Logic:
		error_label.text = "Invalid resource type loaded"
		return
		
	current_logic = loaded_resource
	_last_path = path.get_base_dir()
	error_label.text = "Logic loaded successfully"
#endregion
