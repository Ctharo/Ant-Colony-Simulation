class_name EntityInfoPanel
extends PanelContainer

signal highlight_ants(colony: Colony, enable: bool)
signal spawn_requested(colony: Colony, count: int, profile: AntProfile)
signal closed

#region Constants
const STYLE = {
	"PANEL_SIZE": Vector2(340, 700),
	"BAR_BG_COLOR": Color(0.2, 0.2, 0.2),
	"HEALTH_COLOR": Color(0.2, 0.8, 0.2),
	"ENERGY_COLOR": Color(0.2, 0.2, 0.8),
	"LOW_COLOR": Color.RED,
	"MED_COLOR": Color.CORAL,
	"SELECTION_CIRCLE_COLOR": Color(Color.WHITE, 0.5),
	"SELECTION_CIRCLE_WIDTH": 2.0,
	"INFLUENCE_SETTINGS": {
		"OVERALL_COLOR": Color.WHITE,
		"IGNORE_TYPES": ["random"],
		"MIN_WEIGHT_THRESHOLD": 0.01
	}
}
const ANT_HIGHLIGHT_RADIUS = 12.0
const ANT_HIGHLIGHT_COLOR = Color(Color.WHITE, 0.5)
#endregion

#region Member Variables
## Currently displayed entity (Ant or Colony)
var current_entity: Node
var _profile_map: Dictionary = {}
var _influence_colors: Dictionary = {}
var heatmap: HeatmapManager
## Tracks if we enabled influence visualization so we can disable on close
var _influence_vis_enabled_by_panel: bool = false
#endregion

#region UI Components - Header
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var title_label: Label = %TitleLabel
@onready var close_button: Button = %CloseButton
#endregion

#region UI Components - Info Section (shared)
@onready var info_container: VBoxContainer = %InfoContainer
#endregion

#region UI Components - Ant Section
@onready var ant_section: VBoxContainer = %AntSection
@onready var role_label: Label = %RoleLabel
@onready var colony_label: Label = %ColonyLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var health_value_label: Label = %HealthValueLabel
@onready var energy_value_label: Label = %EnergyValueLabel
@onready var food_label: Label = %FoodLabel
@onready var ant_profile_name_label: Label = %AntProfileNameLabel
@onready var edit_ant_profile_button: Button = %EditAntProfileButton
@onready var active_profile_label: Label = %ActiveProfileLabel
@onready var view_influence_profile_button: Button = %ViewInfluenceProfileButton
@onready var influences_legend: VBoxContainer = %InfluencesLegend
#endregion

#region UI Components - Colony Section
@onready var colony_section: VBoxContainer = %ColonySection
@onready var ant_count_label: Label = %AntCountLabel
@onready var food_collected_label: Label = %FoodCollectedLabel
@onready var radius_label: Label = %RadiusLabel
@onready var spawn_count_spin: SpinBox = %SpawnCountSpin
@onready var profile_option: OptionButton = %ProfileOption
@onready var spawn_button: Button = %SpawnButton
@onready var radius_spin: SpinBox = %RadiusSpin
@onready var max_ants_spin: SpinBox = %MaxAntsSpin
@onready var spawn_rate_spin: SpinBox = %SpawnRateSpin
@onready var dirt_color_picker: ColorPickerButton = %DirtColorPicker
@onready var darker_dirt_color_picker: ColorPickerButton = %DarkerDirtColorPicker
@onready var colony_ant_profiles_list: ItemList = %ColonyAntProfilesList
@onready var edit_colony_ant_profile_button: Button = %EditColonyAntProfileButton
#endregion

#region UI Components - Visualization (shared)
@onready var show_heatmap_check: CheckButton = %ShowHeatmapCheck
@onready var nav_debug_check: CheckButton = %NavDebugCheck
@onready var highlight_check: CheckButton = %HighlightCheck
@onready var show_influence_vectors_check: CheckButton = %ShowInfluenceVectorsCheck
#endregion


func _ready() -> void:
	custom_minimum_size = STYLE.PANEL_SIZE
	hide()
	heatmap = get_tree().get_first_node_in_group("heatmap")
	top_level = true
	
	_setup_styling()
	_connect_signals()
	_setup_scroll_handling()


func _setup_scroll_handling() -> void:
	## Consume scroll events to prevent camera zoom
	scroll_container.gui_input.connect(_on_scroll_gui_input)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _on_scroll_gui_input(event: InputEvent) -> void:
	## Stop scroll events from propagating to camera
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			accept_event()


func _gui_input(event: InputEvent) -> void:
	## Stop all mouse events from propagating to camera
	if event is InputEventMouseButton:
		accept_event()


func _connect_signals() -> void:
	close_button.pressed.connect(_on_close_pressed)
	
	# Ant signals
	edit_ant_profile_button.pressed.connect(_on_edit_ant_profile_pressed)
	view_influence_profile_button.pressed.connect(_on_view_influence_profile_pressed)
	
	# Colony signals
	spawn_button.pressed.connect(_on_spawn_pressed)
	profile_option.item_selected.connect(_on_profile_selected)
	radius_spin.value_changed.connect(_on_radius_changed)
	max_ants_spin.value_changed.connect(_on_max_ants_changed)
	spawn_rate_spin.value_changed.connect(_on_spawn_rate_changed)
	dirt_color_picker.color_changed.connect(_on_dirt_color_changed)
	darker_dirt_color_picker.color_changed.connect(_on_darker_dirt_changed)
	colony_ant_profiles_list.item_selected.connect(_on_colony_ant_profile_selected)
	edit_colony_ant_profile_button.pressed.connect(_on_edit_colony_ant_profile_pressed)
	
	# Visualization signals
	show_heatmap_check.toggled.connect(_on_show_heatmap_toggled)
	nav_debug_check.toggled.connect(_on_nav_debug_toggled)
	highlight_check.toggled.connect(_on_highlight_toggled)
	show_influence_vectors_check.toggled.connect(_on_show_influence_vectors_toggled)


func _setup_styling() -> void:
	health_bar.add_theme_stylebox_override("fill", _create_stylebox(STYLE.HEALTH_COLOR))
	health_bar.add_theme_stylebox_override("background", _create_stylebox(STYLE.BAR_BG_COLOR))
	energy_bar.add_theme_stylebox_override("fill", _create_stylebox(STYLE.ENERGY_COLOR))
	energy_bar.add_theme_stylebox_override("background", _create_stylebox(STYLE.BAR_BG_COLOR))


func _create_stylebox(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style


func _process(_delta: float) -> void:
	if not is_visible() or not is_instance_valid(current_entity):
		return
	
	if current_entity is Ant:
		_update_ant_info()
	elif current_entity is Colony:
		_update_colony_info()
	
	queue_redraw()


#region Public Methods
func show_entity_info(entity: Node) -> void:
	if not entity:
		return
	
	current_entity = entity
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	
	if entity is Ant:
		_setup_ant_view(entity)
	elif entity is Colony:
		_setup_colony_view(entity)
	
	show()
	queue_redraw()


func get_current_ant() -> Ant:
	if current_entity is Ant:
		return current_entity as Ant
	return null


func get_current_colony() -> Colony:
	if current_entity is Colony:
		return current_entity as Colony
	return null
#endregion


#region Ant View Setup
func _setup_ant_view(ant: Ant) -> void:
	ant_section.visible = true
	colony_section.visible = false
	
	title_label.text = "Ant #%d" % ant.id
	colony_label.text = "Colony: %s" % (str(ant.colony.name) if ant.colony else "None")
	
	# Show ant-specific visualization options
	show_influence_vectors_check.visible = true
	highlight_check.visible = false
	highlight_check.text = "Show Nav Path"
	
	_update_ant_profile_section()
	_update_movement_influences_section()
	_update_status_bars()
	_sync_ant_visualization()
	
	food_label.text = "Carrying Food: %s" % ("Yes" if ant.is_carrying_food else "No")
	
	# Automatically enable influence arrows when viewing ant info
	_enable_influence_visualization(ant)


func _enable_influence_visualization(ant: Ant) -> void:
	## Automatically show influence arrows when ant info panel opens
	if ant and ant.influence_manager:
		ant.influence_manager.set_visualization_enabled(true)
		show_influence_vectors_check.button_pressed = true
		_influence_vis_enabled_by_panel = true


func _disable_influence_visualization() -> void:
	## Disable influence arrows when panel closes (if we enabled them)
	if _influence_vis_enabled_by_panel and current_entity is Ant:
		var ant := current_entity as Ant
		if is_instance_valid(ant) and ant.influence_manager:
			ant.influence_manager.set_visualization_enabled(false)
		_influence_vis_enabled_by_panel = false


func _update_ant_info() -> void:
	var ant := current_entity as Ant
	if not ant:
		return
	
	_update_status_bars()
	food_label.text = "Carrying Food: %s" % ("Yes" if ant.is_carrying_food else "No")
	role_label.text = "Role: %s" % ant.role
	_update_movement_influences_section()
	
	# Update legend every 20 physics frames
	if Engine.get_physics_frames() % 20 == 0:
		if ant.influence_manager and ant.influence_manager.active_profile:
			_update_legend(ant.influence_manager.active_profile.influences)


func _update_ant_profile_section() -> void:
	var ant := current_entity as Ant
	if not ant or not ant.profile:
		ant_profile_name_label.text = "Profile: None"
		edit_ant_profile_button.disabled = true
		return
	
	ant_profile_name_label.text = "Profile: %s" % ant.profile.name
	edit_ant_profile_button.disabled = false


func _update_movement_influences_section() -> void:
	var ant := current_entity as Ant
	if not ant or not ant.influence_manager:
		active_profile_label.text = "Active: None"
		view_influence_profile_button.disabled = true
		return
	
	var active = ant.influence_manager.active_profile
	if active:
		active_profile_label.text = "Active: %s" % active.name
		view_influence_profile_button.disabled = false
	else:
		active_profile_label.text = "Active: None"
		view_influence_profile_button.disabled = true


func _update_status_bars() -> void:
	var ant := current_entity as Ant
	if not ant:
		return
	
	var health_percent = (ant.health_level / ant.health_max) * 100.0
	health_bar.value = health_percent
	health_value_label.text = "%d/%d" % [ant.health_level, ant.health_max]
	_update_bar_color(health_bar, health_percent, STYLE.HEALTH_COLOR)
	
	var energy_percent = (ant.energy_level / ant.energy_max) * 100.0
	energy_bar.value = energy_percent
	energy_value_label.text = "%d/%d" % [ant.energy_level, ant.energy_max]
	_update_bar_color(energy_bar, energy_percent, STYLE.ENERGY_COLOR)


func _update_bar_color(bar: ProgressBar, value: float, normal_color: Color) -> void:
	var style = bar.get_theme_stylebox("fill") as StyleBoxFlat
	if value > 66:
		style.bg_color = normal_color
	elif value > 33:
		style.bg_color = STYLE.MED_COLOR
	else:
		style.bg_color = STYLE.LOW_COLOR


func _sync_ant_visualization() -> void:
	var ant := current_entity as Ant
	if not ant:
		return
	
	nav_debug_check.button_pressed = ant.nav_agent.debug_enabled if ant.nav_agent else false
	show_influence_vectors_check.button_pressed = ant.influence_manager.is_visualization_enabled() if ant.influence_manager else false
#endregion


#region Colony View Setup
func _setup_colony_view(colony: Colony) -> void:
	ant_section.visible = false
	colony_section.visible = true
	
	title_label.text = colony.name
	
	# Show colony-specific visualization options
	show_influence_vectors_check.visible = false
	highlight_check.visible = true
	highlight_check.text = "Highlight Ants"
	
	_update_colony_info()
	_populate_spawn_profiles(colony)
	_sync_colony_profile_controls(colony)
	_populate_colony_ant_profiles_list()
	_sync_colony_visualization(colony)


func _update_colony_info() -> void:
	var colony: Colony = current_entity as Colony
	if not colony:
		return
	
	ant_count_label.text = "Ants: %d" % [colony.ants.size()]
	food_collected_label.text = "Food Collected: %.1f units" % colony.foods.count
	radius_label.text = "Colony Radius: %.1f" % colony.radius


func _populate_spawn_profiles(colony: Colony) -> void:
	profile_option.clear()
	_profile_map.clear()
	
	if not colony.profile:
		return
	
	var idx := 0
	for ant_profile in colony.profile.ant_profiles:
		profile_option.add_item(ant_profile.name)
		_profile_map[idx] = ant_profile
		idx += 1
	
	if profile_option.item_count > 0:
		profile_option.selected = 0


func _sync_colony_profile_controls(colony: Colony) -> void:
	if not colony.profile:
		return
	
	radius_spin.value = colony.profile.radius
	max_ants_spin.value = colony.profile.max_ants
	spawn_rate_spin.value = colony.profile.spawn_rate
	dirt_color_picker.color = colony.profile.dirt_color
	darker_dirt_color_picker.color = colony.profile.darker_dirt


func _populate_colony_ant_profiles_list() -> void:
	colony_ant_profiles_list.clear()
	
	var colony := current_entity as Colony
	if not colony or not colony.profile:
		return
	
	for i in range(colony.profile.ant_profiles.size()):
		var ant_profile = colony.profile.ant_profiles[i]
		var initial_count = colony.profile.initial_ants.get(ant_profile.name, 0)
		colony_ant_profiles_list.add_item("%s (initial: %d)" % [ant_profile.name, initial_count])
	
	edit_colony_ant_profile_button.disabled = true


func _sync_colony_visualization(colony: Colony) -> void:
	show_heatmap_check.button_pressed = colony.heatmap_enabled
	highlight_check.button_pressed = colony.highlight_ants_enabled
	nav_debug_check.button_pressed = colony.nav_debug_enabled
#endregion


#region Legend Management
func _clear_legend() -> void:
	for child in influences_legend.get_children():
		child.queue_free()
	_influence_colors.clear()


func _update_legend(influences: Array) -> void:
	_clear_legend()
	
	var ant := current_entity as Ant
	if not ant or not is_instance_valid(ant):
		return
	
	var total_magnitude = 0.0
	var influence_data = []
	
	for logic in influences:
		var influence := logic as Influence
		if not influence:
			continue
			
		if _should_ignore_influence(influence):
			continue
		
		if not influence.is_valid(ant):
			continue
		
		var direction = EvaluationSystem.get_value(influence, ant)
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
	
	_add_legend_entry("Overall", STYLE.INFLUENCE_SETTINGS.OVERALL_COLOR, 1.0)
	
	var separator = HSeparator.new()
	influences_legend.add_child(separator)
	
	for data in influence_data:
		var influence = data.influence
		var normalized_weight = data.magnitude / total_magnitude if total_magnitude > 0 else 0.0
		_add_legend_entry(
			influence.name,
			influence.color,
			normalized_weight
		)


func _add_legend_entry(p_name: String, color: Color, normalized_weight: float) -> void:
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


#region Signal Handlers - Ant
func _on_edit_ant_profile_pressed() -> void:
	var ant := current_entity as Ant
	if not ant or not ant.profile:
		return
	
	var editor = AntProfileEditorPopup.new()
	add_child(editor)
	editor.edit_profile(ant.profile)
	await editor.closed
	_update_ant_profile_section()


func _on_view_influence_profile_pressed() -> void:
	var ant := current_entity as Ant
	if not ant or not ant.influence_manager:
		return
	
	var active = ant.influence_manager.active_profile
	if not active:
		return
	
	var popup = InfluenceProfileViewPopup.new()
	add_child(popup)
	popup.show_profile(active)
#endregion


#region Signal Handlers - Colony Spawn
func _on_spawn_pressed() -> void:
	var colony := current_entity as Colony
	if not colony:
		return
	
	var count = int(spawn_count_spin.value)
	var selected_idx = profile_option.selected
	var selected_profile: AntProfile = _profile_map.get(selected_idx)
	
	if selected_profile:
		var ants = colony.spawn_ants(count, selected_profile)
		for ant in ants:
			if not ant.is_inside_tree():
				var ant_container = get_tree().get_first_node_in_group("ant_container")
				if ant_container:
					ant_container.add_child(ant)
		spawn_requested.emit(colony, count, selected_profile)


func _on_profile_selected(_index: int) -> void:
	pass
#endregion


#region Signal Handlers - Colony Profile
func _on_radius_changed(value: float) -> void:
	var colony := current_entity as Colony
	if colony and colony.profile:
		colony.profile.radius = value
		colony.radius = value
		colony.queue_redraw()


func _on_max_ants_changed(value: float) -> void:
	var colony := current_entity as Colony
	if colony and colony.profile:
		colony.profile.max_ants = int(value)


func _on_spawn_rate_changed(value: float) -> void:
	var colony := current_entity as Colony
	if colony and colony.profile:
		colony.profile.spawn_rate = value


func _on_dirt_color_changed(color: Color) -> void:
	var colony := current_entity as Colony
	if colony and colony.profile:
		colony.profile.dirt_color = color
		colony.dirt_color = color
		colony.queue_redraw()


func _on_darker_dirt_changed(color: Color) -> void:
	var colony := current_entity as Colony
	if colony and colony.profile:
		colony.profile.darker_dirt = color
		colony.darker_dirt = color
		colony.queue_redraw()
#endregion


#region Signal Handlers - Colony Ant Profiles
func _on_colony_ant_profile_selected(index: int) -> void:
	edit_colony_ant_profile_button.disabled = index < 0


func _on_edit_colony_ant_profile_pressed() -> void:
	var colony := current_entity as Colony
	var selected_indices = colony_ant_profiles_list.get_selected_items()
	if selected_indices.is_empty() or not colony or not colony.profile:
		return
	
	var profile_idx = selected_indices[0]
	if profile_idx < colony.profile.ant_profiles.size():
		var ant_profile = colony.profile.ant_profiles[profile_idx]
		_open_ant_profile_editor(ant_profile)


func _open_ant_profile_editor(ant_profile: AntProfile) -> void:
	var editor = AntProfileEditorPopup.new()
	add_child(editor)
	editor.edit_profile(ant_profile)
	await editor.closed
	_populate_colony_ant_profiles_list()
#endregion


#region Signal Handlers - Visualization
func _on_show_heatmap_toggled(enabled: bool) -> void:
	if current_entity is Ant:
		var ant := current_entity as Ant
		if enabled: # FIXME heatmap is null
			HeatmapManager.debug_draw(ant, true)
		else:
			HeatmapManager.debug_draw(ant, false)
	elif current_entity is Colony:
		var colony := current_entity as Colony
		colony.heatmap_enabled = enabled


func _on_nav_debug_toggled(enabled: bool) -> void:
	if current_entity is Ant:
		var ant := current_entity as Ant
		if ant.nav_agent:
			ant.nav_agent.debug_enabled = enabled
	elif current_entity is Colony:
		var colony := current_entity as Colony
		colony.nav_debug_enabled = enabled
		for ant in colony.ants:
			if ant.nav_agent:
				ant.nav_agent.debug_enabled = enabled


func _on_highlight_toggled(enabled: bool) -> void:
	if current_entity is Colony:
		var colony := current_entity as Colony
		colony.highlight_ants_enabled = enabled
		highlight_ants.emit(colony, enabled)


func _on_show_influence_vectors_toggled(toggled_on: bool) -> void:
	if current_entity is Ant:
		var ant := current_entity as Ant
		if ant.influence_manager:
			ant.influence_manager.set_visualization_enabled(toggled_on)
			# Track if we're toggling off manually
			if not toggled_on:
				_influence_vis_enabled_by_panel = false
#endregion


#region Signal Handlers - Panel
func _on_close_pressed() -> void:
	_disable_influence_visualization()
	closed.emit()
	queue_free()
#endregion


func _exit_tree() -> void:
	_disable_influence_visualization()
	
	if current_entity is Ant:
		var ant := current_entity as Ant
		if is_instance_valid(ant):
			if ant.nav_agent:
				ant.nav_agent.debug_enabled = false
			if heatmap:
				heatmap.debug_draw(ant, false)
	
	current_entity = null
