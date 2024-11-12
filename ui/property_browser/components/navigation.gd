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
#region Navigation Methods
func navigate_back() -> void:
	if _navigation_history.size() > 0:
		_current_path = _navigation_history.pop_back()
		refresh_view_for_path(_current_path)
		_back_button.disabled = _navigation_history.is_empty()
		path_changed.emit(_current_path)

## Handle selection of item in group list (not navigation)
func select_group(group_index: int) -> void:
	var group_text = _group_list.get_item_text(group_index)
	var path = Path.parse(group_text)
	
	# Update path label
	_path_label.text = path.full
	
	# Update property tree view
	var group = _ant.get_property_group(path.get_group_name())
	if group:
		var node = group.get_root() if path.is_group_root() else group.get_at_path(path.get_subpath())
		if node:
			_update_property_tree(node)

## Handle activation of a container (navigation)
func navigate_to_container(path: Path) -> void:
	# Update navigation state
	_navigation_history.append(_current_path)
	_current_path = path
	_back_button.disabled = false
	
	# Get the container node
	var group = _ant.get_property_group(path.get_group_name())
	if not group:
		return
		
	var node: NestedProperty
	if path.is_group_root():
		node = group.get_root()
	else:
		node = group.get_at_path(path.get_subpath())
	
	if node and node.type == NestedProperty.Type.CONTAINER:
		# Update group label
		_group_label.text = "Group: %s" % path.get_group_name()
		
		# Update group list with sibling containers
		_update_sibling_containers(node, path)
		
		# Update property tree with container contents
		_update_property_tree(node)
		
		# Update path label
		_path_label.text = path.full
		
		path_changed.emit(path)

## Handle activation of a property (no navigation)
func handle_property_activation(path: Path) -> void:
	# Only update path label
	_path_label.text = path.full

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
		# Add all container siblings
		for child in parent_node.children.values():
			if child.type == NestedProperty.Type.CONTAINER:
				var child_path = parent_path.append(child.name)
				_group_list.add_item(child_path.full)
				_add_item_with_tooltip(child_path, child)

#func navigate_to_group(group_index: int) -> void:
	#var group_text = _group_list.get_item_text(group_index)
	#
	## Create path from group text
	#var new_path: Path = Path.parse(group_text) if Path.is_path_format(group_text) else Path.new([group_text.to_lower()])
	#
	## Update labels
	#_path_label.text = new_path.full
	#_group_label.text = "Group: %s" % new_path.get_group_name()
	#
	## Get group and node
	#var group = _ant.get_property_group(new_path.get_group_name())
	#if not group:
		#return
		#
	#var node: NestedProperty
	#if new_path.is_group_root():
		#node = group.get_root()
	#else:
		#node = group.get_at_path(new_path.get_subpath())
	#
	#if node:
		#if node.type == NestedProperty.Type.CONTAINER:
			## Update navigation state only for containers
			#_navigation_history.append(_current_path)
			#_current_path = new_path
			#_back_button.disabled = false
			#_update_view_for_node(node, new_path)
		#else:
			## For properties, just update the property view
			#_update_property_tree(node)
			#
		#path_changed.emit(new_path)
#
#func navigate_to_path(path: Path) -> void:
	#var group = _ant.get_property_group(path.get_group_name())
	#if not group:
		#return
		#
	#var node: NestedProperty
	#if path.is_group_root():
		#node = group.get_root()
	#else:
		#node = group.get_at_path(path.get_subpath())
	#
	#if node:
		#if node.type == NestedProperty.Type.CONTAINER:
			## Container activation - update navigation and views
			#_navigation_history.append(_current_path)
			#_current_path = path
			#_back_button.disabled = false
			#_update_view_for_node(node, path)
		#
		## Always update labels
		#_path_label.text = path.full
		#_group_label.text = "Group: %s" % path.get_group_name()
		#
		#path_changed.emit(path)
#
	#
func get_current_path() -> Path:
	return _current_path
#endregion

#region View Management
func refresh_root_view() -> void:
	if not _ant:
		return
		
	_group_list.clear()
	_properties_tree.clear()
	_current_path = Path.new([])

	var groups = _ant.get_group_names()
	for group_name in groups:
		_group_list.add_item(group_name)
		var group = _ant.get_property_group(group_name)
		if group and group.description:
			_group_list.set_item_tooltip(_group_list.item_count - 1, group.description)
			
	# Update labels for root view
	_path_label.text = ""
	_group_label.text = "Group: root"

func refresh_view_for_path(path: Path) -> void:
	if not _ant:
		return
		
	if path.parts.is_empty():
		refresh_root_view()
		return

	var group = _ant.get_property_group(path.get_group_name())
	if not group:
		return

	# Get the node at the current path
	var node: NestedProperty
	if path.is_group_root():
		node = group.get_root()
	else:
		node = group.get_at_path(path.get_subpath())

	if node:
		_update_view_for_node(node, path)

func _update_view_for_node(node: NestedProperty, path: Path) -> void:
	if node.type == NestedProperty.Type.CONTAINER:
		# Clear and repopulate group list with siblings
		_group_list.clear()
		
		# Get parent to find siblings
		var parent_path = path.get_parent()
		if parent_path.is_root():
			# Root level - show all top groups
			var groups = _ant.get_group_names()
			for group_name in groups:
				_group_list.add_item(group_name)
		else:
			# Get parent's container children
			var group = _ant.get_property_group(parent_path.get_group_name())
			if not group:
				return
				
			var parent_node = group.get_root() if parent_path.is_group_root() else group.get_at_path(parent_path.get_subpath())
			
			if parent_node and parent_node.type == NestedProperty.Type.CONTAINER:
				# Add all container siblings
				for child in parent_node.children.values():
					if child.type == NestedProperty.Type.CONTAINER:
						var child_path = parent_path.append(child.name)
						_group_list.add_item(child_path.full)
						_add_item_with_tooltip(child_path, child)
				
		# Always update property tree with container's contents
		_update_property_tree(node)
	else:
		# For properties, just update the path label
		_path_label.text = path.full

	_group_label.text = "Group: %s" % path.get_group_name()
	
func _update_property_tree(node: NestedProperty) -> void:
	_properties_tree.clear()
	var root = _properties_tree.create_item()
	_properties_tree.set_hide_root(true)
	
	if node.type == NestedProperty.Type.CONTAINER:
		for child in node.children.values():
			var item = _properties_tree.create_item(root)
			item.set_text(0, child.name)
			if child.type == NestedProperty.Type.PROPERTY:
				item.set_text(1, Property.type_to_string(child.value_type))
				item.set_text(2, Property.format_value(child.get_value()))
	else:
		var item = _properties_tree.create_item(root)
		item.set_text(0, node.name)
		if node.type == NestedProperty.Type.PROPERTY:
			item.set_text(1, Property.type_to_string(node.value_type))
			item.set_text(2, Property.format_value(node.get_value()))
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
	# Only add tooltip if we haven't already added this path
	if _group_list.get_item_text(_group_list.get_item_count() - 1) != path.full:
		var tooltip = ""
		if node.description:
			tooltip = node.description
		if node.type == NestedProperty.Type.PROPERTY:
			tooltip += "\nType: " + Property.type_to_string(node.value_type)
			tooltip += "\nValue: " + Property.format_value(node.get_value())
		
		if not tooltip.is_empty():
			var idx = _group_list.get_item_count() - 1
			_group_list.set_item_tooltip(idx, tooltip)
#endregion
