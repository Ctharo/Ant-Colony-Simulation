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

#region Components
var ui_builder: PropertyBrowserUIBuilder
#endregion

#region Configuration constants
const WINDOW_SIZE_PERCENTAGE := 0.8
const TREE_COLUMNS := {
	"NAME": 0,
	"TYPE": 1,
	"VALUE": 2,
	"DEPENDENCIES": 3
}

# Column configuration
const COLUMN_WIDTHS := {
	"NAME": 200,
	"TYPE": 150,
	"VALUE": 250,
	"DEPENDENCIES": 200
}
#endregion
#region Member Variables
## Navigation history
var _navigation_history: Array[Path] = []
var _current_path: Path = Path.new([])

## Number of food items to simulate
var foods_to_spawn: int = randi_range(1500, 5000)

## Number of ants to simulate
var ants_to_spawn: int = randi_range(100, 500)

## Number of pheromones to simulate
var pheromones_to_spawn: int = randi_range(500, 5000)

## Tree view value column width
var _original_value_width: int = 250

## Currently expanded tree item
var _expanded_item: TreeItem

## Reference to current Ant instance
var current_ant: Ant

## Current browsing mode (Direct/Group)
var current_mode: String = "Direct"

## Currently selected property group
var current_group: String
#endregion

#region UI Properties
## Mode selection dropdown
var mode_switch: OptionButton

## List of available property groups
var group_list: ItemList

## Tree view showing property details
var properties_tree: Tree

## Label showing selected property path
var path_label: Label

## Label showing current group name
var group_label: Label

## Label showing property description
var description_label: Label

## Back button for navigation
var back_button: Button

## Label for content loading information
var loading_label: Label
#endregion


#region Initialization
func _ready() -> void:
	_configure_window()
	_initialize_ui_builder()
	#create_components()
	_setup_signals()
	DebugLogger.set_log_level(DebugLogger.LogLevel.TRACE)

## Handle input events
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # Escape key
		_on_close_pressed()
		get_viewport().set_input_as_handled()

## Initializes the UI builder with necessary references
func _initialize_ui_builder() -> void:
	ui_builder = PropertyBrowserUIBuilder.new()

	# Connect signals
	#ui_builder.ui_created.connect(_on_ui_created)
	ui_builder.close_requested.connect(_on_close_pressed)

	# Create UI and get references
	var refs = ui_builder.create_ui(self)

	# Assign references
	properties_tree = refs.properties_tree
	group_list = refs.group_list
	mode_switch = refs.mode_switch
	path_label = refs.path_label
	group_label = refs.group_label
	description_label = refs.description_label
	back_button = refs.back_button
	loading_label = refs.loading_label

	_on_ui_created()

## Configures the window properties
func _configure_window() -> void:
	title = "Ant Property Browser"
	visibility_changed.connect(func(): visible = true)

	# Set window properties
	exclusive = true
	unresizable = false
	min_size = Vector2(800, 500)

	# Calculate and set window size based on screen size
	var screen_size := DisplayServer.screen_get_size()
	size = screen_size * WINDOW_SIZE_PERCENTAGE
	position = (screen_size - size) / 2

## Handles UI created signal from UI builder
func _on_ui_created() -> void:
	# Configure tree columns
	_configure_tree_columns()

	# Set up all signal connections
	_setup_signals()

	# Initialize debug logging
	_setup_logging()

	# Load initial data
	_load_initial_data()

	# Update UI state
	_update_ui_state()

## Configures the property tree columns
func _configure_tree_columns() -> void:
	properties_tree.columns = TREE_COLUMNS.size()

	# Set up each column
	_setup_column(TREE_COLUMNS.NAME, "Property", true, COLUMN_WIDTHS.NAME)
	_setup_column(TREE_COLUMNS.TYPE, "Type", false, COLUMN_WIDTHS.TYPE)
	_setup_column(TREE_COLUMNS.VALUE, "Value", true, COLUMN_WIDTHS.VALUE)
	_setup_column(TREE_COLUMNS.DEPENDENCIES, "Dependencies", true, COLUMN_WIDTHS.DEPENDENCIES)

	properties_tree.column_titles_visible = true

## Sets up an individual tree column
func _setup_column(index: int, title: String, expandable: bool, min_width: int) -> void:
	properties_tree.set_column_title(index, title)
	properties_tree.set_column_title_alignment(index, HORIZONTAL_ALIGNMENT_LEFT)
	properties_tree.set_column_clip_content(index, true)
	properties_tree.set_column_expand(index, expandable)
	properties_tree.set_column_custom_minimum_width(index, min_width)

## Sets up all signal connections
func _setup_signals() -> void:
	# Tree signals
	properties_tree.item_mouse_selected.connect(_on_item_selected)
	properties_tree.nothing_selected.connect(_on_tree_deselected)
	properties_tree.item_activated.connect(_on_tree_item_activated)

	# Group list signals
	group_list.item_selected.connect(_on_group_selected)
	group_list.item_activated.connect(_on_group_activated)

	# Navigation signals
	back_button.pressed.connect(_on_back_pressed)

## Sets up debug logging
func _setup_logging() -> void:
	DebugLogger.set_log_level(DebugLogger.LogLevel.TRACE)
	_trace("PropertyBrowser UI initialization complete")

## Loads initial data
func _load_initial_data() -> void:
	if current_ant:
		_refresh_view()
	else:
		_warn("No ant set for Property Browser initialization")

## Updates initial UI state
func _update_ui_state() -> void:
	# Disable back button initially
	back_button.disabled = true

	# Clear and set up initial labels
	path_label.text = "none"
	description_label.text = "Select a property to view its description"

	# Set initial group label
	group_label.text = "Property Groups"

## Handles double-click on tree item
func _on_tree_item_activated() -> void:
	var selected = properties_tree.get_selected()
	if not selected:
		return

	var node = selected.get_metadata(0) as NestedProperty
	if not node:
		return

	var path = node.get_path()
	_navigation_history.append(_current_path)
	_current_path = path
	_update_view_for_node(node, path)
	back_button.disabled = false

## Update view for a specific node
func _update_view_for_node(node: NestedProperty, path: Path) -> void:
	# Update group list to show current path
	group_list.clear()
	group_list.add_item(path.to_string())
	_add_item_with_tooltip(path, node)

	# Update property tree
	properties_tree.clear()
	var root = properties_tree.create_item()
	properties_tree.hide_root = true

	if node.type == NestedProperty.Type.CONTAINER:
		_populate_container_contents(root, node)
	else:
		_populate_single_property(root, node)

	# Update UI state
	group_label.text = "Path: %s" % path.to_string().capitalize()

## Filter groups
func _filter_groups(search_text: String) -> void:
	group_list.clear()

	if search_text.is_empty():
		_refresh_root_view()
		return

	# Handle dot notation search
	var path_parts = search_text.split(".")

	# If ends with dot, show all children at that path
	if search_text.ends_with("."):
		var parent_path = Path.new(path_parts.slice(0, -1))
		_show_children_at_path(parent_path)
		return

	# Otherwise filter children
	var parent_path = Path.new(path_parts.slice(0, -1))
	var filter = path_parts[-1].to_lower()
	_show_filtered_children(parent_path, filter)

## Shows properties for a given Ant instance
func show_ant(ant: Ant) -> void:
	current_ant = ant
	_refresh_view()
#endregion

## Creates test components for demonstration
func create_components() -> void:

	ui_builder.show_loading_indicator(self)

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
		"food": foods_to_spawn,
		"pheromones": pheromones_to_spawn,
		"ants": ants_to_spawn
	}
	_staged_creation(to_create, a)
	show_ant(a)

#region Tree Management

## Populates a tree item with property data
func _populate_tree_item(item: TreeItem, property: Variant) -> void:
	if not property:
		return

	if property is Property:
		_populate_regular_property(item, property)
	elif property is NestedProperty:
		_populate_nested_property(item, property)

#region Navigation Methods
func _on_back_pressed() -> void:
	if _navigation_history.size() > 0:
		_current_path = _navigation_history.pop_back()
		_refresh_view_for_path(_current_path)
		back_button.disabled = _navigation_history.is_empty()

func _on_group_activated(index: int) -> void:
	var path_string = group_list.get_item_text(index).to_lower()
	var new_path = Path.parse(path_string)
	_navigation_history.append(_current_path)
	_current_path = new_path
	_refresh_view_for_path(_current_path)
	back_button.disabled = false

## Refresh root view
func _refresh_root_view() -> void:
	group_list.clear()
	properties_tree.clear()

	var groups = current_ant.get_group_names()
	for group_name in groups:
		group_list.add_item(group_name.capitalize())
		var group = current_ant.get_property_group(group_name)
		if group and group.description:
			group_list.set_item_tooltip(group_list.item_count - 1, group.description)

func _refresh_view_for_path(path: Path) -> void:
	if path.parts.is_empty():
		_refresh_root_view()
		return

	var group = current_ant.get_property_group(path.parts[0])
	if not group:
		return

	var node = group.get_root()
	if path.parts.size() > 1:
		node = group.get_at_path(Path.new(path.parts.slice(1)))

	if node:
		_update_view_for_node(node, path)

## Recursively finds paths matching the search pattern
func _find_matching_paths(container: NestedProperty, search_parts: Array, current_path: String, matched_paths: Array) -> void:
	if search_parts.is_empty():
		if not current_path.is_empty():
			matched_paths.append(current_path)
		return

	var current_search = search_parts[0].to_lower()
	var remaining_parts = search_parts.slice(1)
	var current_full_path = current_path + ("." if not current_path.is_empty() else "") + container.name

	# Check if this container matches the current search part
	if container.name.to_lower().contains(current_search):
		if remaining_parts.is_empty():
			matched_paths.append(current_full_path)
		else:
			# Continue searching in children
			for child in container.children.values():
				_find_matching_paths(child, remaining_parts, current_full_path, matched_paths)

	# Also search children for matches to the current search part
	for child in container.children.values():
		_find_matching_paths(child, search_parts, current_path, matched_paths)

func _show_children_at_path(path: Path) -> void:
	if path.parts.is_empty():
		_refresh_root_view()
		return

	var group = current_ant.get_property_group(path.parts[0])
	if not group:
		return

	var node = group.get_root()
	if path.parts.size() > 1:
		node = group.get_at_path(Path.new(path.parts.slice(1)))

	if not node or node.type != NestedProperty.Type.CONTAINER:
		return

	for child in node.children.values():
		var child_path = Path.new(path.parts + [child.name])
		_add_item_with_tooltip(child_path, child)

func _show_filtered_children(parent_path: Path, filter: String) -> void:
	if parent_path.parts.is_empty():
		var groups = current_ant.get_group_names()
		for group_name in groups:
			if group_name.to_lower().contains(filter):
				group_list.add_item(group_name.capitalize())
		return

	var group = current_ant.get_property_group(parent_path.parts[0])
	if not group:
		return

	var node = group.get_root()
	if parent_path.parts.size() > 1:
		node = group.get_at_path(Path.new(parent_path.parts.slice(1)))

	if not node or node.type != NestedProperty.Type.CONTAINER:
		return

	for child in node.children.values():
		if child.name.to_lower().contains(filter):
			var child_path = Path.new(parent_path.parts + [child.name])
			_add_item_with_tooltip(child_path, child)

## Add item with tooltip to group list
func _add_item_with_tooltip(path: Path, node: NestedProperty) -> void:
	group_list.add_item(path.to_string())
	var last_idx = group_list.item_count - 1

	var tooltip = ""
	if node.description:
		tooltip = node.description
	if node.type == NestedProperty.Type.PROPERTY:
		tooltip += "\nType: " + Property.type_to_string(node.value_type)
		tooltip += "\nValue: " + Property.format_value(node.get_value())
	if not tooltip.is_empty():
		group_list.set_item_tooltip(last_idx, tooltip)

## Adds matching nested properties to the group list based on search path
func _add_matching_nested_properties(container: NestedProperty, path_parts: Array, full_path: String, base_path: String) -> void:
	# If we've processed all path parts, add this path to the list
	if path_parts.is_empty():
		group_list.add_item(base_path)
		var tooltip = ""
		var prop = container.get_child_by_string_path(base_path)
		if prop:
			if prop.description:
				tooltip = prop.description
			if prop.type == NestedProperty.Type.PROPERTY:
				tooltip += "\nType: " + Property.type_to_string(prop.value_type)
				tooltip += "\nValue: " + Property.format_value(prop.get_value())
		if not tooltip.is_empty():
			group_list.set_item_tooltip(group_list.item_count - 1, tooltip)
		return

	var current_part = path_parts[0].to_lower()
	var remaining_parts = path_parts.slice(1)

	# Get all child names at this level
	var child_names = container.get_child_names_at_path("")

	for child_name in child_names:
		if child_name.to_lower().contains(current_part):
			var new_base_path = base_path + "." + child_name
			var child = container.get_child_by_string_path(child_name)

			if child:
				if child.type == NestedProperty.Type.CONTAINER:
					# For containers, continue searching deeper if there are more path parts
					_add_matching_nested_properties(child, remaining_parts, full_path, new_base_path)
				elif remaining_parts.is_empty():
					# For properties, only add them if we're at the last path part
					group_list.add_item(new_base_path)

					# Add tooltip with property information
					var tooltip = ""
					if child.description:
						tooltip = child.description
					tooltip += "\nType: " + Property.type_to_string(child.value_type)
					tooltip += "\nValue: " + Property.format_value(child.get_value())
					group_list.set_item_tooltip(group_list.item_count - 1, tooltip)

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
	var dependencies_text = "None" if property.dependencies.is_empty() else "\n".join(property.dependenciese)
	item.set_text(COL_DEPENDENCIES, dependencies_text)
	if not property.dependencies.is_empty():
		item.set_tooltip_text(COL_DEPENDENCIES, "Dependencies:\n" + dependencies_text)
	item.set_metadata(0, property)

#region Tree Management
## Populates the tree with nested property data
func _populate_nested_property(item: TreeItem, property: NestedProperty) -> void:
	item.set_text(COL_NAME, Helper.snake_to_readable(property.name))

	if property.type == NestedProperty.Type.CONTAINER:
		item.set_text(COL_TYPE, "Container")
		item.set_text(COL_VALUE, "")
		item.set_selectable(COL_VALUE, false)

		# Add children recursively
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

	var dependencies_text = "None" if property.dependencies.is_empty() else "\n".join(
		property.dependencies.map(func(p): return p.to_string())
	)
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


## Handles property group selection
func _on_group_selected(index: int) -> void:
	var group_name = group_list.get_item_text(index).to_lower()
	_trace("Group selected: %s" % group_name)

	# Update current group
	current_group = group_name

	# Get the property group
	var group = current_ant.get_property_group(group_name)
	if not group:
		_error("Failed to get property group: %s" % group_name)
		return

	# Update UI
	group_label.text = "Property Group: %s" % group_name.capitalize()
	description_label.text = group.description if group.description else "No description available"

	# Clear and repopulate properties tree
	properties_tree.clear()
	var root = properties_tree.create_item()
	properties_tree.hide_root = true

	# Get the root property container
	var root_container = group.get_root()
	if not root_container:
		_error("Failed to get root container for group: %s" % group_name)
		return

	# Populate tree with nested properties
	_populate_group_properties(root, root_container)

	# Update path label
	path_label.text = group_name

	_trace("Populated properties for group: %s" % group_name)

## Handle group item hover
func _on_group_hovered(index: int, at_position: Vector2) -> void:
	var group_name = group_list.get_item_text(index).to_lower()
	var group = current_ant.get_property_group(group_name)

	if group:
		# Update info about number of properties
		var property_count = group.get_properties().size()
		description_label.text = "Group contains %d properties" % property_count

## Handles property selection
func _on_property_selected() -> void:
	var selected = properties_tree.get_selected()
	if not selected:
		_warn("No valid property selected")
		return

	var property = selected.get_metadata(0)
	if not property or not property is NestedProperty:
		_warn("No valid nested property found for selection")
		return

	if property.type == NestedProperty.Type.PROPERTY:
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
	_refresh_groups()
	path_label.text = "none"

## Refreshes the property groups list
func _refresh_groups() -> void:
	_trace("Refreshing property groups list")
	group_list.clear()
	properties_tree.clear()

	var groups = current_ant.get_group_names()
	for group_name in groups:
		group_list.add_item(group_name.capitalize())

## Populate tree with container contents, prioritizing properties over sub-containers
func _populate_container_contents(parent_item: TreeItem, container: NestedProperty) -> void:
	# Create arrays for sorting properties and containers separately
	var properties: Array[NestedProperty] = []
	var containers: Array[NestedProperty] = []

	# Categorize children
	for child in container.children.values():
		if child.type == NestedProperty.Type.PROPERTY:
			properties.append(child)
		else:
			containers.append(child)

	# Sort properties alphabetically
	properties.sort_custom(func(a: NestedProperty, b: NestedProperty) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0)

	# Sort containers alphabetically
	containers.sort_custom(func(a: NestedProperty, b: NestedProperty) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0)

	# Add properties first (leaves)
	for property in properties:
		var item = properties_tree.create_item(parent_item)
		item.set_text(COL_NAME, Helper.snake_to_readable(property.name))
		_populate_property_item(item, property)
		item.set_metadata(0, property)

	# Then add containers (branches)
	for sub_container in containers:
		var item = properties_tree.create_item(parent_item)
		item.set_text(COL_NAME, Helper.snake_to_readable(sub_container.name))
		_populate_container_item(item, sub_container)
		item.set_metadata(0, sub_container)

## Populates a tree item with container data
func _populate_container_item(item: TreeItem, container: NestedProperty) -> void:
	# Set basic container information
	item.set_text(COL_TYPE, "Container")
	item.set_custom_bg_color(COL_TYPE, Color.html("#2c3e50"))
	item.set_text(COL_VALUE, "")
	item.set_selectable(COL_VALUE, false)

	# Add container metadata
	var child_count = container.children.size()
	item.set_tooltip_text(COL_NAME, "Container with %d items" % child_count)

	# Style container items differently
	item.set_custom_font_size(COL_NAME, 14)

	# Set metadata for navigation
	item.set_metadata(0, container)

	# Add dependencies information if any
	var dependencies = container.dependencies.map(func(p): return p.to_string())
	var dependencies_text = "None" if dependencies.is_empty() else "\n".join(dependencies)
	item.set_text(COL_DEPENDENCIES, dependencies_text)

	if not dependencies.is_empty():
		item.set_tooltip_text(COL_DEPENDENCIES, "Dependencies:\n" + dependencies_text)

## Populates a tree item with property data
func _populate_property_item(item: TreeItem, property: NestedProperty) -> void:
	# Set property type
	item.set_text(COL_TYPE, Property.type_to_string(property.value_type))

	# Get and format property value
	var value = property.get_value()
	var value_text = Property.format_value(value)
	var wrapped_text = _wrap_text(value_text)

	# Set value display
	item.set_text(COL_VALUE, _get_condensed_text(value_text))
	item.set_tooltip_text(COL_VALUE, value_text)
	item.set_metadata(1, wrapped_text)  # Store full text for expansion
	item.set_selectable(COL_VALUE, true)

	# Add dependencies information
	var dependencies = property.dependencies.map(func(p): return p.to_string())
	var dependencies_text = "None" if dependencies.is_empty() else "\n".join(dependencies)
	item.set_text(COL_DEPENDENCIES, dependencies_text)

	if not dependencies.is_empty():
		item.set_tooltip_text(COL_DEPENDENCIES, "Dependencies:\n" + dependencies_text)

	# Add property metadata
	if property.description:
		item.set_tooltip_text(COL_NAME, property.description)

	# Store property reference
	item.set_metadata(0, property)

	# Style based on value type
	_style_property_item(item, property)

## Displays a single property in the tree
func _populate_single_property(parent_item: TreeItem, property: NestedProperty) -> void:
	if property.type != NestedProperty.Type.PROPERTY:
		return

	var item = properties_tree.create_item(parent_item)

	# Set property name
	item.set_text(COL_NAME, Helper.snake_to_readable(property.name))

	# Populate all property data
	_populate_property_item(item, property)

	# Expand the item by default since it's the only one
	item.set_collapsed(false)

## Recursively populates the tree with group properties, prioritizing higher-level properties
func _populate_group_properties(parent_item: TreeItem, container: NestedProperty) -> void:
	# Separate and sort children into properties and containers
	var properties: Array[NestedProperty] = []
	var containers: Array[NestedProperty] = []

	for child in container.children.values():
		if child.type == NestedProperty.Type.PROPERTY:
			properties.append(child)
		else:
			containers.append(child)

	# Sort properties and containers by name
	properties.sort_custom(func(a, b): return a.name < b.name)
	containers.sort_custom(func(a, b): return a.name < b.name)

	# Add properties first
	for property in properties:
		var item = properties_tree.create_item(parent_item)
		item.set_text(COL_NAME, Helper.snake_to_readable(property.name))
		_populate_property_item(item, property)
		item.set_metadata(0, property)

	# Then add containers
	for container_prop in containers:
		var item = properties_tree.create_item(parent_item)
		item.set_text(COL_NAME, Helper.snake_to_readable(container_prop.name))
		_populate_container_item(item, container_prop)
		item.set_metadata(0, container_prop)

## Updates selection for nested property
func _update_nested_property_selection(property: NestedProperty) -> void:
	var path = property.path.full
	path_label.text = path
	description_label.text = property.description
	property_selected.emit(path)
#endregion

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

#endregion

#region Property Access Methods

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
	loading_label.text ="Finished! Created %s items" % items_created
	await get_tree().create_timer(2.5).timeout
	if loading_label:
		loading_label.queue_free()
		loading_label = null

## Creates a batch of components per frame
func _create_batch(params: Dictionary, timer: Timer) -> void:
	var items_created = 0

	# Create food
	while params.food > 0 and items_created < ITEMS_PER_FRAME:
		loading_label.text ="Creating content: food (%s)" % params.food
		var food = Food.new(randf_range(0.0, 50.0))
		food.global_position = _get_random_position()
		add_child(food)
		params.food -= 1
		items_created += 1


	# Create ants if pheromones are done
	while params.food == 0 and params.pheromones == 0 and params.ants > 0 and items_created < ITEMS_PER_FRAME:
		loading_label.text ="Creating content: ants (%s)" % params.ants
		var ant = Ant.new()
		ant.global_position = _get_random_position()
		add_child(ant)
		ant.set_physics_process(false)
		ant.set_process(false)
		params.ants -= 1
		items_created += 1

	# Create pheromones if food is done
	while params.food == 0 and params.pheromones > 0 and items_created < ITEMS_PER_FRAME:
		loading_label.text ="Creating content: pheromones (%s)" % params.pheromones
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
## Applies styling to property items based on type and state
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
