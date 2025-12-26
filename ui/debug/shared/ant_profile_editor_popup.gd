class_name AntProfileEditorPopup
extends Window

signal closed(profile: AntProfile)

#region Constants
const WINDOW_SIZE = Vector2i(450, 600)
#endregion

#region Member Variables
var editing_profile: AntProfile
var _influence_profiles: Array[InfluenceProfile] = [] as Array[InfluenceProfile]
#endregion


func _init() -> void:
	title = "Edit Ant Profile"
	size = WINDOW_SIZE
	unresizable = false
	close_requested.connect(_on_close_requested)


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)
	
	_add_basic_section(vbox)
	_add_separator(vbox)
	_add_stats_section(vbox)
	_add_separator(vbox)
	_add_movement_influences_section(vbox)
	_add_separator(vbox)
	_add_pheromones_section(vbox)
	_add_separator(vbox)
	_add_buttons(vbox)


func _add_separator(parent: Control) -> void:
	var sep = HSeparator.new()
	parent.add_child(sep)


func _add_section_label(parent: Control, text: String) -> void:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)


#region Basic Info Section
func _add_basic_section(parent: Control) -> void:
	_add_section_label(parent, "Basic Info")
	
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	parent.add_child(container)
	
	# Name
	var name_row = _create_row("Name:")
	var name_edit = LineEdit.new()
	name_edit.name = "NameEdit"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(_on_name_changed)
	name_row.add_child(name_edit)
	container.add_child(name_row)


func _on_name_changed(new_text: String) -> void:
	if editing_profile:
		editing_profile.name = new_text
#endregion


#region Stats Section
func _add_stats_section(parent: Control) -> void:
	_add_section_label(parent, "Stats")
	
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	parent.add_child(container)
	
	# Movement Rate
	var movement_row = _create_row("Movement Rate:")
	var movement_spin = SpinBox.new()
	movement_spin.name = "MovementRateSpin"
	movement_spin.min_value = 1.0
	movement_spin.max_value = 100.0
	movement_spin.step = 0.5
	movement_spin.value_changed.connect(_on_movement_rate_changed)
	movement_row.add_child(movement_spin)
	container.add_child(movement_row)
	
	# Vision Range
	var vision_row = _create_row("Vision Range:")
	var vision_spin = SpinBox.new()
	vision_spin.name = "VisionRangeSpin"
	vision_spin.min_value = 10.0
	vision_spin.max_value = 500.0
	vision_spin.step = 5.0
	vision_spin.value_changed.connect(_on_vision_range_changed)
	vision_row.add_child(vision_spin)
	container.add_child(vision_row)
	
	# Size
	var size_row = _create_row("Size:")
	var size_spin = SpinBox.new()
	size_spin.name = "SizeSpin"
	size_spin.min_value = 0.5
	size_spin.max_value = 5.0
	size_spin.step = 0.1
	size_spin.value_changed.connect(_on_size_changed)
	size_row.add_child(size_spin)
	container.add_child(size_row)


func _on_movement_rate_changed(value: float) -> void:
	if editing_profile:
		editing_profile.movement_rate = value


func _on_vision_range_changed(value: float) -> void:
	if editing_profile:
		editing_profile.vision_range = value


func _on_size_changed(value: float) -> void:
	if editing_profile:
		editing_profile.size = value
#endregion


#region Movement Influences Section
func _add_movement_influences_section(parent: Control) -> void:
	_add_section_label(parent, "Movement Influences")
	
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	parent.add_child(container)
	
	var list = ItemList.new()
	list.name = "InfluencesList"
	list.custom_minimum_size = Vector2(0, 100)
	list.select_mode = ItemList.SELECT_SINGLE
	list.item_selected.connect(_on_influence_selected)
	container.add_child(list)
	
	var buttons_row = HBoxContainer.new()
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_row.add_theme_constant_override("separation", 10)
	container.add_child(buttons_row)
	
	var view_btn = Button.new()
	view_btn.name = "ViewInfluenceBtn"
	view_btn.text = "View Details"
	view_btn.disabled = true
	view_btn.pressed.connect(_on_view_influence_pressed)
	buttons_row.add_child(view_btn)


func _on_influence_selected(_index: int) -> void:
	var view_btn = _find_node("ViewInfluenceBtn") as Button
	if view_btn:
		view_btn.disabled = false


func _on_view_influence_pressed() -> void:
	var list = _find_node("InfluencesList") as ItemList
	if not list:
		return
	
	var selected = list.get_selected_items()
	if selected.is_empty() or not editing_profile:
		return
	
	var idx = selected[0]
	if idx < editing_profile.movement_influences.size():
		var influence_profile = editing_profile.movement_influences[idx]
		_show_influence_profile_details(influence_profile)


func _show_influence_profile_details(profile: InfluenceProfile) -> void:
	var popup = InfluenceProfileViewPopup.new()
	add_child(popup)
	popup.show_profile(profile)
#endregion


#region Pheromones Section
func _add_pheromones_section(parent: Control) -> void:
	_add_section_label(parent, "Pheromones")
	
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	parent.add_child(container)
	
	var list = ItemList.new()
	list.name = "PheromonesList"
	list.custom_minimum_size = Vector2(0, 80)
	list.select_mode = ItemList.SELECT_SINGLE
	container.add_child(list)
#endregion


#region Buttons Section
func _add_buttons(parent: Control) -> void:
	var buttons_row = HBoxContainer.new()
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_row.add_theme_constant_override("separation", 10)
	parent.add_child(buttons_row)
	
	var done_btn = Button.new()
	done_btn.text = "Done"
	done_btn.pressed.connect(_on_done_pressed)
	buttons_row.add_child(done_btn)
#endregion


#region Public Methods
func edit_profile(profile: AntProfile) -> void:
	editing_profile = profile
	title = "Edit Ant Profile: %s" % profile.name
	_populate_fields()
	popup_centered()


func _populate_fields() -> void:
	if not editing_profile:
		return
	
	# Basic info
	var name_edit = _find_node("NameEdit") as LineEdit
	if name_edit:
		name_edit.text = editing_profile.name
	
	# Stats
	var movement_spin = _find_node("MovementRateSpin") as SpinBox
	if movement_spin:
		movement_spin.set_value_no_signal(editing_profile.movement_rate)
	
	var vision_spin = _find_node("VisionRangeSpin") as SpinBox
	if vision_spin:
		vision_spin.set_value_no_signal(editing_profile.vision_range)
	
	var size_spin = _find_node("SizeSpin") as SpinBox
	if size_spin:
		size_spin.set_value_no_signal(editing_profile.size)
	
	# Movement Influences
	var influences_list = _find_node("InfluencesList") as ItemList
	if influences_list:
		influences_list.clear()
		for influence_profile in editing_profile.movement_influences:
			if influence_profile:
				influences_list.add_item(influence_profile.name)
	
	# Pheromones
	var pheromones_list = _find_node("PheromonesList") as ItemList
	if pheromones_list:
		pheromones_list.clear()
		for pheromone in editing_profile.pheromones:
			if pheromone:
				pheromones_list.add_item(pheromone.name)
#endregion


#region Utility Methods
func _create_row(label_text: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row


func _find_node(node_name: String) -> Node:
	return find_child(node_name, true, false)
#endregion


#region Signal Handlers
func _on_done_pressed() -> void:
	closed.emit(editing_profile)
	queue_free()


func _on_close_requested() -> void:
	closed.emit(editing_profile)
	queue_free()
#endregion
