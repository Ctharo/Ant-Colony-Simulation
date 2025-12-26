class_name AntInfoPanel
extends PanelContainer

#region Constants
const STYLE = {
	"BAR_BG_COLOR": Color(0.2, 0.2, 0.2),
	"HEALTH_COLOR": Color(0.2, 0.8, 0.2),
	"ENERGY_COLOR": Color(0.2, 0.2, 0.8),
	"LOW_COLOR": Color.RED,
	"MED_COLOR": Color.CORAL,
	"PANEL_SIZE": Vector2(320, 550),
	"SELECTION_CIRCLE_COLOR": Color(Color.WHITE, 0.5),
	"SELECTION_CIRCLE_RADIUS": 12.0,
	"SELECTION_CIRCLE_WIDTH": 2.0,
	"INFLUENCE_SETTINGS": {
		"OVERALL_COLOR": Color.WHITE,
		"ARROW_LENGTH": 50.0,
		"ARROW_WIDTH": 2.0,
		"ARROW_HEAD_SIZE": 8.0,
		"OVERALL_SCALE": 1.5,
		"IGNORE_TYPES": ["random"],
		"MIN_WEIGHT_THRESHOLD": 0.01
	}
}
#endregion

#region Member Variables
var _influence_colors: Dictionary = {}
var heatmap: HeatmapManager
var current_ant: Ant
#endregion

#region UI Components
@onready var title_label: Label = %TitleLabel
@onready var role_label: Label = %RoleLabel
@onready var colony_label: Label = %ColonyLabel
@onready var action_label: Label = %ActionLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var food_label: Label = %FoodLabel
@onready var health_value_label: Label = %HealthValueLabel
@onready var energy_value_label: Label = %EnergyValueLabel
@onready var close_button: Button = %CloseButton

## Profile Section
@onready var profile_name_label: Label = %ProfileNameLabel
@onready var edit_profile_button: Button = %EditProfileButton

## Movement Influences Section
@onready var active_profile_label: Label = %ActiveProfileLabel
@onready var view_influence_profile_button: Button = %ViewInfluenceProfileButton

## Visualization Section
@onready var show_heatmap_check: CheckButton = %ShowHeatmapCheck
@onready var show_influence_vectors_check: CheckButton = %ShowInfluenceVectorsCheck
@onready var show_nav_path_check: CheckButton = %ShowNavPathCheck

## Influences Legend
@onready var influences_legend: VBoxContainer = %InfluencesLegend
#endregion


func _ready() -> void:
	custom_minimum_size = STYLE.PANEL_SIZE
	hide()
	setup_styling()
	clear_legend()
	
	heatmap = get_tree().get_first_node_in_group("heatmap")
	
	_connect_signals()


func _connect_signals() -> void:
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	if edit_profile_button:
		edit_profile_button.pressed.connect(_on_edit_profile_pressed)
	if view_influence_profile_button:
		view_influence_profile_button.pressed.connect(_on_view_influence_profile_pressed)


func _process(_delta: float) -> void:
	_update_ui()
	queue_redraw()


#region Public Methods
func show_ant_info(ant: Ant) -> void:
	if not ant:
		return
	
	current_ant = ant
	show()
	
	title_label.text = "Ant #%d" % ant.id
	colony_label.text = "Colony: %s" % (str(ant.colony.name) if ant.colony else "None")
	
	_update_profile_section()
	_update_movement_influences_section()
	update_status_bars()
	
	food_label.text = "Carrying Food: %s" % ("Yes" if ant.is_carrying_food else "No")
	
	queue_redraw()
#endregion


#region UI Update Methods
func _update_ui() -> void:
	if not current_ant or not is_visible():
		return
	
	if not is_instance_valid(current_ant):
		return
	
	update_status_bars()
	
	food_label.text = "Carrying Food: %s" % ("Yes" if current_ant.is_carrying_food else "No")
	role_label.text = "Role: %s" % current_ant.role
	
	_update_movement_influences_section()
	
	# Update legend every 20 physics frames
	if Engine.get_physics_frames() % 20 != 0:
		return
	
	if current_ant.influence_manager and current_ant.influence_manager.active_profile:
		update_legend(current_ant.influence_manager.active_profile.influences)


func _update_profile_section() -> void:
	if not current_ant or not current_ant.profile:
		profile_name_label.text = "Profile: None"
		edit_profile_button.disabled = true
		return
	
	profile_name_label.text = "Profile: %s" % current_ant.profile.name
	edit_profile_button.disabled = false


func _update_movement_influences_section() -> void:
	if not current_ant or not current_ant.influence_manager:
		active_profile_label.text = "Active: None"
		view_influence_profile_button.disabled = true
		return
	
	var active = current_ant.influence_manager.active_profile
	if active:
		active_profile_label.text = "Active: %s" % active.name
		view_influence_profile_button.disabled = false
	else:
		active_profile_label.text = "Active: None"
		view_influence_profile_button.disabled = true
#endregion


#region Styling
func setup_styling() -> void:
	health_bar.add_theme_stylebox_override("fill", create_stylebox(STYLE.HEALTH_COLOR))
	health_bar.add_theme_stylebox_override("background", create_stylebox(STYLE.BAR_BG_COLOR))
	
	energy_bar.add_theme_stylebox_override("fill", create_stylebox(STYLE.ENERGY_COLOR))
	energy_bar.add_theme_stylebox_override("background", create_stylebox(STYLE.BAR_BG_COLOR))


func create_stylebox(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style
#endregion


#region Status Bars
func update_status_bars() -> void:
	if not current_ant:
		return
	
	var health_percent = (current_ant.health_level / current_ant.health_max) * 100.0
	health_bar.value = health_percent
	health_value_label.text = "%d/%d" % [current_ant.health_level, current_ant.health_max]
	update_bar_color(health_bar, health_percent, STYLE.HEALTH_COLOR)
	
	var energy_percent = (current_ant.energy_level / current_ant.energy_max) * 100.0
	energy_bar.value = energy_percent
	energy_value_label.text = "%d/%d" % [current_ant.energy_level, current_ant.energy_max]
	update_bar_color(energy_bar, energy_percent, STYLE.ENERGY_COLOR)


func update_bar_color(bar: ProgressBar, value: float, normal_color: Color) -> void:
	var style = bar.get_theme_stylebox("fill") as StyleBoxFlat
	if value > 66:
		style.bg_color = normal_color
	elif value > 33:
		style.bg_color = STYLE.MED_COLOR
	else:
		style.bg_color = STYLE.LOW_COLOR
#endregion


#region Legend Management
func clear_legend() -> void:
	for child in influences_legend.get_children():
		child.queue_free()
	_influence_colors.clear()


func update_legend(influences: Array) -> void:
	clear_legend()
	
	if not current_ant or not is_instance_valid(current_ant):
		return
	
	var total_magnitude = 0.0
	var influence_data = []
	
	for influence in influences:
		if _should_ignore_influence(influence):
			continue
		
		if not influence.is_valid(current_ant):
			continue
		
		var direction = EvaluationSystem.get_value(influence, current_ant)
		var magnitude = direction.length()
		
		if magnitude < STYLE.INFLUENCE_SETTINGS.MIN_WEIGHT_THRESHOLD:
			continue
		
		total_magnitude += magnitude
		influence_data.append({
			"influence": influence,
			"magnitude": magnitude
		})
	
	influence_data.sort_custom(
		func(a, b): return a.magnitude > b.magnitude
	)
	
	add_legend_entry("Overall", STYLE.INFLUENCE_SETTINGS.OVERALL_COLOR, 1.0)
	
	var separator = HSeparator.new()
	influences_legend.add_child(separator)
	
	for data in influence_data:
		var influence = data.influence
		var normalized_weight = data.magnitude / total_magnitude if total_magnitude > 0 else 0.0
		add_legend_entry(
			influence.name,
			influence.color,
			normalized_weight
		)


func add_legend_entry(p_name: String, color: Color, normalized_weight: float) -> void:
	var entry = HBoxContainer.new()
	
	var influence_type = p_name.to_snake_case().trim_suffix("_influence")
	if not influence_type in STYLE.INFLUENCE_SETTINGS.IGNORE_TYPES:
		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(16, 16)
		color_rect.color = color
		entry.add_child(color_rect)
	else:
		var color_spacer = Control.new()
		color_spacer.custom_minimum_size = Vector2(17, 0)
		entry.add_child(color_spacer)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(5, 0)
	entry.add_child(spacer)
	
	var name_label = Label.new()
	name_label.text = p_name.trim_suffix("_influence").capitalize()
	entry.add_child(name_label)
	
	var weight_label = Label.new()
	weight_label.custom_minimum_size.x = 70
	weight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weight_label.text = "%.1f%%" % (normalized_weight * 100)
	
	var weight_spacer = Control.new()
	weight_spacer.custom_minimum_size = Vector2(10, 0)
	entry.add_child(weight_spacer)
	
	entry.add_child(weight_label)
	
	influences_legend.add_child(entry)


func _should_ignore_influence(influence: Influence) -> bool:
	var influence_type = influence.name.to_snake_case().trim_suffix("_influence")
	return influence_type in STYLE.INFLUENCE_SETTINGS.IGNORE_TYPES
#endregion


#region Signal Handlers - Profile
func _on_edit_profile_pressed() -> void:
	if not current_ant or not current_ant.profile:
		return
	
	var editor = AntProfileEditorPopup.new()
	add_child(editor)
	editor.edit_profile(current_ant.profile)
	await editor.closed
	_update_profile_section()


func _on_view_influence_profile_pressed() -> void:
	if not current_ant or not current_ant.influence_manager:
		return
	
	var active = current_ant.influence_manager.active_profile
	if not active:
		return
	
	var popup = InfluenceProfileViewPopup.new()
	add_child(popup)
	popup.show_profile(active)
#endregion


#region Signal Handlers - Visualization
func _on_show_nav_path_check_toggled(toggled_on: bool) -> void:
	if current_ant:
		current_ant.nav_agent.debug_enabled = toggled_on


func _on_show_heatmap_toggled(enabled: bool) -> void:
	if current_ant:
		if enabled:
			heatmap.debug_draw(current_ant, true)
		else:
			heatmap.debug_draw(current_ant, false)


func _on_show_influence_vectors_check_toggled(toggled_on: bool) -> void:
	if current_ant and current_ant.influence_manager:
		current_ant.influence_manager.set_visualization_enabled(toggled_on)
#endregion


#region Signal Handlers - Panel
func _on_close_pressed() -> void:
	queue_free()
#endregion


func _exit_tree() -> void:
	if current_ant and is_instance_valid(current_ant):
		if current_ant.nav_agent:
			current_ant.nav_agent.debug_enabled = false
		if heatmap:
			heatmap.debug_draw(current_ant, false)
