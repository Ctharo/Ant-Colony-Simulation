class_name PropertyBrowserUIBuilder
extends RefCounted

#region Signals
## Signal declarations
signal ui_created
signal close_requested
#endregion

#region Constants
## UI Layout Constants
const MIN_WINDOW_SIZE := Vector2(800, 500)
const CONTENT_PADDING := 10
const GROUP_LIST_MIN_WIDTH := 270
const GROUP_LIST_MAX_WIDTH := 300
const PROPERTIES_TREE_MIN_HEIGHT := 400
const DESCRIPTION_PANEL_MIN_HEIGHT := 100
const DESCRIPTION_PANEL_MAX_HEIGHT := 250
const DESCRIPTION_PANEL_HEIGHT := 150
const BUTTON_SIZE := Vector2(100, 30)
const SPLIT_RATIO := 0.25  # Left panel takes 25% of the width
#endregion

#region UI References
## UI controls
var mode_switch: OptionButton
var node_list: ItemList
var properties_tree: Tree
var path_label: Label
var root_label: Label
var description_label: Label
var back_button: Button
var loading_label: Label
#endregion

#region Public Interface
## Initialize the builder with UI element references
func initialize(refs: Dictionary) -> void:
	mode_switch = refs.get("mode_switch")
	node_list = refs.get("node_list")
	properties_tree = refs.get("properties_tree")
	path_label = refs.get("path_label")
	root_label = refs.get("root_label")
	description_label = refs.get("description_label")
	back_button = refs.get("back_button")
	loading_label = refs.get("loading_label")

## Creates all UI elements and layout
func create_ui(parent_window: Window) -> Dictionary:
	# Set up window size constraints
	parent_window.min_size = MIN_WINDOW_SIZE

	var main_container := _create_main_container()
	parent_window.add_child(main_container)

	# Connect to window resize signal
	parent_window.size_changed.connect(_on_window_resize.bind(parent_window))

	var refs := {}

	# Top sections
	refs.mode_switch = _create_mode_selector(main_container)
	refs.back_button = _create_navigation_controls(main_container)

	# Create split with its sides
	var content_split = _create_content_split(parent_window, refs)
	main_container.add_child(content_split)

	# Bottom sections
	refs.path_label = _create_path_display(main_container)
	refs.loading_label = _create_loading_label(main_container)
	_create_close_button(main_container)

	ui_created.emit()
	return refs

## Creates and displays a loading indicator
func show_loading_indicator(_parent_window: Window) -> void:
	loading_label.text = "Creating content..."
	loading_label.visible = true

## Updates the loading indicator text
func update_loading_text(text: String) -> void:
	if loading_label:
		loading_label.text = text

## Removes the loading indicator
func remove_loading_indicator() -> void:
	if loading_label:
		loading_label.queue_free()
		loading_label = null
#endregion

#region Layout Creation
## Creates the main content split layout and its contents
func _create_content_split(_parent_window: Window, refs: Dictionary) -> HSplitContainer:
	var content_split := HSplitContainer.new()
	content_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_split.split_offset = GROUP_LIST_MIN_WIDTH

	# Create and add left side (Property Tree)
	var left_side := VBoxContainer.new()
	left_side.name = "LeftPanel"
	left_side.size_flags_horizontal = Control.SIZE_FILL
	content_split.add_child(left_side)

	refs.root_label = _create_root_label(left_side)
	_create_search_box(left_side)
	refs.node_list = _create_node_list(left_side)

	# Create and add right side (Properties)
	var right_side := VBoxContainer.new()
	right_side.name = "RightPanel"
	right_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_split.add_child(right_side)

	var properties_label := _create_styled_label("Properties", 16)
	right_side.add_child(properties_label)

	refs.properties_tree = _create_properties_tree(right_side)
	refs.description_label = _create_description_panel(right_side)

	return content_split

## Creates the main container with responsive layout
func _create_main_container() -> VBoxContainer:
	var container := VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.set_offset(SIDE_LEFT, CONTENT_PADDING)
	container.set_offset(SIDE_TOP, CONTENT_PADDING)
	container.set_offset(SIDE_RIGHT, -CONTENT_PADDING)
	container.set_offset(SIDE_BOTTOM, -CONTENT_PADDING)
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return container
#endregion

#region UI Components
## Creates the root label
func _create_root_label(parent: Control) -> Label:
	root_label = Label.new()
	root_label.text = "Property Tree"
	root_label.add_theme_font_size_override("font_size", 16)
	parent.add_child(root_label)
	return root_label

## Creates and configures the node list with dynamic sizing
func _create_node_list(parent: Control) -> ItemList:
	node_list = ItemList.new()
	node_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node_list.custom_minimum_size = Vector2(GROUP_LIST_MIN_WIDTH, 300)
	node_list.select_mode = ItemList.SELECT_SINGLE
	node_list.same_column_width = true

	_apply_node_list_style(node_list)
	parent.add_child(node_list)

	return node_list

## Creates and configures the properties tree
func _create_properties_tree(parent: Control) -> Tree:
	var tree := Tree.new()
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size.y = PROPERTIES_TREE_MIN_HEIGHT
	parent.add_child(tree)
	return tree

## Creates the description panel with dynamic sizing
func _create_description_panel(parent: Control) -> Label:
	var description_panel := PanelContainer.new()
	description_panel.name = "DescriptionPanel"
	description_panel.custom_minimum_size.y = DESCRIPTION_PANEL_MIN_HEIGHT
	description_panel.size_flags_vertical = Control.SIZE_FILL
	description_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(description_panel)

	var description_container := VBoxContainer.new()
	description_container.add_theme_constant_override("separation", 5)
	description_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_panel.add_child(description_container)

	var description_title := _create_styled_label("Description", 16)
	description_container.add_child(description_title)

	var label = Label.new()
	label.name = "DescriptionLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.y = 100
	description_container.add_child(label)
	description_label = label

	return label

## Creates the navigation controls section
func _create_navigation_controls(parent: Control) -> Button:
	var nav_container := HBoxContainer.new()
	parent.add_child(nav_container)

	back_button = Button.new()
	back_button.text = "← Back"
	back_button.disabled = true
	nav_container.add_child(back_button)

	return back_button

## Creates the mode selection UI
func _create_mode_selector(parent: Control) -> OptionButton:
	var mode_container := HBoxContainer.new()
	parent.add_child(mode_container)

	var mode_label := Label.new()
	mode_label.text = "Browse Mode:"
	mode_container.add_child(mode_label)

	mode_switch = OptionButton.new()
	mode_switch.add_item("Property Tree View", 0)
	mode_container.add_child(mode_switch)

	return mode_switch

## Creates the search box for filtering nodes
func _create_search_box(parent: Control) -> LineEdit:
	var search_box := LineEdit.new()
	search_box.placeholder_text = "Search properties... (use '.' for paths)"
	search_box.clear_button_enabled = true
	parent.add_child(search_box)
	return search_box

## Creates the property path display
func _create_path_display(parent: Control) -> Label:
	var path_container := HBoxContainer.new()
	path_container.add_theme_constant_override("separation", 10)
	parent.add_child(path_container)

	var path_title := Label.new()
	path_title.text = "Selected Property Path:"
	path_container.add_child(path_title)

	path_label = Label.new()
	path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_container.add_child(path_label)

	return path_label

## Creates the loading label
func _create_loading_label(parent: Control) -> Label:
	loading_label = Label.new()
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loading_label.add_theme_color_override("font_color", Color(1, 1, 1))
	loading_label.add_theme_font_size_override("font_size", 24)
	loading_label.set_anchors_preset(Control.PRESET_CENTER)
	parent.add_child(loading_label)
	loading_label.visible = false
	return loading_label

## Creates the close button
func _create_close_button(parent: Control) -> Button:
	var button_container := HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 10)
	parent.add_child(button_container)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = BUTTON_SIZE
	close_button.pressed.connect(func(): close_requested.emit())
	button_container.add_child(close_button)

	return close_button
#endregion

#region Styling
## Applies styling to the node list
func _apply_node_list_style(list: ItemList) -> void:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color.html("#2c3e50")
	style_box.set_corner_radius_all(4)
	list.add_theme_stylebox_override("panel", style_box)
	list.add_theme_color_override("font_color", Color.html("#ecf0f1"))
	list.add_theme_color_override("font_selected_color", Color.html("#2ecc71"))

## Creates styled labels
func _create_styled_label(text: String, font_size: int = 14) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label

## Creates styled buttons
func _create_styled_button(text: String, size: Vector2 = BUTTON_SIZE) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = size
	return button
#endregion

#region Layout Updates
## Handle window resize events
func _on_window_resize(window: Window) -> void:
	var available_width := window.size.x - (2 * CONTENT_PADDING)
	var available_height := window.size.y - (2 * CONTENT_PADDING)

	_update_split_layout(available_width)
	_update_description_layout(available_height)

## Update split container layout
func _update_split_layout(available_width: float) -> void:
	if is_instance_valid(node_list):
		var split_width: int = max(
			min(available_width * SPLIT_RATIO, GROUP_LIST_MAX_WIDTH),
			GROUP_LIST_MIN_WIDTH
		)
		node_list.custom_minimum_size.x = split_width

## Update description panel layout
func _update_description_layout(available_height: float) -> void:
	if is_instance_valid(description_label):
		var parent_container = description_label.get_parent().get_parent() as PanelContainer
		if parent_container:
			var desc_height: int = min(
				available_height * 0.25,  # Take up to 25% of height
				DESCRIPTION_PANEL_MAX_HEIGHT
			)
			parent_container.custom_minimum_size.y = max(
				desc_height,
				DESCRIPTION_PANEL_MIN_HEIGHT
			)
#endregion
