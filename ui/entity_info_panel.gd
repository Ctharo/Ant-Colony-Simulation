class_name EntityInfoPanel
extends DraggablePanel

signal highlight_ants(colony: Colony, enable: bool)
signal spawn_requested(colony: Colony, count: int, profile: AntProfile)
signal closed

#region Constants
const STYLE: Dictionary = {
	"PANEL_SIZE": Vector2(340, 700),
	"PANEL_MIN_SIZE": Vector2(340, 400),
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
const ANT_HIGHLIGHT_RADIUS: float = 12.0
const ANT_HIGHLIGHT_COLOR: Color = Color(Color.WHITE, 0.5)
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
@onready var header_container: HBoxContainer = %HeaderContainer
@onready var title_label: Label = %TitleLabel
@onready var collapse_button: Button = %CollapseButton
@onready var close_button: Button = %CloseButton
@onready var content_container: VBoxContainer = %ContentContainer
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


#region DraggablePanel Overrides
func _get_content_container() -> Control:
	return content_container


func _get_header_container() -> Control:
	return header_container


func _get_collapse_button() -> Button:
	return collapse_button


func _get_default_position() -> Vector2:
	## Position on right side of screen with padding
	var viewport_size: Vector2 = get_viewport_rect().size
	return Vector2(viewport_size.x - STYLE.PANEL_SIZE.x - EDGE_PADDING, EDGE_PADDING)


func _on_panel_ready() -> void:
	custom_minimum_size = STYLE.PANEL_MIN_SIZE
	hide()
	heatmap = get_tree().get_first_node_in_group("heatmap")

	_setup_styling()
	_connect_signals()
	_setup_scroll_handling()
#endregion


#region Setup
func _setup_scroll_handling() -> void:
	## Consume scroll events to prevent camera zoom
	scroll_container.gui_input.connect(_on_scroll_gui_input)


func _on_scroll_gui_input(event: InputEvent) -> void:
	## Stop scroll events from propagating to camera
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
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
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style
#endregion


#region Process
func _process(_delta: float) -> void:
	if not is_visible() or not is_instance_valid(current_entity):
		return

	if current_entity is Ant:
		_update_ant_info()
	elif current_entity is Colony:
		_update_colony_info()

	queue_redraw()
#endregion


#region Public Methods
func show_entity_info(entity: Node) -> void:
	if not entity:
		return

	current_entity = entity

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
	## Disable influence visualization if we enabled it
	if _influence_vis_enabled_by_panel and current_entity is Ant:
		var ant: Ant = current_entity as Ant
		if is_instance_valid(ant) and ant.influence_manager:
			ant.influence_manager.set_visualization_enabled(false)
		_influence_vis_enabled_by_panel = false


func _update_ant_profile_section() -> void:
	if not current_entity is Ant:
		return
	var ant: Ant = current_entity as Ant
	ant_profile_name_label.text = "Profile: %s" % (ant.profile.name if ant.profile else "None")


func _update_movement_influences_section() -> void:
	if not current_entity is Ant:
		return
	var ant: Ant = current_entity as Ant

	if ant.influence_manager and ant.influence_manager.active_profile:
		active_profile_label.text = "Active: %s" % ant.influence_manager.active_profile.name
	else:
		active_profile_label.text = "Active: None"


func _update_status_bars() -> void:
	if not current_entity is Ant:
		return
	var ant: Ant = current_entity as Ant

	health_bar.max_value = ant.health_max
	health_bar.value = ant.health_level
	health_value_label.text = "%d/%d" % [int(ant.health_level), int(ant.health_max)]

	energy_bar.max_value = ant.energy_max
	energy_bar.value = ant.energy_level
	energy_value_label.text = "%d/%d" % [int(ant.energy_level), int(ant.energy_max)]

	_update_bar_colors()


func _update_bar_colors() -> void:
	if not current_entity is Ant:
		return
	var ant: Ant = current_entity as Ant

	var health_pct: float = ant.health_level / ant.health_max
	var energy_pct: float = ant.energy_level / ant.energy_max

	var health_color: Color = STYLE.HEALTH_COLOR
	if health_pct < 0.25:
		health_color = STYLE.LOW_COLOR
	elif health_pct < 0.5:
		health_color = STYLE.MED_COLOR

	var energy_color: Color = STYLE.ENERGY_COLOR
	if energy_pct < 0.25:
		energy_color = STYLE.LOW_COLOR
	elif energy_pct < 0.5:
		energy_color = STYLE.MED_COLOR

	health_bar.add_theme_stylebox_override("fill", _create_stylebox(health_color))
	energy_bar.add_theme_stylebox_override("fill", _create_stylebox(energy_color))


func _sync_ant_visualization() -> void:
	if not current_entity is Ant:
		return
	var ant: Ant = current_entity as Ant

	nav_debug_check.button_pressed = ant.nav_agent.debug_enabled if ant.nav_agent else false
	show_influence_vectors_check.button_pressed = ant.influence_manager.is_visualization_enabled() if ant.influence_manager else false
#endregion


#region Colony View Setup
func _setup_colony_view(colony: Colony) -> void:
	ant_section.visible = false
	colony_section.visible = true

	title_label.text = "Colony: %s" % colony.name

	# Hide ant-specific options
	show_influence_vectors_check.visible = false
	highlight_check.visible = true
	highlight_check.text = "Highlight Ants"

	_populate_profile_options()
	_sync_colony_values(colony)
	_populate_colony_ant_profiles_list()


func _populate_profile_options() -> void:
	profile_option.clear()
	_profile_map.clear()

	var dir: DirAccess = DirAccess.open("res://resources/profiles/ant")
	if not dir:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	var idx: int = 0
	while file_name != "":
		if file_name.ends_with(".tres"):
			var profile: AntProfile = load("res://resources/profiles/ant/" + file_name) as AntProfile
			if profile:
				profile_option.add_item(profile.name, idx)
				_profile_map[idx] = profile
				idx += 1
		file_name = dir.get_next()


func _sync_colony_values(colony: Colony) -> void:
	if not colony.profile:
		return

	radius_spin.value = colony.radius
	max_ants_spin.value = colony.profile.max_ants
	spawn_rate_spin.value = colony.profile.spawn_rate
	dirt_color_picker.color = colony.profile.dirt_color

	show_heatmap_check.button_pressed = colony.heatmap_enabled
	nav_debug_check.button_pressed = colony.nav_debug_enabled
	highlight_check.button_pressed = colony.highlight_ants_enabled


func _populate_colony_ant_profiles_list() -> void:
	colony_ant_profiles_list.clear()

	var colony: Colony = current_entity as Colony
	if not colony or not colony.profile:
		return

	for ant_profile: AntProfile in colony.profile.ant_profiles:
		var count: int = colony.profile.initial_ants.get(ant_profile.resource_path, 0)
		colony_ant_profiles_list.add_item("%s (initial: %d)" % [ant_profile.name, count])
#endregion


#region Update Methods
func _update_ant_info() -> void:
	if not current_entity is Ant:
		return
	var ant: Ant = current_entity as Ant

	if not is_instance_valid(ant):
		_on_close_pressed()
		return

	food_label.text = "Carrying Food: %s" % ("Yes" if ant.is_carrying_food else "No")
	_update_status_bars()
	_update_movement_influences_section()
	_update_legend()


func _update_colony_info() -> void:
	if not current_entity is Colony:
		return
	var colony: Colony = current_entity as Colony

	if not is_instance_valid(colony):
		_on_close_pressed()
		return

	ant_count_label.text = "Ants: %d / %d" % [colony.ants.size(), colony.profile.max_ants if colony.profile else 0]
	food_collected_label.text = "Food: %.1f units" % (colony.foods.mass if colony.foods else 0.0)
	radius_label.text = "Radius: %.1f" % colony.radius
#endregion


#region Legend Management
func _update_legend() -> void:
	if not current_entity is Ant:
		return
	var ant: Ant = current_entity as Ant

	if not ant.influence_manager or not ant.influence_manager.active_profile:
		_clear_legend()
		return

	# Only update periodically
	if Engine.get_physics_frames() % 20 != 0:
		return

	_build_legend(ant.influence_manager.active_profile.influences)


func _clear_legend() -> void:
	for child: Node in influences_legend.get_children():
		child.queue_free()
	_influence_colors.clear()


func _build_legend(influences: Array) -> void:
	_clear_legend()

	var ant: Ant = current_entity as Ant
	if not ant or not is_instance_valid(ant):
		return

	for influence: Variant in influences:
		if not influence is Influence:
			continue
		var inf: Influence = influence as Influence

		if inf.influence_type in STYLE.INFLUENCE_SETTINGS.IGNORE_TYPES:
			continue

		if not inf.is_valid(ant):
			continue

		var color: Color = _get_influence_color(inf.name)
		var row: HBoxContainer = HBoxContainer.new()

		var color_rect: ColorRect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(16, 16)
		color_rect.color = color
		row.add_child(color_rect)

		var label: Label = Label.new()
		label.text = " %s" % inf.name
		row.add_child(label)

		influences_legend.add_child(row)


func _get_influence_color(influence_name: String) -> Color:
	if not _influence_colors.has(influence_name):
		var hue: float = hash(influence_name) % 360 / 360.0
		_influence_colors[influence_name] = Color.from_hsv(hue, 0.7, 0.9)
	return _influence_colors[influence_name]
#endregion


#region Signal Handlers - Ant
func _on_edit_ant_profile_pressed() -> void:
	if not current_entity is Ant:
		return
	var ant: Ant = current_entity as Ant

	if not ant.profile:
		return

	var editor: AntProfileEditorPopup = AntProfileEditorPopup.new()
	add_child(editor)
	editor.edit_profile(ant.profile)
	await editor.closed


func _on_view_influence_profile_pressed() -> void:
	if not current_entity is Ant:
		return
	var ant: Ant = current_entity as Ant

	if not ant.influence_manager or not ant.influence_manager.active_profile:
		return

	var popup: InfluenceProfileViewPopup = InfluenceProfileViewPopup.new()
	add_child(popup)
	popup.show_profile(ant.influence_manager.active_profile)
#endregion


#region Signal Handlers - Colony
func _on_spawn_pressed() -> void:
	if not current_entity is Colony:
		return
	var colony: Colony = current_entity as Colony

	var count: int = int(spawn_count_spin.value)
	var selected_idx: int = profile_option.selected
	var profile: AntProfile = _profile_map.get(selected_idx) as AntProfile

	spawn_requested.emit(colony, count, profile)


func _on_profile_selected(_index: int) -> void:
	pass


func _on_radius_changed(value: float) -> void:
	if not current_entity is Colony:
		return
	var colony: Colony = current_entity as Colony
	colony.radius = value


func _on_max_ants_changed(value: float) -> void:
	if not current_entity is Colony:
		return
	var colony: Colony = current_entity as Colony
	if colony.profile:
		colony.profile.max_ants = int(value)


func _on_spawn_rate_changed(value: float) -> void:
	if not current_entity is Colony:
		return
	var colony: Colony = current_entity as Colony
	if colony.profile:
		colony.profile.spawn_rate = value


func _on_dirt_color_changed(color: Color) -> void:
	if not current_entity is Colony:
		return
	var colony: Colony = current_entity as Colony
	if colony.profile:
		colony.profile.dirt_color = color
		colony.queue_redraw()


func _on_darker_dirt_changed(color: Color) -> void:
	if not current_entity is Colony:
		return
	var colony: Colony = current_entity as Colony
	if colony.profile:
		colony.profile.darker_dirt_color = color
		colony.queue_redraw()
#endregion


#region Signal Handlers - Colony Ant Profiles
func _on_colony_ant_profile_selected(index: int) -> void:
	edit_colony_ant_profile_button.disabled = index < 0


func _on_edit_colony_ant_profile_pressed() -> void:
	var colony: Colony = current_entity as Colony
	var selected_indices: PackedInt32Array = colony_ant_profiles_list.get_selected_items()
	if selected_indices.is_empty() or not colony or not colony.profile:
		return

	var profile_idx: int = selected_indices[0]
	if profile_idx < colony.profile.ant_profiles.size():
		var ant_profile: AntProfile = colony.profile.ant_profiles[profile_idx]
		_open_ant_profile_editor(ant_profile)


func _open_ant_profile_editor(ant_profile: AntProfile) -> void:
	var editor: AntProfileEditorPopup = AntProfileEditorPopup.new()
	add_child(editor)
	editor.edit_profile(ant_profile)
	await editor.closed
	_populate_colony_ant_profiles_list()
#endregion


#region Signal Handlers - Visualization
func _on_show_heatmap_toggled(enabled: bool) -> void:
	if current_entity is Ant:
		var ant: Ant = current_entity as Ant
		if enabled:
			HeatmapManager.debug_draw(ant, true)
		else:
			HeatmapManager.debug_draw(ant, false)
	elif current_entity is Colony:
		var colony: Colony = current_entity as Colony
		colony.heatmap_enabled = enabled


func _on_nav_debug_toggled(enabled: bool) -> void:
	if current_entity is Ant:
		var ant: Ant = current_entity as Ant
		if ant.nav_agent:
			ant.nav_agent.debug_enabled = enabled
	elif current_entity is Colony:
		var colony: Colony = current_entity as Colony
		colony.nav_debug_enabled = enabled
		for ant: Ant in colony.ants:
			if ant.nav_agent:
				ant.nav_agent.debug_enabled = enabled


func _on_highlight_toggled(enabled: bool) -> void:
	if current_entity is Colony:
		var colony: Colony = current_entity as Colony
		colony.highlight_ants_enabled = enabled
		highlight_ants.emit(colony, enabled)


func _on_show_influence_vectors_toggled(toggled_on: bool) -> void:
	if current_entity is Ant:
		var ant: Ant = current_entity as Ant
		if ant.influence_manager:
			ant.influence_manager.set_visualization_enabled(toggled_on)
			if not toggled_on:
				_influence_vis_enabled_by_panel = false
#endregion


#region Signal Handlers - Panel
func _on_close_pressed() -> void:
	_disable_influence_visualization()
	closed.emit()
	queue_free()
#endregion


#region Cleanup
func _exit_tree() -> void:
	_disable_influence_visualization()

	if current_entity is Ant:
		var ant: Ant = current_entity as Ant
		if is_instance_valid(ant):
			if ant.nav_agent:
				ant.nav_agent.debug_enabled = false
			if heatmap:
				heatmap.debug_draw(ant, false)

	current_entity = null
#endregion
