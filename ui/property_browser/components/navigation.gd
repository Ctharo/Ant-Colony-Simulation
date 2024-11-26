class_name PropertyBrowserNavigation
extends RefCounted

#region Signals
signal path_changed(new_path: Path)
#endregion

var logger: Logger
#region Member Variables
## Navigation history
var _navigation_history: Array[Path] = [] :
	set(value):
		_navigation_history = value
		_back_button.disabled = _navigation_history.is_empty()

## Current path with automatic label update
var _current_path: Path = Path.new([]) :
	set = set_current_path,
	get = get_current_path

## Reference to UI components
var _back_button: Button
var _path_label: Label
var _root_label: Label
var _node_list: ItemList
var _properties_tree: Tree
var _property_access: PropertyAccess
#endregion

#region Initialization
func _init(components: Dictionary) -> void:
	logger = Logger.new("property_browser_navigation", DebugLogger.Category.UI)
	_back_button = components.back_button
	_path_label = components.path_label
	_root_label = components.root_label
	_node_list = components.node_list
	_properties_tree = components.properties_tree

func set_property_access(entity: Node) -> void:
	for property in entity.get_property_list():
		if property.name == "_property_access":
			_property_access = entity._property_access
	refresh_root_view()
#endregion

#region Navigation Methods
## Navigate back to previous path
func navigate_back() -> void:
	if _navigation_history.size() > 0:
		var from = _current_path
		var previous = _navigation_history.pop_back()
		set_current_path(previous)
		logger.trace("Navigating back from %s to %s" % [from.full, previous.full])

		# For any path (including root path nodes), select it in the root view
		if previous.parts.size() <= 1:  # Root or root node
			refresh_root_view()
			if not previous.is_root():  # Root node selected
				# Find and select the container in the node list
				for i in range(_node_list.item_count):
					if _node_list.get_item_text(i) == previous.full:
						_node_list.select(i)
						var node = _property_access.find_property_node(previous)
						if node:
							_update_property_tree(node)
						break
		else:
			refresh_view_for_path(previous)

		path_changed.emit(previous)
	else:
		refresh_root_view()

## Handles item selection (single click)
func handle_selection(path: Path) -> void:
	var node = _property_access.find_property_node(path)
	if not node:
		return

	if node.type == PropertyNode.Type.CONTAINER:
		_add_to_navigation_history(path)

	_update_property_tree(node)
	_path_label.text = path.full
	path_changed.emit(path)

## Main method for handling activation of properties or containers
func handle_activation(path: Path) -> void:
	var node = _property_access.find_property_node(path)
	if not node:
		return

	if node.type == PropertyNode.Type.CONTAINER:
		_handle_container_activation(path, node)
	else:
		_handle_value_activation(path)

	path_changed.emit(path)

## Handle activation of a container node
func _handle_container_activation(path: Path, node: PropertyNode) -> void:
	var previous_path = _current_path

	# Add any missing parent paths to history
	if not previous_path.is_root():
		var parent_path = path.get_parent()
		if parent_path and not parent_path.is_root() and (_navigation_history.is_empty() or _navigation_history.back() != parent_path):
			_add_to_navigation_history(parent_path)

	# Add current path to history before changing to new path
	_add_to_navigation_history(previous_path)

	# Update current path
	set_current_path(path)

	_update_container_view(node, path)
	_update_property_tree(node)

## Handle activation of a value node
func _handle_value_activation(path: Path) -> void:
	_path_label.text = path.full

## Add path to navigation history if valid
func _add_to_navigation_history(path: Path) -> void:
	# Skip if trying to add a duplicate of the last entry
	if not _navigation_history.is_empty() and _navigation_history.back() == path:
		return

	# Add path to history (excluding root except when explicitly added)
	if not path.is_root():
		_navigation_history.append(path)
		_back_button.disabled = false

#endregion

#region View Management
func refresh_root_view() -> void:
	if not _property_access:
		return

	_node_list.clear()
	_properties_tree.clear()
	set_current_path()
	_navigation_history.clear()
	_back_button.disabled = true

	# Get all root level property nodes
	var root_nodes = _property_access.get_root_names()
	for node_name in root_nodes:
		_node_list.add_item(node_name)
		var node = _property_access.find_property_node(Path.parse(node_name))
		if node and node.description:
			_node_list.set_item_tooltip(_node_list.item_count - 1, node.description)

	# Update labels for root view
	_path_label.text = ""
	_root_label.text = "Root View"

func refresh_view_for_path(path: Path) -> void:
	if not _property_access:
		return

	if path.is_root():
		refresh_root_view()
		return

	var node = _property_access.find_property_node(path)
	if node:
		_update_view_for_node(node, path)

func _update_view_for_node(node: PropertyNode, path: Path) -> void:
	_path_label.text = path.full
	_root_label.text = "Node: %s" % path.get_root_name()

	if node.type == PropertyNode.Type.CONTAINER:
		_update_container_view(node, path)
		_update_property_tree(node)
	else:
		_update_property_tree(node)

## Update node list to show only the current container
func _update_container_view(node: PropertyNode, path: Path) -> void:
	_node_list.clear()

	# Add only the current container to the list
	_node_list.add_item(path.full)
	if node.description:
		_node_list.set_item_tooltip(0, node.description)

func _update_property_tree(node: PropertyNode) -> void:
	_properties_tree.clear()
	var root = _properties_tree.create_item()
	_properties_tree.set_hide_root(true)

	if node.type == PropertyNode.Type.CONTAINER:
		_add_children_to_tree(root, node)
	else:
		# Single value node
		var item = _properties_tree.create_item(root)
		_setup_value_item(item, node)
#endregion

#region Path Management
func set_current_path(value: Path = Path.new([])) -> void:
	_current_path = value
	if _path_label:
		_path_label.text = value.full if value else "none"
	if _root_label and value:
		_root_label.text = "Node: %s" % value.get_root_name()

func get_current_path() -> Path:
	return _current_path
#endregion

#region Helper Methods
func _add_item_with_tooltip(path: Path, node: PropertyNode) -> void:
	var idx = _node_list.get_item_count() - 1
	if idx >= 0:
		var tooltip = ""
		if node.description:
			tooltip = node.description
		if node.type == PropertyNode.Type.VALUE:
			tooltip += "\nType: " + Property.type_to_string(node.value_type)
			tooltip += "\nValue: " + Property.format_value(node.get_value())

		if not tooltip.is_empty():
			_node_list.set_item_tooltip(idx, tooltip)

func _add_children_to_tree(parent_item: TreeItem, parent_node: PropertyNode) -> void:
	for child in parent_node.children.values():
		var item = _properties_tree.create_item(parent_item)
		item.set_text(0, child.name)
		item.set_metadata(0, child)

		if child.type == PropertyNode.Type.CONTAINER:
			# Container node styling
			item.set_text(1, "Container")
			item.set_custom_color(1, Color(0.7, 0.7, 1.0))  # Light blue for containers
			item.set_collapsed(true)  # Start collapsed
			# Add expand/collapse arrow
			#item.set_collapsed_icon(0, get_theme_icon("GuiTreeArrowRight", "EditorIcons"))
			#item.set_expanded_icon(0, get_theme_icon("GuiTreeArrowDown", "EditorIcons"))
			# Recursively add children
			_add_children_to_tree(item, child)
		else:
			# Value node styling
			_setup_value_item(item, child)



func _setup_value_item(item: TreeItem, node: PropertyNode) -> void:
	# Value node display
	item.set_text(1, Property.type_to_string(node.value_type))
	item.set_text(2, Property.format_value(node.get_value()))

	# Add tooltip with description if available
	if node.description:
		item.set_tooltip_text(0, node.description)

	# Style based on value type
	match node.value_type:
		Property.Type.FLOAT:
			item.set_custom_color(2, Color(0.2, 0.8, 0.2))  # Green for numbers
		Property.Type.INT:
			item.set_custom_color(2, Color(0.2, 0.7, 0.2))  # Darker green for integers
		Property.Type.BOOL:
			item.set_custom_color(2, Color(0.8, 0.4, 0.4))  # Red for booleans
		Property.Type.STRING:
			item.set_custom_color(2, Color(0.8, 0.8, 0.2))  # Yellow for strings
		Property.Type.VECTOR2:
			item.set_custom_color(2, Color(0.4, 0.4, 0.8))  # Blue for vectors
#endregion
