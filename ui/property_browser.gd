class_name PropertyBrowser
extends Window

#region Signals
signal property_selected(property_path: String)
#endregion

#region Constants
## Tree view column indices
const COL_NAME = 0
const COL_TYPE = 1
const COL_VALUE = 2
const COL_DEPENDENCIES = 3  
#endregion

#region UI Elements
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
#endregion

#region Member Variables
## Reference to current Ant instance
var current_ant: Ant

## Current browsing mode (Direct/Attribute)
var current_mode: String = "Direct"

## Currently selected attribute
var current_attribute: String

## Property access manager
var _property_access: PropertyAccess
#endregion

#region Initialization
func _ready() -> void:
	_configure_window()
	create_ui()
	create_components()
	DebugLogger.set_log_level(DebugLogger.LogLevel.TRACE)


## Configure window properties
func _configure_window() -> void:
	title = "Ant Property Browser"
	size = Vector2(1800, 700)  # Increased width to accommodate new column
	exclusive = false
	unresizable = false

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

func create_components() -> void:
	var a: Ant = Ant.new()
	var c: Colony = Colony.new()
	a.colony = c

	a.global_position = Vector2(randf_range(0, 1800), randf_range(0, 800))
	c.global_position = Vector2(randf_range(0, 1800), randf_range(0, 800))
	
	show_ant(a)

## Creates the main container
func _create_main_container() -> VBoxContainer:
	var container = VBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
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
	content_split.split_offset = 150
	parent.add_child(content_split)
	
	_create_attribute_panel(content_split)
	_create_properties_panel(content_split)

## Creates the attribute selection panel
func _create_attribute_panel(parent: Control) -> void:
	var attribute_container = VBoxContainer.new()
	attribute_container.custom_minimum_size.x = 150
	attribute_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(attribute_container)
	
	attribute_label = Label.new()
	attribute_label.text = "Attributes"
	attribute_container.add_child(attribute_label)
	
	attribute_list = ItemList.new()
	attribute_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	attribute_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attribute_list.connect("item_selected", Callable(self, "_on_attribute_selected"))
	attribute_container.add_child(attribute_list)

## Creates the properties panel with tree view and description
func _create_properties_panel(parent: Control) -> void:
	var right_container = VBoxContainer.new()
	right_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(right_container)
	
	_create_properties_tree(right_container)
	_create_description_panel(right_container)

## Creates the properties tree view
func _create_properties_tree(parent: Control) -> void:
	var properties_label = Label.new()
	properties_label.text = "Properties"
	parent.add_child(properties_label)
	
	properties_tree = Tree.new()
	properties_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	properties_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_configure_tree_columns()
	properties_tree.connect("item_selected", Callable(self, "_on_property_selected"))
	parent.add_child(properties_tree)


## Configures the tree view columns
func _configure_tree_columns() -> void:
	properties_tree.columns = 4  # Increased to 4 columns
	properties_tree.set_column_title(COL_NAME, "Property")
	properties_tree.set_column_title(COL_TYPE, "Type")
	properties_tree.set_column_title(COL_VALUE, "Value")
	properties_tree.set_column_title(COL_DEPENDENCIES, "Dependencies")
	
	for col in range(4):  # Updated range for 4 columns
		properties_tree.set_column_title_alignment(col, HORIZONTAL_ALIGNMENT_LEFT)
	
	properties_tree.set_column_expand(COL_NAME, true)
	properties_tree.set_column_expand(COL_TYPE, false)
	properties_tree.set_column_expand(COL_VALUE, true)
	properties_tree.set_column_expand(COL_DEPENDENCIES, true)
	
	properties_tree.set_column_custom_minimum_width(COL_NAME, 300)
	properties_tree.set_column_custom_minimum_width(COL_TYPE, 150)
	properties_tree.set_column_custom_minimum_width(COL_VALUE, 250)
	properties_tree.set_column_custom_minimum_width(COL_DEPENDENCIES, 300)  # Width for dependencies
	
	properties_tree.column_titles_visible = true

## Creates the description panel
func _create_description_panel(parent: Control) -> void:
	var description_panel = PanelContainer.new()
	description_panel.custom_minimum_size.y = 100
	parent.add_child(description_panel)
	
	var description_container = VBoxContainer.new()
	description_panel.add_child(description_container)
	
	var description_title = Label.new()
	description_title.text = "Description"
	description_container.add_child(description_title)
	
	description_label = Label.new()
	description_label.text = ""
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_container.add_child(description_label)

## Creates the property path display
func _create_path_display(parent: Control) -> void:
	var path_container = HBoxContainer.new()
	parent.add_child(path_container)
	
	var path_title = Label.new()
	path_title.text = "Selected Property Path:"
	path_container.add_child(path_title)
	
	path_label = Label.new()
	path_label.text = ""
	path_container.add_child(path_label)

## Creates the close button
func _create_close_button(parent: Control) -> void:
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.connect("pressed", Callable(self, "_on_close_pressed"))
	parent.add_child(close_button)
#endregion

#region Event Handlers
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
		DebugLogger.warn(DebugLogger.Category.PROPERTY, "No valid property selected")
		return
		
	var property_info = selected.get_metadata(0) as PropertyResult.PropertyInfo
	if not property_info:
		DebugLogger.warn(DebugLogger.Category.PROPERTY, "No valid property info found for selection")
		return
	
	_update_property_selection(property_info)
#endregion

#region Data Management
## Refreshes the entire view
func _refresh_view() -> void:
	if not current_ant:
		DebugLogger.warn(DebugLogger.Category.CONTEXT, "No ant set for Property Browser scene")
		return
	
	_refresh_attributes()
	path_label.text = ""

## Refreshes the attributes list
func _refresh_attributes() -> void:
	DebugLogger.trace(DebugLogger.Category.PROPERTY, "Refreshing attributes list")
	
	attribute_list.clear()
	properties_tree.clear()
	
	var attributes = current_ant.get_attribute_names()
	for attribute_name in attributes:
		attribute_list.add_item(attribute_name.capitalize())

## Populates properties for a given attribute
func _populate_properties(attribute: String) -> void:
	DebugLogger.trace(DebugLogger.Category.PROPERTY, "Populating properties for attribute: %s" % attribute)
	properties_tree.clear()
	var root = properties_tree.create_item()
	properties_tree.hide_root = true
	
	var property_results = current_ant.get_attribute_properties(attribute)
	if property_results.is_empty():
		DebugLogger.warn(DebugLogger.Category.PROPERTY, 
			"No properties found for attribute: %s" % attribute)
		return
	
	for property_result in property_results:
		if not property_result.success():
			DebugLogger.warn(DebugLogger.Category.PROPERTY,
				"Failed to get property in attribute %s: %s" % [
					attribute, property_result.error_message
				])
			continue
			
		var item = properties_tree.create_item(root)
		_populate_tree_item(item, property_result)

## Populates a tree item with property data
func _populate_tree_item(item: TreeItem, property_result: PropertyResult) -> void:
	var property_info = property_result.property_info as PropertyResult.PropertyInfo
	if not property_info:
		DebugLogger.error(DebugLogger.Category.PROPERTY,
			"Property result missing metadata: %s" % property_result.error_message)
		return
	
	item.set_text(COL_NAME, Helper.snake_to_readable(property_info.name))
	item.set_text(COL_TYPE, Component.type_to_string(property_info.type))
	item.set_text(COL_VALUE, PropertyResult.format_value(property_result.value))
	
	# Add dependencies information
	var dependencies_text = ""
	if property_info.dependencies.is_empty():
		dependencies_text = "None"
	else:
		# Format the dependencies list
		dependencies_text = "\n".join(property_info.dependencies)
	
	item.set_text(COL_DEPENDENCIES, dependencies_text)
	
	# Set tooltip for dependencies column if there are any
	if not property_info.dependencies.is_empty():
		item.set_tooltip_text(COL_DEPENDENCIES, "Dependencies:\n" + dependencies_text)
	
	item.set_metadata(0, property_info)

## Updates UI after property selection
func _update_property_selection(property_info: PropertyResult.PropertyInfo) -> void:
	description_label.text = property_info.description if not property_info.description.is_empty() else "No description available."
	
	var path = "%s.%s" % [current_attribute, property_info.name]
	path_label.text = path
	property_selected.emit(path)
#endregion

#region Helper Functions
## Formats a value for display
func _format_value(value: Variant) -> String:
	return PropertyResult.format_value(value)

## Logs a trace message
func _trace(message: String) -> void:
	DebugLogger.trace(DebugLogger.Category.PROPERTY,
		message,
		{"From": "property_browser"}
	)
#endregion
