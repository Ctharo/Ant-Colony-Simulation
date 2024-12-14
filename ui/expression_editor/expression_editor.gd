extends Control

## Reference to the expression being edited
var current_expression: Logic
## Reference to the expression cache manager
var cache_manager: Cache


@onready var type_option: OptionButton = %TypeOption
@onready var id_edit: LineEdit = $MainContainer/TopBar/IdEdit
@onready var name_edit: LineEdit = $MainContainer/TopBar/NameEdit
@onready var desc_edit: TextEdit = $MainContainer/TopBar/DescEdit
@onready var property_container: VBoxContainer = %PropertyConfig
@onready var list_container: VBoxContainer = %ListConfig
@onready var distance_container: VBoxContainer = %DistanceConfig
@onready var expression_tree: Tree = %ExpressionTree
@onready var preview_label: Label = %PreviewLabel
@onready var test_environment: ExpressionTestEnvironment = %ExpressionTestEnvironment

func _ready() -> void:
	# Dictionary mapping control variables to their expected paths
	var required_controls = {
		"type_option": "MainContainer/TopBar/TypeOption",
		"id_edit": "MainContainer/TopBar/IdEdit",
		"name_edit": "MainContainer/TopBar/NameEdit",
		"desc_edit": "MainContainer/TopBar/DescEdit",
		"property_container": "MainContainer/ConfigArea/PropertyConfig",
		"list_container": "MainContainer/ConfigArea/ListConfig",
		"distance_container": "MainContainer/ConfigArea/DistanceConfig",
		"expression_tree": "MainContainer/ExpressionTree",
		"preview_label": "MainContainer/PreviewArea/PreviewLabel",
	}

	# Validate all required controls
	for control_name in required_controls:
		assert(get(control_name) != null,
			"Required control '%s' not found at %s" % [control_name, required_controls[control_name]])

	_setup_type_options()
	_setup_signals()

func _setup_type_options() -> void:
	type_option.clear()



func _setup_signals() -> void:
	type_option.item_selected.connect(_on_type_selected)
	id_edit.text_changed.connect(_on_id_changed)
	name_edit.text_changed.connect(_on_name_changed)
	desc_edit.text_changed.connect(_on_desc_changed)
	# Connect to test environment
	test_environment.test_entity_changed.connect(_on_test_entity_changed)

func _on_expression_changed() -> void:
	# Update preview
	_update_preview()

func _on_test_entity_changed(entity: Node) -> void:
	if current_expression and entity:
		current_expression.initialize(entity)
		_update_preview()

func _on_type_selected(index: int) -> void:
	var type_name = type_option.get_item_text(index)
	_hide_all_config_containers()

	match type_name:
		"Property":
			property_container.visible = true
		"ListMap", "ListFilter", "ListAny":
			list_container.visible = true
		"Distance":
			distance_container.visible = true

	_update_preview()

func _hide_all_config_containers() -> void:
	property_container.visible = false
	list_container.visible = false
	distance_container.visible = false

func _on_id_changed(new_id: String) -> void:
	if current_expression:
		current_expression.id = new_id
		_update_preview()

func _on_name_changed(new_name: String) -> void:
	if current_expression:
		current_expression.name = new_name
		_update_preview()

func _on_desc_changed() -> void:
	if current_expression:
		current_expression.description = desc_edit.text
		_update_preview()

func _update_preview() -> void:
	if not current_expression:
		preview_label.text = "No expression selected"
		return

	var preview_text = "Expression Preview:\n"
	preview_text += "Type: %s\n" % current_expression.get_class()
	preview_text += "ID: %s\n" % current_expression.id
	preview_text += "Name: %s\n" % current_expression.name
	preview_text += "Description: %s\n" % current_expression.description

	# Add type-specific preview info
	match current_expression.get_class():
		"PropertyExpression":
			preview_text += "Property Path: %s\n" % current_expression.property_path
		"ListMapExpression", "ListFilterExpression", "ListAnyExpression":
			preview_text += "Source Expression: %s\n" % (current_expression.array_expression.name if current_expression.array_expression else "None")

	preview_label.text = preview_text

func _on_save_pressed() -> void:
	if not current_expression:
		return

	# Validate required fields
	if current_expression.id.is_empty():
		push_error("Expression ID is required")
		return

	# Create save path
	var save_path = "res://resources/expressions/%s.tres" % current_expression.id

	# Save the expression resource
	var err = ResourceSaver.save(current_expression, save_path)
	if err != OK:
		push_error("Failed to save expression: %s" % err)
		return

	print("Expression saved successfully to: %s" % save_path)

func _on_load_pressed() -> void:
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.filters = ["*.tres ; Expression Resources"]

	add_child(file_dialog)
	file_dialog.popup_centered(Vector2(800, 600))

	# Wait for file selection
	var file_path = await file_dialog.file_selected
	file_dialog.queue_free()

	# Load the expression
	var loaded_expression = load(file_path)
	if loaded_expression is Logic:
		current_expression = loaded_expression
		_load_expression_to_ui()
	else:
		push_error("Selected file is not a LogicExpression resource")

func _load_expression_to_ui() -> void:
	if not current_expression:
		return

	id_edit.text = current_expression.id
	name_edit.text = current_expression.name
	desc_edit.text = current_expression.description

	# Select correct type in OptionButton
	for i in type_option.item_count:
		if type_option.get_item_text(i) == current_expression.get_class().trim_suffix("Expression"):
			type_option.select(i)
			_on_type_selected(i)
			break

	_update_preview()
