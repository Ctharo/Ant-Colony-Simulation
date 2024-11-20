class_name PropertyBrowserNavigation
extends BaseRefCounted

#region Signals
signal path_changed(new_path: Path)
#endregion

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
var _ant: Ant
#endregion

#region Initialization
func _init(components: Dictionary) -> void:
	log_category = DebugLogger.Category.UI
	log_from = "property_browser_navigation"
	_back_button = components.back_button
	_path_label = components.path_label
	_root_label = components.root_label
	_node_list = components.node_list
	_properties_tree = components.properties_tree

func set_ant(ant: Ant) -> void:
	_ant = ant
	refresh_root_view()
#endregion

#region Navigation Methods
func navigate_back() -> void:
	if _navigation_history.size() > 0:
		var from = _current_path
		set_current_path(_navigation_history.pop_back())
		_trace("Navigating from %s to %s" % [from.full, _current_path.full])
		refresh_view_for_path(_current_path)
		path_changed.emit(_current_path)

## Handles item selection (single click)
func handle_selection(path: Path) -> void:
	var node = _ant.find_property_node(path)
	if not node:
		return

	_update_property_tree(node)
	_path_label.text = path.full
	path_changed.emit(path)

## Main method for handling activation of properties or containers
func handle_activation(path: Path) -> void:
	var node = _ant.find_property_node(path)
	if not node:
		return

	if node.type == PropertyNode.Type.CONTAINER:
		# First navigation from root
		if _navigation_history.is_empty() and _current_path.is_root():
			_navigation_history.append(_current_path)

		# Check if we're navigating between siblings
		var is_sibling_navigation = false
		if not _current_path.is_root():
			var parent_current = _current_path.get_parent()
			var parent_new = path.get_parent()

			# If both have same parent, we're navigating between siblings
			if parent_current and parent_new and parent_current.full == parent_new.full:
				is_sibling_navigation = true

		# If going between siblings, don't modify history
		if not is_sibling_navigation:
			_navigation_history.append(_current_path)

		set_current_path(path)

		# Update UI
		_update_sibling_containers(node, path)
		_update_property_tree(node)
	else:
		# Value node activation - just update path label
		_path_label.text = path.full

	path_changed.emit(path)

## Handle selection in root list
func select_node(node_index: int) -> void:
	var node_text = _node_list.get_item_text(node_index)
	_trace("Node %s selected" % node_text)
	var path = Path.parse(node_text)
	handle_selection(path)

## Handle activation in node list
func activate_node(node_index: int) -> void:
	var node_text = _node_list.get_item_text(node_index)
	_trace("Node %s activated" % node_text)
	var path = Path.parse(node_text)
	handle_activation(path)

## Update [member _node_list] with sibling containers
func _update_sibling_containers(node: PropertyNode, path: Path) -> void:
	_node_list.clear()

	var parent_path = path.get_parent()
	if parent_path == null or parent_path.parts.is_empty():
		# Root level - show all root containers
		var roots = _ant.get_root_names()
		for root_name in roots:
			_node_list.add_item(root_name)
		return

	# Get parent container
	var parent_node = _ant.find_property_node(parent_path)
	if not parent_node or parent_node.type != PropertyNode.Type.CONTAINER:
		return

	# Add all container siblings including current container
	for child in parent_node.children.values():
		if child.type == PropertyNode.Type.CONTAINER:
			var child_path = parent_path.append(child.name)
			_node_list.add_item(child_path.full)
			_add_item_with_tooltip(child_path, child)
#endregion

#region Path Management
func set_current_path(value: Path = Path.new([])) -> void:
	_current_path = value
	if _path_label:
		_path_label.text = value.full if value else "none"
	if _root_label and value:
		_root_label.text = "Root: %s" % value.get_root_name()

func get_current_path() -> Path:
	return _current_path
#endregion

#region View Management
func refresh_root_view() -> void:
	if not _ant:
		return

	_node_list.clear()
	_properties_tree.clear()
	set_current_path()
	_navigation_history.clear()

	# Get all root level property nodes
	var root_nodes = _ant.get_root_names()
	for node_name in root_nodes:
		_node_list.add_item(node_name)
		var node = _ant.find_property_node(Path.parse(node_name))
		if node and node.description:
			_node_list.set_item_tooltip(_node_list.item_count - 1, node.description)

	# Update labels for root view
	_path_label.text = ""
	_root_label.text = "Root View"

func refresh_view_for_path(path: Path) -> void:
	if not _ant:
		return

	if path.parts.is_empty():
		refresh_root_view()
		return

	var node = _ant.find_property_node(path)
	if node:
		_update_view_for_node(node, path)

func _update_view_for_node(node: PropertyNode, path: Path) -> void:
	_path_label.text = path.full
	_root_label.text = "Root: %s" % path.get_root_name()

	if node.type == PropertyNode.Type.CONTAINER:
		_update_sibling_containers(node, path)
		_update_property_tree(node)
	else:
		_update_property_tree(node)

func _update_property_tree(node: PropertyNode) -> void:
	_properties_tree.clear()
	var root = _properties_tree.create_item()
	_properties_tree.set_hide_root(true)

	if node.type == PropertyNode.Type.CONTAINER:
		for child in node.children.values():
			var item = _properties_tree.create_item(root)
			item.set_text(0, child.name)
			item.set_metadata(0, child)
			if child.type == PropertyNode.Type.VALUE:
				item.set_text(1, Property.type_to_string(child.value_type))
				item.set_text(2, Property.format_value(child.get_value()))
			else:
				item.set_text(1, "Container")
#endregion

#region Search and Filter
func filter_nodes(search_text: String) -> void:
	_node_list.clear()

	if search_text.is_empty():
		refresh_root_view()
		return

	var search_path = Path.parse(search_text)

	if search_text.ends_with("."):
		var parent_path = search_path.get_parent()
		_show_children_at_path(parent_path if parent_path else Path.new([]))
		return

	var parent_path = search_path.get_parent()
	var filter = search_path.get_property().to_lower()
	_show_filtered_children(parent_path if parent_path else Path.new([]), filter)

func _show_children_at_path(path: Path) -> void:
	if not _ant or path.parts.is_empty():
		refresh_root_view()
		return

	var node = _ant.find_property_node(path)
	if not node or node.type != PropertyNode.Type.CONTAINER:
		return

	for child in node.children.values():
		var child_path = path.append(child.name)
		_add_item_with_tooltip(child_path, child)

func _show_filtered_children(parent_path: Path, filter: String) -> void:
	if not _ant:
		return

	if parent_path.parts.is_empty():
		var roots = _ant.get_root_names()
		for root_name in roots:
			if root_name.to_lower().contains(filter):
				_node_list.add_item(root_name)
		return

	var parent_node = _ant.find_property_node(parent_path)
	if not parent_node or parent_node.type != PropertyNode.Type.CONTAINER:
		return

	for child in parent_node.children.values():
		if child.name.to_lower().contains(filter):
			var child_path = parent_path.append(child.name)
			_add_item_with_tooltip(child_path, child)
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
#endregion
