class_name PropertyBrowser
extends Window

signal property_selected(property_path: String)

var mode_switch: OptionButton
var category_list: ItemList
var properties_tree: Tree
var path_label: Label
var category_label: Label
var description_label: Label

var current_ant: Ant
var current_mode: String = "Direct"
var current_category: String
var current_info: PropertyInspector.ObjectInfo

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
	show_ant(Ant.new())

func show_ant(ant: Ant) -> void:
	if not ant:
		return
	current_ant = ant
	_refresh_view()

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
	mode_switch.add_item("Direct Properties", 0)
	mode_switch.add_item("Attribute Properties", 1)
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
	current_mode = "Direct" if index == 0 else "Attributes"
	category_label.text = "Categories" if current_mode == "Direct" else "Attributes"
	_refresh_view()

func _refresh_view() -> void:
	if not current_ant:
		return
	
	# Get fresh object info using containers
	current_info = PropertyInspector.get_object_info(current_ant)
	
	# Update UI
	_populate_categories()
	path_label.text = ""

func _populate_properties(category: PropertyInspector.CategoryInfo) -> void:
	properties_tree.clear()
	var root = properties_tree.create_item()
	properties_tree.hide_root = true
	
	for prop in category.properties:
		var item = properties_tree.create_item(root)
		item.set_text(COL_NAME, PropertyBrowser.snake_to_readable(prop.name))
		item.set_text(COL_TYPE, prop.type)
		
		# Format value based on type
		var value_text = _format_value(prop.value)
		item.set_text(COL_VALUE, value_text)
		
		# Store property info in metadata for later use
		item.set_metadata(0, prop)
		
## Helper function to convert snake_case to Title Case
static func snake_to_readable(text: String) -> String:
	# Replace underscores with spaces and capitalize each word
	var words = text.split("_")
	for i in range(words.size()):
		words[i] = words[i].capitalize() if i == 0 else words[i]
	return " ".join(words)
	
func _populate_categories() -> void:
	category_list.clear()
	properties_tree.clear()

	if not current_info:
		print("No current info while populating categories")  # Debug
		return
	
	# Show appropriate categories based on mode
	var categories = current_info.direct_categories if current_mode == "Direct" else current_info.attributes
	print("Populating ", categories.size(), " categories for mode: ", current_mode)  # Debug
		
	for category in categories:
		print("Adding category: ", category.name, " with ", category.properties.size(), " properties")  # Debug
		category_list.add_item(category.name.capitalize())

func _on_category_selected(index: int) -> void:
	var categories = current_info.direct_categories if current_mode == "Direct" else current_info.attributes
	if index < 0 or index >= categories.size():
		return
	
	var category = categories[index]
	current_category = category.name
	_populate_properties(category)
	description_label.text = ""  # Clear description when category changes

func _on_property_selected() -> void:
	var selected = properties_tree.get_selected()
	if not selected:
		return
		
	var prop = selected.get_metadata(0) as PropertyInspector.PropertyInfo
	if not prop:
		return
	
	# Update description
	description_label.text = prop.description if not prop.description.is_empty() else "No description available."
	
	# Update property path
	var path: String
	if current_mode == "Direct":
		path = prop.name
	else:
		path = "%s.%s" % [current_category, prop.name]
		
	path_label.text = path
	property_selected.emit(path)



func _refresh_categories() -> void:
	category_list.clear()
	path_label.text = ""
	
	if current_mode == "Direct":
		# Show categories from PropertiesContainer
		for category in current_ant.properties_container.get_categories():
			category_list.add_item(category)
	else:
		# Show attributes from AttributesContainer
		for attr_name in current_ant.attributes_container.get_attributes():
			category_list.add_item(attr_name)

# Helper functions
func _update_metadata(item_list: ItemList, index: int, data: Variant) -> void:
	item_list.set_item_metadata(index, data)

func _get_metadata(item_list: ItemList, index: int) -> Variant:
	return item_list.get_item_metadata(index)

func _format_value(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "<null>"
		TYPE_BOOL:
			return str(value).to_lower()
		TYPE_INT, TYPE_FLOAT:
			return str(value)
		TYPE_STRING:
			return '"%s"' % value if not value.is_empty() else '""'
		TYPE_VECTOR2:
			var v = value as Vector2
			return "(%.1f, %.1f)" % [v.x, v.y]
		TYPE_VECTOR3:
			var v = value as Vector3
			return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]
		TYPE_ARRAY:
			return "[...]" if not value.is_empty() else "[]"
		TYPE_DICTIONARY:
			return "{...}" if not value.is_empty() else "{}"
		TYPE_OBJECT:
			return value.get_class() if value else "<null>"
		_:
			return str(value)
