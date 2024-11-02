class_name PropertyBrowser
extends Popup

signal property_selected(property_path: String)

var mode_switch: OptionButton
var category_list: ItemList
var properties_list: ItemList
var path_label: Label
var category_label: Label  # New reference to the label

var current_ant: Ant
var current_mode: String = "Direct"  # "Direct" or "Attributes"
var current_category: String

func _ready() -> void:
	create_ui()
	var ant: Ant = Ant.new()
	show_ant(ant)

func create_ui() -> void:
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	add_child(main_container)
	
	# Title
	var title = Label.new()
	title.text = "Ant Property Browser"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title)
	
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
	
	# Lists container
	var lists_container = HBoxContainer.new()
	lists_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(lists_container)
	
	# Category List
	var category_container = VBoxContainer.new()
	category_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lists_container.add_child(category_container)
	
	# Store reference to category label
	category_label = Label.new()
	category_label.text = "Categories"  # Default text
	category_container.add_child(category_label)
	
	category_list = ItemList.new()
	category_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	category_list.connect("item_selected", Callable(self, "_on_category_selected"))
	category_container.add_child(category_list)
	
	# Properties List
	var properties_container = VBoxContainer.new()
	properties_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lists_container.add_child(properties_container)
	
	var properties_label = Label.new()
	properties_label.text = "Properties"
	properties_container.add_child(properties_label)
	
	properties_list = ItemList.new()
	properties_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	properties_list.connect("item_selected", Callable(self, "_on_property_selected"))
	properties_container.add_child(properties_list)
	
	# Property Path Display
	var path_container = VBoxContainer.new()
	main_container.add_child(path_container)
	
	var path_title = Label.new()
	path_title.text = "Selected Property Path:"
	path_container.add_child(path_title)
	
	path_label = Label.new()
	path_label.text = ""
	path_container.add_child(path_label)

func show_ant(ant: Ant) -> void:
	if not ant:
		return
	current_ant = ant
	_refresh_categories()

func _on_mode_changed(index: int) -> void:
	current_mode = "Direct" if index == 0 else "Attributes"
	# Update the category label based on mode
	category_label.text = "Categories" if current_mode == "Direct" else "Attributes"
	_refresh_categories()

func _refresh_categories() -> void:
	category_list.clear()
	properties_list.clear()
	path_label.text = ""
	
	if current_mode == "Direct":
		# Show method categories
		for category in current_ant._exposed_methods:
			category_list.add_item(category)
	else:
		# Show attributes 
		for attr_name in current_ant._exposed_attributes: # TODO: Use access via ant.attributes
			if current_ant._exposed_attributes[attr_name]:
				category_list.add_item(attr_name)

func _on_category_selected(index: int) -> void:
	properties_list.clear()
	path_label.text = ""
	
	var category_name = category_list.get_item_text(index)
	current_category = category_name
	
	if current_mode == "Direct":
		# Show methods in category
		var methods = current_ant._exposed_methods[category_name]
		for method_name in methods:
			var value = current_ant.get_method_result(method_name)
			var display_text = "%s (%s)" % [method_name, typeof_as_string(value)]
			properties_list.add_item(display_text)
			_update_metadata(properties_list, properties_list.get_item_count() - 1, {
				"name": method_name,
				"type": typeof_as_string(value),
				"is_method": true
			})
	else:
		# Show attribute properties
		var properties = current_ant.get_attribute_properties(category_name)
		for prop_name in properties:
			var prop_info = properties[prop_name]
			var type_str = Attribute.type_to_string(prop_info["type"])
			var display_text = "%s (%s)" % [prop_name, type_str]
			properties_list.add_item(display_text)
			_update_metadata(properties_list, properties_list.get_item_count() - 1, {
				"name": prop_name,
				"type": type_str,
				"is_method": false,
				"value": prop_info["value"]
			})

func _on_property_selected(index: int) -> void:
	var metadata = _get_metadata(properties_list, index)
	if not metadata:
		return
	
	var path: String
	if current_mode == "Direct":
		path = metadata.name  # Just the method name for direct properties
	else:
		path = "%s.%s" % [current_category, metadata.name]  # attribute.property format
	
	path_label.text = path
	emit_signal("property_selected", path)

# Helper functions
func _update_metadata(item_list: ItemList, index: int, data: Variant) -> void:
	item_list.set_item_metadata(index, data)

func _get_metadata(item_list: ItemList, index: int) -> Variant:
	return item_list.get_item_metadata(index)

# Get type information for a property
func get_property_type(property_path: String) -> String:
	if not current_ant:
		return "Unknown"
	
	if not "." in property_path:
		# It's a direct method
		var value = current_ant.get_method_result(property_path)
		return typeof_as_string(value)
	
	# It's an attribute property
	var parts = property_path.split(".")
	var attribute_name = parts[0]
	var property_name = parts[1]
	
	if attribute_name in current_ant.exposed_attributes:
		var attribute = current_ant.exposed_attributes[attribute_name]
		if attribute and "_exposed_properties" in attribute:
			var prop_info = attribute._exposed_properties.get(property_name)
			if prop_info:
				var value = prop_info["getter"].call()
				return typeof_as_string(value)
	
	return "Unknown"

# Helper function to get type string
func typeof_as_string(value: Variant) -> String:
	match typeof(value):
		TYPE_BOOL: return "Boolean"
		TYPE_INT: return "Integer"
		TYPE_FLOAT: return "Float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR3: return "Vector3"
		TYPE_ARRAY: return "Array"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_OBJECT: return value.get_class() if value else "Object"
		_: return "Unknown"
