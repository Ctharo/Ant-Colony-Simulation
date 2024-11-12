class_name PropertyManager
extends RefCounted

## Emitted when a property is activated
signal property_activated(property_path: Path)
signal property_selected(property_path: Path)

#region Constants
## Tree view column indices
const COL_NAME = 0
const COL_TYPE = 1
const COL_VALUE = 2
const COL_DEPENDENCIES = 3

## Column configuration
const COLUMN_WIDTHS := {
	"NAME": 200,
	"TYPE": 150,
	"VALUE": 250,
	"DEPENDENCIES": 200
}
#endregion

#region Member Variables
## Currently expanded tree item
var _expanded_item: TreeItem

## Reference to the properties tree
var properties_tree: Tree

## Reference to description label
var description_label: Label
#endregion

#region Initialization
func _init(tree: Tree, desc_label: Label) -> void:
	properties_tree = tree
	description_label = desc_label
	_configure_tree_columns()
	_setup_signals()

## Configure the tree columns with proper settings
func _configure_tree_columns() -> void:
	properties_tree.columns = 4
	
	_setup_column(COL_NAME, "Property", true, COLUMN_WIDTHS.NAME)
	_setup_column(COL_TYPE, "Type", false, COLUMN_WIDTHS.TYPE)
	_setup_column(COL_VALUE, "Value", true, COLUMN_WIDTHS.VALUE)
	_setup_column(COL_DEPENDENCIES, "Dependencies", true, COLUMN_WIDTHS.DEPENDENCIES)
	
	properties_tree.column_titles_visible = true

## Set up individual column properties
func _setup_column(index: int, title: String, expandable: bool, min_width: int) -> void:
	properties_tree.set_column_title(index, title)
	properties_tree.set_column_title_alignment(index, HORIZONTAL_ALIGNMENT_LEFT)
	properties_tree.set_column_clip_content(index, true)
	properties_tree.set_column_expand(index, expandable)
	properties_tree.set_column_custom_minimum_width(index, min_width)

## Connect necessary signals
func _setup_signals() -> void:
	properties_tree.item_selected.connect(_on_item_selected)
	properties_tree.nothing_selected.connect(_on_tree_deselected)
	properties_tree.item_activated.connect(_on_tree_item_activated)
	
	# Add double-click handling for values
	properties_tree.item_mouse_selected.connect(_on_item_mouse_selected)
#endregion

#region Property View Management
## Update the property view with new node data
func update_property_view(node: NestedProperty) -> void:
	properties_tree.clear()
	var root = properties_tree.create_item()
	properties_tree.hide_root = true
	
	if node.type == NestedProperty.Type.CONTAINER:
		_populate_container_contents(root, node)
	else:
		_populate_single_property(root, node)

	_update_description(node)

## Populate container contents in the tree
func _populate_container_contents(parent_item: TreeItem, container: NestedProperty) -> void:
	var properties: Array[NestedProperty] = []
	var containers: Array[NestedProperty] = []
	
	for child in container.children.values():
		if child.type == NestedProperty.Type.PROPERTY:
			properties.append(child)
		else:
			containers.append(child)
	
	properties.sort_custom(func(a, b): return a.name.naturalnocasecmp_to(b.name) < 0)
	containers.sort_custom(func(a, b): return a.name.naturalnocasecmp_to(b.name) < 0)
	
	# Add properties first
	for property in properties:
		var item = properties_tree.create_item(parent_item)
		item.set_text(COL_NAME, Helper.snake_to_readable(property.name))
		_populate_property_item(item, property)
		item.set_metadata(0, property)
	
	# Then add containers
	for sub_container in containers:
		var item = properties_tree.create_item(parent_item)
		item.set_text(COL_NAME, Helper.snake_to_readable(sub_container.name))
		_populate_container_item(item, sub_container)
		item.set_metadata(0, sub_container)

## Populate a container item in the tree
func _populate_container_item(item: TreeItem, container: NestedProperty) -> void:
	item.set_text(COL_TYPE, "Container")
	item.set_custom_bg_color(COL_TYPE, Color.html("#2c3e50"))
	item.set_text(COL_VALUE, "")
	item.set_selectable(COL_VALUE, false)
	
	var child_count = container.children.size()
	item.set_tooltip_text(COL_NAME, "Container with %d items" % child_count)
	item.set_custom_font_size(COL_NAME, 17)
	item.set_metadata(0, container)
	
	_set_dependencies_text(item, container.dependencies)

## Populate a property item in the tree
func _populate_property_item(item: TreeItem, property: NestedProperty) -> void:
	item.set_text(COL_TYPE, Property.type_to_string(property.value_type))
	
	var value = property.get_value()
	var value_text = Property.format_value(value)
	var wrapped_text = _wrap_text(value_text)
	
	item.set_text(COL_VALUE, _get_condensed_text(value_text))
	item.set_tooltip_text(COL_VALUE, value_text)
	item.set_metadata(1, wrapped_text)
	item.set_selectable(COL_VALUE, true)
	
	_set_dependencies_text(item, property.dependencies)
	
	if property.description:
		item.set_tooltip_text(COL_NAME, property.description)
	
	item.set_metadata(0, property)
	_style_property_item(item, property)

## Populate a single property in the tree
func _populate_single_property(parent_item: TreeItem, property: NestedProperty) -> void:
	if property.type != NestedProperty.Type.PROPERTY:
		return
	
	var item = properties_tree.create_item(parent_item)
	item.set_text(COL_NAME, Helper.snake_to_readable(property.name))
	_populate_property_item(item, property)
	item.set_collapsed(false)

## Set dependencies text for an item
func _set_dependencies_text(item: TreeItem, dependencies: Array) -> void:
	var str_array: Array[String] = []
	for dependency in dependencies:
		str_array.append(dependency.path.full)
	var dependencies_text = "None" if str_array.is_empty() else "\n".join(
		str_array.map(func(p): return p.full)
	)
	item.set_text(COL_DEPENDENCIES, dependencies_text)
	
	if not dependencies.is_empty():
		item.set_tooltip_text(COL_DEPENDENCIES, "Dependencies:\n" + dependencies_text)
#endregion

#region Signal Handling
## Handle item selection
func _on_item_selected() -> void:
	var selected = properties_tree.get_selected()
	if not selected:
		return
	
	var node = selected.get_metadata(0) as NestedProperty
	if not node:
		return
		
	# Update description
	_update_description(node)
	
	# Just emit standard selection
	property_selected.emit(node.path)

## Handle double-click/activation of tree items
func _on_tree_item_activated() -> void:
	var selected = properties_tree.get_selected()
	if not selected:
		return
		
	var node = selected.get_metadata(0) as NestedProperty
	if not node:
		return
		
	# Emit activation signal with the path
	property_activated.emit(node.path)

## Handle mouse selection (for value column expansion)
func _on_item_mouse_selected(position: Vector2, mouse_button_index: int) -> void:
	var selected = properties_tree.get_selected()
	if not selected:
		return
		
	# Get the clicked column
	var clicked_column = properties_tree.get_column_at_position(position)
	
	# If value column was clicked
	if clicked_column == COL_VALUE:
		_handle_value_cell_click(selected)

#endregion

#region Item Selected handling
## Handle clicking on a value cell
func _handle_value_cell_click(item: TreeItem) -> void:
	if item == _expanded_item:
		_collapse_expanded_cell()
	_expand_cell(item)

## Expand a cell to show full content
func _expand_cell(item: TreeItem) -> void:
	var full_text = item.get_metadata(1)
	item.set_text(COL_VALUE, full_text)
	_expanded_item = item

## Collapse the currently expanded cell
func _collapse_expanded_cell() -> void:
	if _expanded_item != null:
		var full_text = _expanded_item.get_metadata(1)
		_expanded_item.set_text(COL_VALUE, _get_condensed_text(full_text))
		_expanded_item = null

## Handle tree deselection
func _on_tree_deselected() -> void:
	_collapse_expanded_cell()
#endregion

#region Helper Functions
## Style a property item based on its type
func _style_property_item(item: TreeItem, property: NestedProperty) -> void:
	# Style based on property type
	match property.value_type:
		Property.Type.BOOL:
			item.set_custom_bg_color(COL_TYPE, Color.html("#27ae60"))
		Property.Type.INT, Property.Type.FLOAT:
			item.set_custom_bg_color(COL_TYPE, Color.html("#2980b9"))
		Property.Type.STRING:
			item.set_custom_bg_color(COL_TYPE, Color.html("#8e44ad"))
		Property.Type.VECTOR2, Property.Type.VECTOR3:
			item.set_custom_bg_color(COL_TYPE, Color.html("#c0392b"))
		Property.Type.ARRAY, Property.Type.DICTIONARY:
			item.set_custom_bg_color(COL_TYPE, Color.html("#d35400"))
		_:
			item.set_custom_bg_color(COL_TYPE, Color.html("#7f8c8d"))

	# Style if property has dependencies
	if not property.dependencies.is_empty():
		item.set_custom_color(COL_DEPENDENCIES, Color.html("#e74c3c"))

## Get condensed text for display
func _get_condensed_text(text: String, max_length: int = 50) -> String:
	if text.length() <= max_length:
		return text
	return text.substr(0, max_length - 3) + "..."

## Wrap text to fit within specified width
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

## Update description label with node information
func _update_description(node: NestedProperty) -> void:
	if node.type == NestedProperty.Type.PROPERTY:
		description_label.text = node.description if node.description else "No description available"
	else:
		description_label.text = "Container with %d items" % node.children.size()
#endregion
