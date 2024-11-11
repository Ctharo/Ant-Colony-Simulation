class_name PropertyBrowser
extends Window

#region Signals
signal property_selected(property_path: String)
signal content_created
#endregion

#region Constants
## Tree view column indices
const COL_NAME = 0
const COL_TYPE = 1
const COL_VALUE = 2
const COL_DEPENDENCIES = 3

## Number of items to process per frame for staged creation
const ITEMS_PER_FRAME = 50
#endregion

#region Member Variables
## Tree view value column width
var _original_value_width: int = 250

## Currently expanded tree item
var _expanded_item: TreeItem

## Reference to current Ant instance
var current_ant: Ant

## Current browsing mode (Direct/Attribute)
var current_mode: String = "Direct"

## Currently selected attribute
var current_attribute: String
#endregion

#region UI Properties
## Mode selection dropdown
var mode_switch: OptionButton

## List of available attributes
var attribute_list: ItemList

## Tree view showing property details
var properties_tree: Tree

## Label showing selected property path
var path_label: Label

## Label showing current attribute name
var attribute_label: Label

## Label showing property description
var description_label: Label

var _loading_label: Label
#endregion


#region Initialization
func _ready() -> void:
	_configure_window()
	create_ui()
	create_components()
	_setup_signals()
	DebugLogger.set_log_level(DebugLogger.LogLevel.TRACE)

## Handle input events
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # Escape key
		_on_close_pressed()
		get_viewport().set_input_as_handled()

## Configure window properties
func _configure_window() -> void:
	title = "Ant Property Browser"
	visibility_changed.connect(func(): visible = true) # Keep visible even when clicking elsewhere
	exclusive = true
	unresizable = false
	# Set minimum size to prevent window from becoming too small
	min_size = Vector2(800, 600)

	# Center the window on screen
	var screen_size = DisplayServer.screen_get_size()
	size = screen_size
	position = (screen_size - size) / 2

## Setup signal connections
func _setup_signals() -> void:
	properties_tree.item_mouse_selected.connect(_on_item_selected)
	properties_tree.nothing_selected.connect(_on_tree_deselected)


## Shows properties for a given Ant instance
func show_ant(ant: Ant) -> void:
	current_ant = ant
	_refresh_view()
#endregion

#region UI Creation
## Creates all UI elements and layout
func create_ui() -> void:
	var main_container = _create_main_container()
	_create_mode_selector(main_container)
	_create_content_split(main_container)
	_create_path_display(main_container)
	_create_close_button(main_container)
	_refresh_view()

## Creates test components for demonstration
func create_components() -> void:

	_show_loading_indicator()


	var a: Ant = Ant.new()
	var c: Colony = Colony.new()
	a.colony = c

	a.global_position = _get_random_position()
	c.global_position = _get_random_position()
	a.carried_food.add_food(randf_range(0.0, 200.0))

	add_child(a)
	a.set_physics_process(false)
	a.set_process(false)

	var to_create = {
		"food": randi_range(1000, 5000),
		"pheromones": randi_range(1750, 7500),
		"ants": randi_range(75, 150)
	}
	_staged_creation(to_create, a)
	show_ant(a)

func _show_loading_indicator() -> void:
	_loading_label = Label.new()
	_loading_label.text = "Creating content..."
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Style the label
	_loading_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_loading_label.add_theme_font_size_override("font_size", 24)

	# Position it in the center of the window
	_loading_label.set_anchors_preset(Control.PRESET_CENTER)

	add_child(_loading_label)

## Creates the main container
func _create_main_container() -> VBoxContainer:
	var container = VBoxContainer.new()

	# Use full rect preset but maintain some padding
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)

	# Add custom minimum size to ensure adequate space
	container.custom_minimum_size = Vector2(750, 500)

	# Ensure container expands to fill available space
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	add_child(container)
	return container

## Creates the mode selection UI
func _create_mode_selector(parent: Control) -> void:
	var mode_container = HBoxContainer.new()
	parent.add_child(mode_container)

	var mode_label = Label.new()
	mode_label.text = "Browse Mode:"
	mode_container.add_child(mode_label)

	mode_switch = OptionButton.new()
	mode_switch.add_item("Attribute Properties", 0)
	mode_switch.connect("item_selected", Callable(self, "_on_mode_changed"))
	mode_container.add_child(mode_switch)

## Creates the main content split layout
func _create_content_split(parent: Control) -> void:
	var content_split = HSplitContainer.new()
	content_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Set a larger minimum height to utilize vertical space
	content_split.custom_minimum_size.y = 600

	# Adjust split offset for better initial proportions
	content_split.split_offset = -600
	parent.add_child(content_split)

	_create_attribute_panel(content_split)
	_create_properties_panel(content_split)

## Creates the attribute selection panel
func _create_attribute_panel(parent: Control) -> void:
	var attribute_container = VBoxContainer.new()
	attribute_container.custom_minimum_size.x = 100
	attribute_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attribute_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(attribute_container)

	attribute_label = Label.new()
	attribute_label.text = "Attributes"
	attribute_container.add_child(attribute_label)

	# Configure attribute list to expand vertically
	attribute_list = ItemList.new()
	attribute_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	attribute_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attribute_list.custom_minimum_size.y = 400  # Ensure minimum height
	attribute_list.connect("item_selected", Callable(self, "_on_attribute_selected"))
	attribute_container.add_child(attribute_list)

## Creates the properties panel with tree view and description
func _create_properties_panel(parent: Control) -> void:
	var right_container = VBoxContainer.new()
	right_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Add some spacing between elements
	right_container.add_theme_constant_override("separation", 10)
	parent.add_child(right_container)

	_create_properties_tree(right_container)
	_create_description_panel(right_container)

## Creates the properties tree view
func _create_properties_tree(parent: Control) -> void:
	var tree_container = VBoxContainer.new()
	tree_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(tree_container)

	var properties_label = Label.new()
	properties_label.text = "Properties"
	tree_container.add_child(properties_label)

	properties_tree = Tree.new()
	properties_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	properties_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	properties_tree.custom_minimum_size.y = 400  # Ensure minimum height
	_configure_tree_columns()
	properties_tree.connect("item_selected", Callable(self, "_on_property_selected"))
	tree_container.add_child(properties_tree)

## Creates the description panel
func _create_description_panel(parent: Control) -> void:
	var description_panel = PanelContainer.new()
	# Increased minimum height for better visibility of descriptions
	description_panel.custom_minimum_size.y = 150  # Increased from 100
	parent.add_child(description_panel)

	var description_container = VBoxContainer.new()
	description_container.add_theme_constant_override("separation", 5)
	description_panel.add_child(description_container)

	var description_title = Label.new()
	description_title.text = "Description"
	description_container.add_child(description_title)

	description_label = Label.new()
	description_label.text = ""
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_label.custom_minimum_size.y = 100  # Ensure minimum height for text
	description_container.add_child(description_label)


## Creates the property path display
func _create_path_display(parent: Control) -> void:
	var path_container = HBoxContainer.new()
	# Add some padding around the path display
	path_container.add_theme_constant_override("separation", 10)
	parent.add_child(path_container)

	var path_title = Label.new()
	path_title.text = "Selected Property Path:"
	path_container.add_child(path_title)

	path_label = Label.new()
	path_label.text = ""
	path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_container.add_child(path_label)

## Creates the close button
func _create_close_button(parent: Control) -> void:
	var button_container = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 10)
	parent.add_child(button_container)

	var close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(100, 30)  # Set fixed size for button
	close_button.connect("pressed", Callable(self, "_on_close_pressed"))
	button_container.add_child(close_button)
#endregion

#region Tree Management
## Configures the tree view columns
func _configure_tree_columns() -> void:
	properties_tree.columns = 4
	properties_tree.set_column_title(COL_NAME, "Property")
	properties_tree.set_column_title(COL_TYPE, "Type")
	properties_tree.set_column_title(COL_VALUE, "Value")
	properties_tree.set_column_title(COL_DEPENDENCIES, "Dependencies")

	for col in range(4):
		properties_tree.set_column_title_alignment(col, HORIZONTAL_ALIGNMENT_LEFT)
		properties_tree.set_column_clip_content(col, true)

	properties_tree.set_column_expand(COL_NAME, true)
	properties_tree.set_column_expand(COL_TYPE, false)
	properties_tree.set_column_expand(COL_VALUE, true)
	properties_tree.set_column_expand(COL_DEPENDENCIES, true)

	properties_tree.set_column_custom_minimum_width(COL_NAME, 200)
	properties_tree.set_column_custom_minimum_width(COL_TYPE, 150)
	properties_tree.set_column_custom_minimum_width(COL_VALUE, _original_value_width)
	properties_tree.set_column_custom_minimum_width(COL_DEPENDENCIES, 200)

	properties_tree.column_titles_visible = true

## Populates a tree item with property data
func _populate_tree_item(item: TreeItem, property: Variant) -> void:
	if not property:
		return

	if property is Property:
		_populate_regular_property(item, property)
	elif property is NestedProperty:
		_populate_nested_property(item, property)

## Handles tree item selection
func _on_item_selected(location, button) -> void:
	var selected = properties_tree.get_selected()
	if not selected:
		return

	var column = properties_tree.get_selected_column()
	if column == COL_VALUE:
		_handle_value_cell_click(selected)
	else:
		_collapse_expanded_cell()

## Populates a tree item with regular property data
func _populate_regular_property(item: TreeItem, property: Property) -> void:
	item.set_text(COL_NAME, Helper.snake_to_readable(property.name))
	item.set_text(COL_TYPE, Property.type_to_string(property.type))
	var value_text = Property.format_value(property.value)
	var wrapped_text = _wrap_text(value_text)
	item.set_text(COL_VALUE, _get_condensed_text(value_text))
	item.set_tooltip_text(COL_VALUE, value_text)
	item.set_metadata(1, wrapped_text)
	item.set_selectable(COL_VALUE, true)
	var dependencies_text = "None" if property.dependencies.is_empty() else "\n".join(property.dependencies)
	item.set_text(COL_DEPENDENCIES, dependencies_text)
	if not property.dependencies.is_empty():
		item.set_tooltip_text(COL_DEPENDENCIES, "Dependencies:\n" + dependencies_text)
	item.set_metadata(0, property)

## Populates a tree item with nested property data
func _populate_nested_property(item: TreeItem, property: NestedProperty) -> void:
	item.set_text(COL_NAME, Helper.snake_to_readable(property.name))

	if property.type == NestedProperty.Type.CONTAINER:
		item.set_text(COL_TYPE, "Group")
		item.set_selectable(COL_VALUE, false)
		# Add children
		for child in property.children.values():
			var child_item = properties_tree.create_item(item)
			_populate_nested_property(child_item, child)
	else:
		item.set_text(COL_TYPE, Property.type_to_string(property.value_type))
		var value = property.get_value()
		var value_text = Property.format_value(value)
		var wrapped_text = _wrap_text(value_text)
		item.set_text(COL_VALUE, _get_condensed_text(value_text))
		item.set_tooltip_text(COL_VALUE, value_text)
		item.set_metadata(1, wrapped_text)
		item.set_selectable(COL_VALUE, true)

	var dependencies_text = "None" if property.dependencies.is_empty() else "\n".join(property.dependencies)
	item.set_text(COL_DEPENDENCIES, dependencies_text)
	if not property.dependencies.is_empty():
		item.set_tooltip_text(COL_DEPENDENCIES, "Dependencies:\n" + dependencies_text)
	item.set_metadata(0, property)

### Handles value cell click events
func _handle_value_cell_click(item: TreeItem) -> void:
	if item == _expanded_item:
		_collapse_expanded_cell()
	_expand_cell(item)

## Expands a cell to show full content
func _expand_cell(item: TreeItem) -> void:
	var full_text = item.get_metadata(1)
	item.set_text(COL_VALUE, full_text)
	_expanded_item = item

## Collapses currently expanded cell
func _collapse_expanded_cell() -> void:
	if _expanded_item != null:
		var full_text = _expanded_item.get_metadata(1)
		_expanded_item.set_text(COL_VALUE, _get_condensed_text(full_text))
		_expanded_item = null


## Handles tree deselection
func _on_tree_deselected() -> void:
	_collapse_expanded_cell()

## Handles mode selection changes
func _on_mode_changed(index: int) -> void:
	attribute_label.text = "Attributes"
	_refresh_view()

## Handles attribute selection
func _on_attribute_selected(index: int) -> void:
	var attribute_name = attribute_list.get_item_text(index).to_lower()
	_trace("Attribute selected: %s" % attribute_name)
	current_attribute = attribute_name
	_populate_properties(attribute_name)
	description_label.text = ""

## Handles property selection
func _on_property_selected() -> void:
	var selected = properties_tree.get_selected()
	if not selected:
		_warn("No valid property selected")
		return

	var property = selected.get_metadata(0)
	if not property:
		_warn("No valid property info found for selection")
		return

	if property is Property:
		_update_property_selection(property)
	elif property is NestedProperty and property.type == NestedProperty.Type.PROPERTY:
		_update_nested_property_selection(property)

## Handles close button press
func _on_close_pressed() -> void:
	transition_to_scene("main")
#endregion

#region Data Management
## Refreshes the entire view
func _refresh_view() -> void:
	if not current_ant:
		_warn("No ant set for Property Browser scene")
		return

	_expanded_item = null
	_refresh_attributes()
	path_label.text = "none"

## Refreshes the attributes list
func _refresh_attributes() -> void:
	_trace("Refreshing attributes list")
	attribute_list.clear()
	properties_tree.clear()

	var attributes = _get_attribute_names()
	for attribute_name in attributes:
		attribute_list.add_item(attribute_name.capitalize())

## Populates properties for a given attribute
## Populates properties for a given attribute
func _populate_properties(attribute: String) -> void:
	_trace("Populating properties for attribute: %s" % attribute)
	properties_tree.clear()
	path_label.text = "none"
	var root = properties_tree.create_item()
	properties_tree.hide_root = true

	# Get both regular and nested properties
	var regular_properties = _get_regular_properties(attribute)
	var nested_properties = _get_nested_properties(attribute)

	# Add regular properties first
	for property in regular_properties:
		var item = properties_tree.create_item(root)
		_populate_regular_property(item, property)

	# Add nested properties
	for property in nested_properties:
		var item = properties_tree.create_item(root)
		_populate_nested_property(item, property)

## Gets regular attribute properties
func _get_regular_properties(attribute: String) -> Array[Property]:
	if not current_ant:
		push_error("No ant set for property access")
		return []
	return current_ant.get_attribute_properties(attribute)

## Gets nested attribute properties
func _get_nested_properties(attribute: String) -> Array[NestedProperty]:
	if not current_ant:
		push_error("No ant set for property access")
		return []
	return current_ant.get_attribute_nested_properties(attribute)

## Updates UI for regular property selection
func _update_property_selection(property: Property) -> void:
	var path = current_attribute + "." + property.name
	path_label.text = path
	description_label.text = property.description
	property_selected.emit(path)

## Updates UI for nested property selection
func _update_nested_property_selection(property: NestedProperty) -> void:
	var path = current_attribute + "." + property.get_full_path()
	path_label.text = path
	description_label.text = property.description
	property_selected.emit(path)
#endregion

#region Property Access Methods
## Gets attribute properties through ant's property access system
func _get_attribute_properties(attribute: String) -> Array[Property]:
	if not current_ant:
		push_error("No ant set for property access")
		return []
	return current_ant.get_attribute_properties(attribute)

## Gets all attribute names through ant's property access system
func _get_attribute_names() -> Array[String]:
	if not current_ant:
		push_error("No ant set for property access")
		return []
	return current_ant.get_attribute_names()
#endregion

#region Component Creation
## Handles staged creation of components
func _staged_creation(params: Dictionary, main_ant: Ant) -> void:
	var items_created: int
	for key in params:
		items_created += params.get(key, 0)
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.016  # ~60fps
	timer.connect("timeout", Callable(self, "_create_batch").bind(params, timer))
	timer.start()
	await content_created
	_loading_label.text ="Finished! Created %s items" % items_created
	await get_tree().create_timer(2.5).timeout
	if _loading_label:
		_loading_label.queue_free()
		_loading_label = null

## Creates a batch of components per frame
func _create_batch(params: Dictionary, timer: Timer) -> void:
	var items_created = 0

	# Create food
	while params.food > 0 and items_created < ITEMS_PER_FRAME:
		_loading_label.text ="Creating content: food (%s)" % params.food
		var food = Food.new(randf_range(0.0, 50.0))
		food.global_position = _get_random_position()
		add_child(food)
		params.food -= 1
		items_created += 1


	# Create ants if pheromones are done
	while params.food == 0 and params.pheromones == 0 and params.ants > 0 and items_created < ITEMS_PER_FRAME:
		_loading_label.text ="Creating content: ants (%s)" % params.ants
		var ant = Ant.new()
		ant.global_position = _get_random_position()
		add_child(ant)
		ant.set_physics_process(false)
		ant.set_process(false)
		params.ants -= 1
		items_created += 1

	# Create pheromones if food is done
	while params.food == 0 and params.pheromones > 0 and items_created < ITEMS_PER_FRAME:
		_loading_label.text ="Creating content: pheromones (%s)" % params.pheromones
		var pheromone = Pheromone.new(
			_get_random_position(),
			["food", "home"].pick_random(),
			randf_range(0.0, 100.0),
			Ants.all().as_array().pick_random()
		)
		add_child(pheromone)
		params.pheromones -= 1
		items_created += 1

	# Stop if everything is created
	if params.food == 0 and params.pheromones == 0 and params.ants == 0:
		timer.queue_free()
		content_created.emit()
#endregion

#region Helper Functions
## Gets random position within window bounds
func _get_random_position() -> Vector2:
	return Vector2(randf_range(0, 1800), randf_range(0, 800))

## Condenses text to specified length with ellipsis
func _get_condensed_text(text: String, max_length: int = 50) -> String:
	if text.length() <= max_length:
		return text
	return text.substr(0, max_length - 3) + "..."

## Wraps text to specified width
func _wrap_text(text: String, width: int = 50) -> String:
	var lines = []
	var current_line = ""
	var words = text.split(" ")

	for word in words:
		if current_line.length() + word.length() + 1 <= width:
			if current_line.length() > 0:
				current_line += " "
			current_line += word
		else:
			if current_line.length() > 0:
				lines.append(current_line)
			current_line = word

	if current_line.length() > 0:
		lines.append(current_line)

	return "\n".join(lines)

## Logs a trace message
func _trace(message: String) -> void:
	DebugLogger.trace(DebugLogger.Category.PROPERTY,
		message,
		{"From": "property_browser"}
	)

## Logs an error message
func _error(message: String) -> void:
	DebugLogger.error(DebugLogger.Category.PROPERTY,
		message
	)

## Logs a warning message
func _warn(message: String) -> void:
	DebugLogger.warn(DebugLogger.Category.PROPERTY,
		message
	)

## Transitions to a new scene
func transition_to_scene(scene_name: String) -> void:
	create_tween().tween_callback(Callable(self, "_change_scene").bind(scene_name))

## Changes to the specified scene
func _change_scene(scene_name: String) -> void:
	var error = get_tree().change_scene_to_file("res://" + "ui" + "/" + scene_name + ".tscn")
	if error != OK:
		DebugLogger.error(DebugLogger.Category.PROGRAM, "Failed to load scene: " + scene_name)
#endregion
