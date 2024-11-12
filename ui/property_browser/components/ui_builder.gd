class_name PropertyBrowserUIBuilder
extends RefCounted

## UI references passed from main class
var mode_switch: OptionButton
var group_list: ItemList
var properties_tree: Tree
var path_label: Label
var group_label: Label
var description_label: Label
var back_button: Button
var loading_label: Label

## Constants for styling
const MIN_WINDOW_SIZE := Vector2(800, 500)
const CONTENT_PADDING := 10
const GROUP_LIST_MIN_WIDTH := 100
const PROPERTIES_TREE_MIN_HEIGHT := 400
const DESCRIPTION_PANEL_HEIGHT := 150
const BUTTON_SIZE := Vector2(100, 30)

## Signal declarations
signal ui_created
signal close_requested

## Initialize the builder with UI element references
func initialize(refs: Dictionary) -> void:
	mode_switch = refs.get("mode_switch")
	group_list = refs.get("group_list")
	properties_tree = refs.get("properties_tree")
	path_label = refs.get("path_label")
	group_label = refs.get("group_label")
	description_label = refs.get("description_label")
	back_button = refs.get("back_button")
	loading_label = refs.get("loading_label")

## Creates all UI elements and layout
func create_ui(parent_window: Window) -> Dictionary:
	var main_container := _create_main_container()
	parent_window.add_child(main_container)

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

## Creates the main content split layout and its contents
func _create_content_split(parent_window: Window, refs: Dictionary) -> HSplitContainer:
	var content_split := HSplitContainer.new()
	content_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_split.custom_minimum_size.y = 600
	content_split.split_offset = 200

	# Create and add left side (Groups)
	var left_side := VBoxContainer.new()
	left_side.name = "LeftPanel"
	content_split.add_child(left_side)
	
	refs.group_label = _create_group_label(left_side)
	_create_search_box(left_side)
	refs.group_list = _create_group_list(left_side)

	# Create and add right side (Properties)
	var right_side := VBoxContainer.new()
	right_side.name = "RightPanel"
	content_split.add_child(right_side)
	
	var properties_label := Label.new()
	properties_label.text = "Properties"
	right_side.add_child(properties_label)
	
	refs.properties_tree = _create_properties_tree(right_side)
	refs.description_label = _create_description_panel(right_side)

	return content_split

## Creates and configures the properties tree
func _create_properties_tree(parent: Control) -> Tree:
	var tree := Tree.new()
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size.y = PROPERTIES_TREE_MIN_HEIGHT
	parent.add_child(tree)
	return tree

## Creates the description panel, returns the label
func _create_description_panel(parent: Control) -> Label:
	var description_panel := PanelContainer.new()
	description_panel.name = "DescriptionPanel"
	description_panel.custom_minimum_size.y = DESCRIPTION_PANEL_HEIGHT
	description_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(description_panel)

	var description_container := VBoxContainer.new()
	description_container.add_theme_constant_override("separation", 5)
	description_panel.add_child(description_container)

	var description_title := Label.new()
	description_title.text = "Description"
	description_container.add_child(description_title)

	var label = Label.new()
	label.name = "DescriptionLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.y = 100
	description_container.add_child(label)
	description_label = label

	return label

## Creates the group label
func _create_group_label(parent: Control) -> Label:
	group_label = Label.new()
	group_label.text = "Property Groups"
	group_label.add_theme_font_size_override("font_size", 16)
	parent.add_child(group_label)
	return group_label

## Creates and configures the group list
func _create_group_list(parent: Control) -> ItemList:
	group_list = ItemList.new()
	group_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	group_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_list.custom_minimum_size.y = 300
	group_list.select_mode = ItemList.SELECT_SINGLE
	group_list.same_column_width = true

	_apply_group_list_style(group_list)
	parent.add_child(group_list)

	return group_list

## Creates the properties panel with tree view and description
func _create_properties_panel(parent: Control) -> VBoxContainer:
	var right_container := VBoxContainer.new()
	right_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_container.add_theme_constant_override("separation", 10)
	parent.add_child(right_container)
	
	# Properties tree label and tree will be added here
	# Description panel will be added here
	
	return right_container

## Creates the main container with proper layout settings
func _create_main_container() -> VBoxContainer:
	var container := VBoxContainer.new()

	# Use full rect preset with padding
	container.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT,
		Control.PRESET_MODE_MINSIZE,
		CONTENT_PADDING
	)

	# Set minimum size and expansion
	container.custom_minimum_size = MIN_WINDOW_SIZE
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	return container

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
	mode_switch.add_item("Attribute Properties", 0)
	mode_container.add_child(mode_switch)

	return mode_switch

## Creates the property group selection panel
func _create_group_panel(parent: Control) -> VBoxContainer:
	var group_container := VBoxContainer.new()
	group_container.custom_minimum_size.x = GROUP_LIST_MIN_WIDTH
	group_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(group_container)

	_create_group_label(group_container)
	_create_search_box(group_container)
	_create_group_list(group_container)

	return group_container


## Creates the search box for filtering groups
func _create_search_box(parent: Control) -> LineEdit:
	var search_box := LineEdit.new()
	search_box.placeholder_text = "Search groups... (use '.' for paths)"
	search_box.clear_button_enabled = true
	parent.add_child(search_box)
	return search_box

## Applies styling to the group list
func _apply_group_list_style(list: ItemList) -> void:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color.html("#2c3e50")
	style_box.set_corner_radius_all(4)
	list.add_theme_stylebox_override("panel", style_box)

	list.add_theme_color_override("font_color", Color.html("#ecf0f1"))
	list.add_theme_color_override("font_selected_color", Color.html("#2ecc71"))

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

func _create_loading_label(parent: Control) -> Label:
	loading_label = Label.new()
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Style the label
	loading_label.add_theme_color_override("font_color", Color(1, 1, 1))
	loading_label.add_theme_font_size_override("font_size", 24)

	# Center in window
	loading_label.set_anchors_preset(Control.PRESET_CENTER)

	parent.add_child(loading_label)
	loading_label.visible = false

	return loading_label

## Creates and displays a loading indicator
func show_loading_indicator(parent_window: Window) -> void:
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

## Helper method to create styled labels
func _create_styled_label(text: String, font_size: int = 14) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label

## Helper method to create styled buttons
func _create_styled_button(text: String, size: Vector2 = BUTTON_SIZE) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = size
	return button
