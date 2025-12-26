class_name InfluenceProfileViewPopup
extends Window

signal closed()

#region Constants
const WINDOW_SIZE = Vector2i(500, 500)
#endregion

#region Member Variables
var viewing_profile: InfluenceProfile
#endregion


func _init() -> void:
	title = "Influence Profile"
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
	vbox.name = "MainVBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)
	
	_add_header_section(vbox)
	_add_separator(vbox)
	_add_conditions_section(vbox, "Enter Conditions", "EnterConditionsList")
	_add_separator(vbox)
	_add_conditions_section(vbox, "Exit Conditions", "ExitConditionsList")
	_add_separator(vbox)
	_add_influences_section(vbox)
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


#region Header Section
func _add_header_section(parent: Control) -> void:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	parent.add_child(container)
	
	var name_label = Label.new()
	name_label.name = "ProfileNameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	container.add_child(name_label)
#endregion


#region Conditions Section
func _add_conditions_section(parent: Control, section_title: String, list_name: String) -> void:
	_add_section_label(parent, section_title)
	
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	parent.add_child(container)
	
	var list = ItemList.new()
	list.name = list_name
	list.custom_minimum_size = Vector2(0, 60)
	list.select_mode = ItemList.SELECT_SINGLE
	container.add_child(list)
#endregion


#region Influences Section
func _add_influences_section(parent: Control) -> void:
	_add_section_label(parent, "Influences")
	
	var container = VBoxContainer.new()
	container.name = "InfluencesContainer"
	container.add_theme_constant_override("separation", 5)
	parent.add_child(container)
	
	var list = ItemList.new()
	list.name = "InfluencesList"
	list.custom_minimum_size = Vector2(0, 120)
	list.select_mode = ItemList.SELECT_SINGLE
	list.item_selected.connect(_on_influence_selected)
	container.add_child(list)
	
	# Details panel for selected influence
	var details_container = VBoxContainer.new()
	details_container.name = "InfluenceDetailsContainer"
	details_container.visible = false
	container.add_child(details_container)
	
	var details_label = Label.new()
	details_label.text = "Selected Influence Details:"
	details_container.add_child(details_label)
	
	var details_grid = GridContainer.new()
	details_grid.name = "InfluenceDetailsGrid"
	details_grid.columns = 2
	details_grid.add_theme_constant_override("h_separation", 10)
	details_grid.add_theme_constant_override("v_separation", 5)
	details_container.add_child(details_grid)
	
	# Expression label
	var expr_label = Label.new()
	expr_label.text = "Expression:"
	details_grid.add_child(expr_label)
	
	var expr_value = Label.new()
	expr_value.name = "ExpressionValue"
	expr_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	expr_value.custom_minimum_size.x = 300
	details_grid.add_child(expr_value)
	
	# Color label
	var color_label = Label.new()
	color_label.text = "Color:"
	details_grid.add_child(color_label)
	
	var color_rect = ColorRect.new()
	color_rect.name = "ColorValue"
	color_rect.custom_minimum_size = Vector2(60, 20)
	details_grid.add_child(color_rect)
	
	# Condition label
	var cond_label = Label.new()
	cond_label.text = "Condition:"
	details_grid.add_child(cond_label)
	
	var cond_value = Label.new()
	cond_value.name = "ConditionValue"
	cond_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cond_value.custom_minimum_size.x = 300
	details_grid.add_child(cond_value)


func _on_influence_selected(index: int) -> void:
	if not viewing_profile or index < 0:
		return
	
	if index >= viewing_profile.influences.size():
		return
	
	var influence = viewing_profile.influences[index] as Influence
	if not influence:
		return
	
	var details_container = _find_node("InfluenceDetailsContainer") as Control
	if details_container:
		details_container.visible = true
	
	var expr_value = _find_node("ExpressionValue") as Label
	if expr_value:
		expr_value.text = influence.expression_string if influence.expression_string else "N/A"
	
	var color_rect = _find_node("ColorValue") as ColorRect
	if color_rect:
		color_rect.color = influence.color if influence.color else Color.WHITE
	
	var cond_value = _find_node("ConditionValue") as Label
	if cond_value:
		if influence.condition:
			cond_value.text = influence.condition.expression_string if influence.condition.expression_string else "N/A"
		else:
			cond_value.text = "Always active"
#endregion


#region Buttons Section
func _add_buttons(parent: Control) -> void:
	var buttons_row = HBoxContainer.new()
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_row.add_theme_constant_override("separation", 10)
	parent.add_child(buttons_row)
	
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_on_close_button_pressed)
	buttons_row.add_child(close_btn)
#endregion


#region Public Methods
func show_profile(profile: InfluenceProfile) -> void:
	viewing_profile = profile
	title = "Influence Profile: %s" % profile.name
	_populate_fields()
	popup_centered()


func _populate_fields() -> void:
	if not viewing_profile:
		return
	
	# Name
	var name_label = _find_node("ProfileNameLabel") as Label
	if name_label:
		name_label.text = viewing_profile.name
	
	# Enter Conditions
	var enter_list = _find_node("EnterConditionsList") as ItemList
	if enter_list:
		enter_list.clear()
		for condition in viewing_profile.enter_conditions:
			if condition:
				enter_list.add_item("%s: %s" % [condition.name, condition.expression_string])
		if enter_list.item_count == 0:
			enter_list.add_item("(No enter conditions)")
	
	# Exit Conditions
	var exit_list = _find_node("ExitConditionsList") as ItemList
	if exit_list:
		exit_list.clear()
		for condition in viewing_profile.exit_conditions:
			if condition:
				exit_list.add_item("%s: %s" % [condition.name, condition.expression_string])
		if exit_list.item_count == 0:
			exit_list.add_item("(No exit conditions)")
	
	# Influences
	var influences_list = _find_node("InfluencesList") as ItemList
	if influences_list:
		influences_list.clear()
		for influence in viewing_profile.influences:
			var inf = influence as Influence
			if inf:
				influences_list.add_item(inf.name)
	
	# Hide details until something is selected
	var details_container = _find_node("InfluenceDetailsContainer") as Control
	if details_container:
		details_container.visible = false
#endregion


#region Utility Methods
func _find_node(node_name: String) -> Node:
	return find_child(node_name, true, false)
#endregion


#region Signal Handlers
func _on_close_button_pressed() -> void:
	closed.emit()
	queue_free()


func _on_close_requested() -> void:
	closed.emit()
	queue_free()
#endregion
