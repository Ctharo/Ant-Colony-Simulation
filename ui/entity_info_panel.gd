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
## Tracks if show was requested before panel was ready
var _pending_show: bool = false
## Tracks if panel initialization is complete
var _panel_ready: bool = false
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
var _rules_container: VBoxContainer
var _movement_label: Label
var _last_fired_label: Label
var _rule_checks: Dictionary = {}  # ProfileEntry -> CheckBox
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
	heatmap = get_tree().get_first_node_in_group("heatmap")

	_setup_styling()
	_connect_signals()
	_setup_scroll_handling()
	_build_behavior_rules_section()

	# Retired editors: these buttons' destinations are gone until E3
	# repoints them (behavior editor / designer). Hidden, not removed, so
	# the scene keeps its nodes.
	edit_ant_profile_button.visible = false
	view_influence_profile_button.visible = false
	edit_colony_ant_profile_button.visible = false

	_panel_ready = true

	if _pending_show and current_entity:
		_run_entity_setup(current_entity)  # ← now @onready refs are valid
		_pending_show = false
		show()
	else:
		hide()
#endregion


#region Setup
func _setup_scroll_handling() -> void:
	## Consume scroll events to prevent camera zoom
	scroll_container.gui_input.connect(_on_scroll_gui_input)


func _on_scroll_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		return

	var v_bar: VScrollBar = scroll_container.get_v_scroll_bar()

	# Nothing to scroll — swallow the wheel so the camera doesn't zoom
	if not v_bar.visible:
		accept_event()
		return

	var at_top: bool = v_bar.value <= v_bar.min_value
	var at_bottom: bool = v_bar.value >= v_bar.max_value - v_bar.page

	if (event.button_index == MOUSE_BUTTON_WHEEL_UP and at_top) \
			or (event.button_index == MOUSE_BUTTON_WHEEL_DOWN and at_bottom):
		# Container can't scroll further in this direction; eat the
		# event before it leaks through to camera zoom.
		accept_event()
	# Otherwise: do nothing. The ScrollContainer's own handling runs
	# next, scrolls, and accepts the event itself.


func _connect_signals() -> void:
	close_button.pressed.connect(_on_close_pressed)

	## Ant signals
	view_influence_profile_button.pressed.connect(_on_view_influence_profile_pressed)

	## Colony signals
	spawn_button.pressed.connect(_on_spawn_pressed)
	profile_option.item_selected.connect(_on_profile_selected)
	radius_spin.value_changed.connect(_on_radius_changed)
	max_ants_spin.value_changed.connect(_on_max_ants_changed)
	spawn_rate_spin.value_changed.connect(_on_spawn_rate_changed)
	dirt_color_picker.color_changed.connect(_on_dirt_color_changed)
	darker_dirt_color_picker.color_changed.connect(_on_darker_dirt_changed)
	colony_ant_profiles_list.item_selected.connect(_on_colony_ant_profile_selected)

	## Visualization signals
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

	if not _panel_ready:
		_pending_show = true
		return  # Setup will run once _on_panel_ready fires

	_run_entity_setup(entity)
	show()
	queue_redraw()


func _run_entity_setup(entity: Node) -> void:
	if entity is Ant:
		_setup_ant_view(entity)
	elif entity is Colony:
		_setup_colony_view(entity)

func get_current_ant() -> Ant:
	if current_entity is Ant:
		return current_entity as Ant
	return null


func get_current_colony() -> Colony:
	if current_entity is Colony:
		return current_entity as Colony
	return null
#endregion

#region Behaviors Section
func _build_behavior_rules_section() -> void:
	_rules_container = VBoxContainer.new()
	_rules_container.add_theme_constant_override("separation", 4)
	ant_section.add_child(_rules_container)


func _refresh_behavior_rules() -> void:
	for child: Node in _rules_container.get_children():
		child.queue_free()
	_rule_checks.clear()

	var ant: Ant = get_current_ant()
	if not ant or not ant.behavior_manager:
		return

	var header: Label = Label.new()
	header.text = "Behaviors"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rules_container.add_child(header)

	var manager: BehaviorManager = ant.behavior_manager
	if manager.profile == null:
		var empty_label: Label = Label.new()
		empty_label.text = "No behavior profile assigned."
		empty_label.modulate = Color(1, 1, 1, 0.6)
		_rules_container.add_child(empty_label)
	else:
		for entry: ProfileEntry in manager.profile.sorted_entries():
			if entry == null or entry.behavior == null:
				continue
			var behavior: AntBehavior = entry.behavior
			var check: CheckBox = CheckBox.new()
			check.text = "[%d] %s  (%s)" % [
				entry.priority, behavior.name, behavior.channel_id()]
			check.tooltip_text = behavior.description
			# Reflect both layers: profile entry state AND this ant's override
			check.button_pressed = entry.enabled and manager.is_entry_enabled_local(entry)
			check.disabled = not entry.enabled  # profile-disabled: can't re-enable per-ant
			check.toggled.connect(func(pressed: bool) -> void:
				if is_instance_valid(ant) and ant.behavior_manager:
					ant.behavior_manager.set_entry_enabled_local(entry, pressed)
			)
			_rules_container.add_child(check)
			_rule_checks[entry] = check

	_movement_label = Label.new()
	_movement_label.text = "Movement: —"
	_movement_label.add_theme_font_size_override("font_size", 11)
	_movement_label.modulate = Color(1, 1, 1, 0.6)
	_rules_container.add_child(_movement_label)

	_last_fired_label = Label.new()
	_last_fired_label.text = "Last fired: —"
	_last_fired_label.add_theme_font_size_override("font_size", 11)
	_last_fired_label.modulate = Color(1, 1, 1, 0.6)
	_rules_container.add_child(_last_fired_label)

	if not manager.behavior_fired.is_connected(_on_behavior_fired):
		manager.behavior_fired.connect(_on_behavior_fired)
	if not manager.movement_behavior_changed.is_connected(_on_movement_behavior_changed):
		manager.movement_behavior_changed.connect(_on_movement_behavior_changed)
	if not manager.profile_changed.is_connected(_refresh_behavior_rules):
		manager.profile_changed.connect(_refresh_behavior_rules)


## Exclusive-channel fires only: concurrent behaviors (signaling) fire every
## tick and would drown the label with no information gained.
func _on_behavior_fired(behavior: AntBehavior) -> void:
	if behavior.channel and not behavior.channel.is_exclusive():
		return
	if is_instance_valid(_last_fired_label):
		_last_fired_label.text = "Last fired: %s" % behavior.name


func _on_movement_behavior_changed(behavior: AntBehavior) -> void:
	if not is_instance_valid(_movement_label):
		return
	if behavior == null:
		_movement_label.text = "Movement: — (idle)"
	else:
		_movement_label.text = "Movement: %s" % behavior.name
#endregion
#region Ant View Setup
func _setup_ant_view(ant: Ant) -> void:
	ant_section.visible = true
	colony_section.visible = false

	## Set title and basic info - THIS WAS MISSING ROLE_LABEL
	title_label.text = "Ant #%d" % ant.id
	role_label.text = "Role: %s" % ant.role
	colony_label.text = "Colony: %s" % (str(ant.colony.name) if ant.colony else "None")
	food_label.text = "Carrying Food: %s" % ("Yes" if ant.is_carrying_food else "No")

	## Show ant-specific visualization options
	show_influence_vectors_check.visible = true
	highlight_check.visible = false
	highlight_check.text = "Show Nav Path"

	## Update all sections
	_update_ant_profile_section()
	_update_movement_influences_section()
	_update_status_bars()
	_sync_ant_visualization()
	_refresh_behavior_rules()

	## Automatically enable influence arrows when viewing ant info
	_enable_influence_visualization(ant)


func _enable_influence_visualization(ant: Ant) -> void:
	## Automatically show influence arrows when ant info panel opens
	if ant and ant.influence_manager:
		ant.influence_manager.set_visualization_enabled(true)
		show_influence_vectors_check.button_pressed = true
		_influence_vis_enabled_by_panel = true


func _disable_influence_visualization() -> void:
	## Disable influence visualization if we enabled it
	if _influence_vis_enabled_by_panel and is_instance_valid(current_entity) and current_entity is Ant:
		var ant: Ant = current_entity as Ant
		if ant.influence_manager:
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

	var winner: AntBehavior = null
	if ant.behavior_manager:
		winner = ant.behavior_manager.movement_behavior()
	if winner:
		active_profile_label.text = "Active: %s" % winner.name
	else:
		active_profile_label.text = "Active: — (idle)"

func _update_status_bars() -> void:
	if not current_entity is Ant:
		return
	var ant: Ant = current_entity as Ant

	health_bar.max_value = Ant.HEALTH_MAX
	health_bar.value = ant.health_level
	health_value_label.text = "%d/%d" % [int(ant.health_level), int(Ant.HEALTH_MAX)]

	energy_bar.max_value = Ant.ENERGY_MAX
	energy_bar.value = ant.energy_level
	energy_value_label.text = "%d/%d" % [int(ant.energy_level), int(Ant.ENERGY_MAX)]

	_update_bar_colors()

func _update_bar_colors() -> void:
	if not current_entity is Ant:
		return
	var ant: Ant = current_entity as Ant

	var health_pct: float = ant.health_level / Ant.HEALTH_MAX
	var energy_pct: float = ant.energy_level / Ant.ENERGY_MAX

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

	if ant.influence_manager:
		show_influence_vectors_check.button_pressed = ant.influence_manager.is_visualization_enabled()

	if ant.nav_agent:
		nav_debug_check.button_pressed = ant.nav_agent.debug_enabled


func _update_ant_info() -> void:
	if not current_entity is Ant:
		return
	var ant: Ant = current_entity as Ant

	if not is_instance_valid(ant):
		return

	## Update dynamic labels
	role_label.text = "Role: %s" % ant.role
	food_label.text = "Carrying Food: %s" % ("Yes" if ant.is_carrying_food else "No")

	_update_status_bars()
	_update_movement_influences_section()

	## Update legend periodically
	if Engine.get_physics_frames() % 20 == 0:
		if ant.influence_manager:
			_update_legend()
#endregion


#region Colony View Setup
func _setup_colony_view(colony: Colony) -> void:
	ant_section.visible = false
	colony_section.visible = true

	title_label.text = "Colony: %s" % colony.name

	## Show colony-specific visualization options
	show_influence_vectors_check.visible = false
	highlight_check.visible = true
	highlight_check.text = "Highlight Ants"

	_sync_colony_visualization(colony)
	_populate_profile_options()
	_populate_colony_ant_profiles_list()
	_update_colony_settings(colony)
	_update_colony_info()


func _sync_colony_visualization(colony: Colony) -> void:
	show_heatmap_check.button_pressed = colony.heatmap_enabled
	nav_debug_check.button_pressed = colony.nav_debug_enabled
	highlight_check.button_pressed = colony.highlight_ants_enabled


func _populate_profile_options() -> void:
	profile_option.clear()
	_profile_map.clear()

	var profiles: Array[AntProfile] = _get_available_ant_profiles()
	for i: int in range(profiles.size()):
		var profile: AntProfile = profiles[i]
		profile_option.add_item(profile.name, i)
		_profile_map[i] = profile

	if not profiles.is_empty():
		profile_option.select(0)


func _get_available_ant_profiles() -> Array[AntProfile]:
	var profiles: Array[AntProfile] = [] as Array[AntProfile]

	if current_entity is Colony:
		var colony: Colony = current_entity as Colony
		if colony.profile and not colony.profile.ant_profiles.is_empty():
			profiles.append_array(colony.profile.ant_profiles)

	return profiles


func _populate_colony_ant_profiles_list() -> void:
	colony_ant_profiles_list.clear()

	if not current_entity is Colony:
		return

	var colony: Colony = current_entity as Colony
	if not colony.profile:
		return

	for profile: AntProfile in colony.profile.ant_profiles:
		var item_text: String = "%s" % profile.name
		colony_ant_profiles_list.add_item(item_text)

	edit_colony_ant_profile_button.disabled = true


func _update_colony_settings(colony: Colony) -> void:
	radius_spin.value = colony.radius
	max_ants_spin.value = colony.profile.max_ants if colony.profile else 100
	dirt_color_picker.color = colony.dirt_color


func _update_colony_info() -> void:
	if not current_entity is Colony:
		return
	var colony: Colony = current_entity as Colony

	if not is_instance_valid(colony):
		return

	ant_count_label.text = "Ants: %d" % colony.ants.size()
	food_collected_label.text = "Food: %s" % (str(colony.foods.mass) if colony.foods else "0")
	radius_label.text = "Radius: %.1f" % colony.radius
#endregion


#region Signal Handlers - Ant



func _on_view_influence_profile_pressed() -> void:
	pass  # Retired with steering profiles; E3 routes this to the behavior editor.
#endregion


#region Signal Handlers - Colony
func _on_spawn_pressed() -> void:
	if not current_entity is Colony:
		push_warning("Ant spawn requested on missing Colony")
		return
	var colony: Colony = current_entity as Colony

	var count: int = int(spawn_count_spin.value)
	var selected_idx: int = profile_option.selected
	var profile: AntProfile = _profile_map.get(selected_idx)

	if profile:
		spawn_requested.emit(colony, count, profile) # Why do we emit this?
		colony.spawn_ants(count, profile)


func _on_profile_selected(_index: int) -> void:
	pass


func _on_radius_changed(value: float) -> void:
	if current_entity is Colony:
		var colony: Colony = current_entity as Colony
		colony.radius = value
		colony.queue_redraw()


func _on_max_ants_changed(value: float) -> void:
	if current_entity is Colony:
		var colony: Colony = current_entity as Colony
		if colony.profile:
			colony.profile.max_ants = int(value)


func _on_spawn_rate_changed(value: float) -> void:
	if current_entity is Colony:
		var colony: Colony = current_entity as Colony
		colony.spawn_rate = value


func _on_dirt_color_changed(color: Color) -> void:
	if current_entity is Colony:
		var colony: Colony = current_entity as Colony
		colony.dirt_color = color
		colony.queue_redraw()


func _on_darker_dirt_changed(color: Color) -> void:
	if current_entity is Colony:
		var colony: Colony = current_entity as Colony
		colony.darker_dirt_color = color
		colony.queue_redraw()


func _on_colony_ant_profile_selected(_index: int) -> void:
	pass  # Edit button retired until E3; selection currently drives nothing.


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


#region Legend Management
func _clear_legend() -> void:
	for child: Node in influences_legend.get_children():
		child.queue_free()
	_influence_colors.clear()


func _update_legend() -> void:
	_clear_legend()

	if not current_entity is Ant:
		return
	var ant: Ant = current_entity as Ant

	if not is_instance_valid(ant):
		return

	## Calculate total magnitude for normalization
	var total_magnitude: float = 0.0
	var influence_data: Array[Dictionary] = [] as Array[Dictionary]

	var entries: Array[InfluenceEntry] = ant.influence_manager.get_entries()

	## First pass: collect data and calculate total magnitude
	for entry: InfluenceEntry in entries:
		if entry == null or entry.influence == null:
			continue
		if _should_ignore_influence(entry.influence):
			continue

		## Entry gate AND the influence's own condition
		if not entry.is_active(ant):
			continue

		## Weighted contribution — what the integrator actually sums
		var vector: Vector2 = entry.weighted_vector(ant)
		var magnitude: float = vector.length()

		if magnitude < STYLE.INFLUENCE_SETTINGS.MIN_WEIGHT_THRESHOLD:
			continue

		total_magnitude += magnitude
		influence_data.append({
			"name": entry.influence.name,
			"magnitude": magnitude,
			"color": entry.influence.color
		})

	## Second pass: create legend entries
	for data: Dictionary in influence_data:
		var entry_row: HBoxContainer = HBoxContainer.new()

		## Color indicator
		var color_rect: ColorRect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(16, 16)
		color_rect.color = data.color
		entry_row.add_child(color_rect)

		## Name and percentage
		var percentage: float = (data.magnitude / total_magnitude * 100.0) if total_magnitude > 0 else 0.0
		var label: Label = Label.new()
		label.text = " %s: %.1f%%" % [data.name, percentage]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry_row.add_child(label)

		influences_legend.add_child(entry_row)

		## Store color for this influence
		_influence_colors[data.name] = data.color


func _should_ignore_influence(influence: Influence) -> bool:
	for ignore_type: String in STYLE.INFLUENCE_SETTINGS.IGNORE_TYPES:
		if influence.name.to_lower().contains(ignore_type):
			return true
	return false
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
