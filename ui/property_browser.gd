class_name PropertyBrowser
extends Window

signal property_selected(property_path: String)

#region UI Elements
var mode_switch: OptionButton
var category_list: ItemList
var properties_tree: Tree
var path_label: Label
var category_label: Label
var description_label: Label
#endregion

#region Member Variables
var current_ant: Ant
var current_mode: String = "Direct"
var current_category: String
var _property_access: PropertyAccess
#endregion

# Column indices
const COL_NAME = 0
const COL_TYPE = 1
const COL_VALUE = 2

func _ready() -> void:
	# Set up window properties
	title = "Ant Property Browser"
	size = Vector2(1000, 700)
	exclusive = false
	unresizable = false
	# Create the UI
	create_ui()
	DebugLogger.set_log_level(DebugLogger.LogLevel.TRACE)
	show_ant(Ant.new())

func show_ant(ant: Ant) -> void:
	current_ant = ant
	_refresh_view()
	
## Creates all UI elements
func create_ui() -> void:
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	add_child(main_container)
	
	# Mode Switch
	var mode_container = HBoxContainer.new()
	main_container.add_child(mode_container)
	
	var mode_label = Label.new()
	mode_label.text = "Browse Mode:"
	mode_container.add_child(mode_label)
	
	mode_switch = OptionButton.new()
	mode_switch.add_item("Attribute Properties", 0)
	mode_switch.connect("item_selected", Callable(self, "_on_mode_changed"))
	mode_container.add_child(mode_switch)
	
	# Main content split with adjusted proportions
	var content_split = HSplitContainer.new()
	content_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_split.split_offset = 150
	main_container.add_child(content_split)
	
	# Left side - Categories (now narrower)
	var category_container = VBoxContainer.new()
	category_container.custom_minimum_size.x = 150
	category_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	content_split.add_child(category_container)
	
	category_label = Label.new()
	category_label.text = "Categories"
	category_container.add_child(category_label)
	
	category_list = ItemList.new()
	category_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	category_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_list.connect("item_selected", Callable(self, "_on_category_selected"))
	category_container.add_child(category_list)
	
	# Right side - Properties and Description (wider)
	var right_container = VBoxContainer.new()
	right_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_split.add_child(right_container)
	
	# Properties Tree with adjusted columns
	var properties_label = Label.new()
	properties_label.text = "Properties"
	right_container.add_child(properties_label)
	
	properties_tree = Tree.new()
	properties_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	properties_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	properties_tree.columns = 3
	properties_tree.set_column_title(COL_NAME, "Property")
	properties_tree.set_column_title(COL_TYPE, "Type")
	properties_tree.set_column_title(COL_VALUE, "Value")
	
	# Set left alignment for column titles
	properties_tree.set_column_title_alignment(COL_NAME, HORIZONTAL_ALIGNMENT_LEFT)
	properties_tree.set_column_title_alignment(COL_TYPE, HORIZONTAL_ALIGNMENT_LEFT)
	properties_tree.set_column_title_alignment(COL_VALUE, HORIZONTAL_ALIGNMENT_LEFT)
	
	# Rest remains the same
	properties_tree.set_column_expand(COL_NAME, true)
	properties_tree.set_column_expand(COL_TYPE, false)
	properties_tree.set_column_expand(COL_VALUE, true)
	
	properties_tree.set_column_custom_minimum_width(COL_NAME, 200)
	properties_tree.set_column_custom_minimum_width(COL_TYPE, 100)
	properties_tree.set_column_custom_minimum_width(COL_VALUE, 150)
	
	properties_tree.column_titles_visible = true
	properties_tree.connect("item_selected", Callable(self, "_on_property_selected"))
	right_container.add_child(properties_tree)
	
	# Description Panel
	var description_panel = PanelContainer.new()
	description_panel.custom_minimum_size.y = 100
	right_container.add_child(description_panel)
	
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
	
	# Property Path Display
	var path_container = HBoxContainer.new()
	main_container.add_child(path_container)
	
	var path_title = Label.new()
	path_title.text = "Selected Property Path:"
	path_container.add_child(path_title)
	
	path_label = Label.new()
	path_label.text = ""
	path_container.add_child(path_label)
	
	# Close button
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.connect("pressed", Callable(self, "_on_close_pressed"))
	main_container.add_child(close_button)

func _on_mode_changed(index: int) -> void:
	category_label.text = "Attributes"
	_refresh_view()

func _refresh_view() -> void:
	if not current_ant:
		DebugLogger.warn(DebugLogger.Category.CONTEXT, "No ant set for Property Browser scene")
		return
	
	_refresh_categories()
	path_label.text = ""

func _populate_properties(category: String) -> void:
	DebugLogger.trace(DebugLogger.Category.PROPERTY, "Populating properties for category: %s" % category)
	properties_tree.clear()
	var root = properties_tree.create_item()
	properties_tree.hide_root = true
	
	# Get properties directly from ant
	var property_results = current_ant.get_category_properties(category)
	if property_results.is_empty():
		DebugLogger.warn(DebugLogger.Category.PROPERTY, 
			"No properties found for category: %s" % category)
		return
	
	for property_result in property_results:
		if not property_result.success():
			DebugLogger.warn(DebugLogger.Category.PROPERTY,
				"Failed to get property in category %s: %s" % [
					category, property_result.error_message
				])
			continue
			
		var item = properties_tree.create_item(root)
		_populate_tree_item(item, property_result)

func _populate_tree_item(item: TreeItem, property_result: PropertyResult) -> void:
	# Get property info from the metadata
	var property_info = property_result.property_info as PropertyResult.PropertyInfo
	if not property_info:
		DebugLogger.error(DebugLogger.Category.PROPERTY,
			"Property result missing metadata: %s" % property_result.error_message)
		return
		
	item.set_text(COL_NAME, Helper.snake_to_readable(property_info.name))
	item.set_text(COL_TYPE, Component.type_to_string(property_info.type))
	item.set_text(COL_VALUE, PropertyResult.format_value(property_result.value))
	item.set_metadata(0, property_info)

func _refresh_categories() -> void:
	DebugLogger.trace(DebugLogger.Category.PROPERTY, "Refreshing categories")
	
	category_list.clear()
	properties_tree.clear()
	
	# Get categories directly from ant
	var categories = current_ant.get_categories()
	for category_name in categories:
		category_list.add_item(category_name.capitalize())

func _on_category_selected(index: int) -> void:
	var category_name = category_list.get_item_text(index).to_lower()
	_trace("Category selected: %s" % category_name)
	current_category = category_name
	_populate_properties(category_name)
	description_label.text = ""  # Clear description when category changes

func _on_property_selected() -> void:
	var selected = properties_tree.get_selected()
	if not selected:
		DebugLogger.warn(DebugLogger.Category.PROPERTY, "No valid property selected")
		return
		
	var property_info = selected.get_metadata(0) as PropertyResult.PropertyInfo
	if not property_info:
		DebugLogger.warn(DebugLogger.Category.PROPERTY, "No valid property info found for selection")
		return
	
	# Update description
	description_label.text = property_info.description if not property_info.description.is_empty() else "No description available."
	
	# Update property path
	var path: String
	if current_mode == "Direct":
		path = property_info.name
	else:
		path = "%s.%s" % [current_category, property_info.name]
		
	path_label.text = path
	property_selected.emit(path)
	
func _format_value(value: Variant) -> String:
	return PropertyResult.format_value(value)

func _trace(message: String) -> void:
	DebugLogger.trace(DebugLogger.Category.PROPERTY,
		message,
		{"From": "property_browser"}
	)
