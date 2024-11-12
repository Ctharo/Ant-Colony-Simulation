class_name PropertyBrowserNavigation
extends RefCounted

#region Signals
signal path_changed(new_path: Path)
#endregion

#region Member Variables
## Navigation history
var _navigation_history: Array[Path] = []
var _current_path: Path = Path.new([])

## Reference to UI components
var _back_button: Button
var _path_label: Label
var _group_label: Label
var _group_list: ItemList
var _properties_tree: Tree
var _ant: Ant
#endregion

#region Initialization
func _init(components: Dictionary) -> void:
	_back_button = components.back_button
	_path_label = components.path_label
	_group_label = components.group_label
	_group_list = components.group_list
	_properties_tree = components.properties_tree
	
	# Initialize UI state
	_back_button.disabled = true
	_path_label.text = "none"
	_group_label.text = "Property Groups"

func set_ant(ant: Ant) -> void:
	_ant = ant
	refresh_root_view()
#endregion

#region Navigation Methods
func navigate_back() -> void:
	if _navigation_history.size() > 0:
		_current_path = _navigation_history.pop_back()
		refresh_view_for_path(_current_path)
		_back_button.disabled = _navigation_history.is_empty()
		path_changed.emit(_current_path)


## Handles item selection (single click)
func handle_selection(path: Path) -> void:
	var group = _ant.get_property_group(path.get_group_name())
	if not group:
		return
		
	var node: NestedProperty
	if path.is_group_root():
		node = group.get_root()
	else:
		node = group.get_at_path(path.get_subpath())
	
	if not node:
		return
		
	# Update property tree to show children without changing navigation level
	_update_property_tree(node)
	_path_label.text = path.full
	path_changed.emit(path)

## Handles item activation (double click)
func handle_activation(path: Path) -> void:
	var group = _ant.get_property_group(path.get_group_name())
	if not group:
		return
		
	var node: NestedProperty
	if path.is_group_root():
		node = group.get_root()
	else:
		node = group.get_at_path(path.get_subpath())
	
	if not node:
		return
		
	if node.type == NestedProperty.Type.CONTAINER:
		# Add current path to history unless we're at root
		if not _current_path.is_root():
			_navigation_history.append(_current_path)
		
		_current_path = path
		_back_button.disabled = _navigation_history.is_empty()
		
		# Update UI for new container level
		_group_label.text = "Group: %s" % path.get_group_name()
		_update_sibling_containers(node, path)
		_update_property_tree(node)
		_path_label.text = path.full
		path_changed.emit(path)
	
## Handle selection in group list
## Handle selection in group list
func select_group(group_index: int) -> void:
	var group_text = _group_list.get_item_text(group_index)
	var path = Path.parse(group_text)
	handle_selection(path)

## Handle activation in group list
func activate_group(group_index: int) -> void:
	var group_text = _group_list.get_item_text(group_index)
	var path = Path.parse(group_text)
	handle_activation(path)
func _update_sibling_containers(node: NestedProperty, path: Path) -> void:
	_group_list.clear()
	
	var parent_path = path.get_parent()
	if parent_path == null or parent_path.parts.is_empty():
		# Root level - show all root groups
		var groups = _ant.get_group_names()
		for group_name in groups:
			_group_list.add_item(group_name)
		return
		
	# Get parent's container children
	var group = _ant.get_property_group(parent_path.get_group_name())
	if not group:
		return
		
	var parent_node: NestedProperty
	if parent_path.is_group_root():
		parent_node = group.get_root()
	else:
		parent_node = group.get_at_path(parent_path.get_subpath())
		
	if parent_node and parent_node.type == NestedProperty.Type.CONTAINER:
		# Add all container siblings including current container
		for child in parent_node.children.values():
			if child.type == NestedProperty.Type.CONTAINER:
				var child_path = parent_path.append(child.name)
				_group_list.add_item(child_path.full)
				_add_item_with_tooltip(child_path, child)

func get_current_path() -> Path:
	return _current_path
#endregion

#region View Management
#region View Management
func refresh_root_view() -> void:
	if not _ant:
		return
		
	_group_list.clear()
	_properties_tree.clear()
	_current_path = Path.new([])
	_navigation_history.clear()

	var groups = _ant.get_group_names()
	for group_name in groups:
		_group_list.add_item(group_name)
		var group = _ant.get_property_group(group_name)
		if group and group.description:
			_group_list.set_item_tooltip(_group_list.item_count - 1, group.description)
			
	# Update labels for root view
	_path_label.text = ""
	_group_label.text = "Group: root"
	_back_button.disabled = true

func refresh_view_for_path(path: Path) -> void:
	if not _ant:
		return
		
	if path.parts.is_empty():
		refresh_root_view()
		return

	var group = _ant.get_property_group(path.get_group_name())
	if not group:
		return

	var node: NestedProperty
	if path.is_group_root():
		node = group.get_root()
	else:
		node = group.get_at_path(path.get_subpath())

	if node:
		_update_view_for_node(node, path)
		
func _update_view_for_node(node: NestedProperty, path: Path) -> void:
	_path_label.text = path.full
	_group_label.text = "Group: %s" % path.get_group_name()
	
	if node.type == NestedProperty.Type.CONTAINER:
		# Update both group list and property tree
		_update_sibling_containers(node, path)
		_update_property_tree(node)
	else:
		# For properties, just update property tree
		_update_property_tree(node)

func _update_property_tree(node: NestedProperty) -> void:
	_properties_tree.clear()
	var root = _properties_tree.create_item()
	_properties_tree.set_hide_root(true)
	
	if node.type == NestedProperty.Type.CONTAINER:
		for child in node.children.values():
			var item = _properties_tree.create_item(root)
			item.set_text(0, child.name)
			item.set_metadata(0, child)  # Store node reference for handling clicks
			if child.type == NestedProperty.Type.PROPERTY:
				item.set_text(1, Property.type_to_string(child.value_type))
				item.set_text(2, Property.format_value(child.get_value()))
			else:  # Container
				item.set_text(1, "Group")
#endregion

#region Search and Filter
func filter_groups(search_text: String) -> void:
	_group_list.clear()

	if search_text.is_empty():
		refresh_root_view()
		return

	# Handle dot notation search
	var search_path = Path.parse(search_text)

	# If ends with dot, show all children at that path
	if search_text.ends_with("."):
		var parent_path = search_path.get_parent()
		_show_children_at_path(parent_path if parent_path else Path.new([]))
		return

	# Otherwise filter children
	var parent_path = search_path.get_parent()
	var filter = search_path.get_property().to_lower()
	_show_filtered_children(parent_path if parent_path else Path.new([]), filter)

## Updates the path and optionally group labels
## @param path: The current path to display
## @param update_group: Whether to update the group label as well
func _set_path_labels(path: Path, update_group: bool) -> void:
	# Set path label
	_path_label.text = path.full
	
	# Update group label only if requested
	if update_group:
		_group_label.text = "Group: %s" % (path.full)

func _show_children_at_path(path: Path) -> void:
	if not _ant or path.parts.is_empty():
		refresh_root_view()
		return

	var group = _ant.get_property_group(path.get_group_name())
	if not group:
		return

	var node: NestedProperty
	if path.is_group_root():
		node = group.get_root()
	else:
		node = group.get_at_path(path.get_subpath())

	if not node or node.type != NestedProperty.Type.CONTAINER:
		return

	for child in node.children.values():
		var child_path = path.append(child.name)
		_add_item_with_tooltip(child_path, child)

func _show_filtered_children(parent_path: Path, filter: String) -> void:
	if not _ant:
		return
		
	if parent_path.parts.is_empty():
		var groups = _ant.get_group_names()
		for group_name in groups:
			if group_name.to_lower().contains(filter):
				_group_list.add_item(group_name)
		return

	var group = _ant.get_property_group(parent_path.get_group_name())
	if not group:
		return

	var node: NestedProperty
	if parent_path.is_group_root():
		node = group.get_root()
	else:
		node = group.get_at_path(parent_path.get_subpath())

	if not node or node.type != NestedProperty.Type.CONTAINER:
		return

	for child in node.children.values():
		if child.name.to_lower().contains(filter):
			var child_path = parent_path.append(child.name)
			_add_item_with_tooltip(child_path, child)
#endregion

#region Helper Methods
func _add_item_with_tooltip(path: Path, node: NestedProperty) -> void:
	var idx = _group_list.get_item_count() - 1
	if idx >= 0:
		var tooltip = ""
		if node.description:
			tooltip = node.description
		if node.type == NestedProperty.Type.PROPERTY:
			tooltip += "\nType: " + Property.type_to_string(node.value_type)
			tooltip += "\nValue: " + Property.format_value(node.get_value())
		
		if not tooltip.is_empty():
			_group_list.set_item_tooltip(idx, tooltip)
#endregion
