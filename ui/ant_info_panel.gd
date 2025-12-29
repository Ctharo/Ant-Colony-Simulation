class_name AntInfoPanel
extends DraggablePanel

#region Constants
const STYLE: Dictionary = {
	"BAR_BG_COLOR": Color(0.2, 0.2, 0.2),
	"HEALTH_COLOR": Color(0.2, 0.8, 0.2),
	"ENERGY_COLOR": Color(0.2, 0.2, 0.8),
	"LOW_COLOR": Color.RED,
	"MED_COLOR": Color.CORAL,
	"PANEL_SIZE": Vector2(320, 550),
	"PANEL_MIN_SIZE": Vector2(300, 350),
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
## Tracks if show was requested before panel was ready
var _pending_show: bool = false
## Tracks if panel initialization is complete
var _panel_ready: bool = false
#endregion

#region UI Components
@onready var header_container: HBoxContainer = %HeaderContainer
@onready var collapse_button: Button = %CollapseButton
@onready var content_container: VBoxContainer = %ContentContainer
@onready var scroll_container: ScrollContainer = %ScrollContainer
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
	setup_styling()
	clear_legend()

	heatmap = get_tree().get_first_node_in_group("heatmap")

	_connect_signals()
	_setup_scroll_handling()

	_panel_ready = true

	# Only hide if show wasn't already requested
	if _pending_show:
		show()
		_pending_show = false
	else:
		hide()
#endregion


func _setup_scroll_handling() -> void:
	## Consume scroll events to prevent camera zoom
	scroll_container.gui_input.connect(_on_scroll_gui_input)


func _on_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			accept_event()


func _connect_signals() -> void:
	close_button.pressed.connect(_on_close_pressed)
	edit_profile_button.pressed.connect(_on_edit_profile_pressed)
	view_influence_profile_button.pressed.connect(_on_view_influence_profile_pressed)
	show_heatmap_check.toggled.connect(_on_show_heatmap_toggled)
	show_influence_vectors_check.toggled.connect(_on_show_influence_vectors_check_toggled)
	show_nav_path_check.toggled.connect(_on_show_nav_path_check_toggled)


func _process(_delta: float) -> void:
	if not is_visible() or not is_instance_valid(current_ant):
		return

	update_ant_info()

	# Update legend every 20 physics frames
	if Engine.get_physics_frames() % 20 == 0:
		if current_ant.influence_manager and current_ant.influence_manager.active_profile:
			update_legend(current_ant.influence_manager.active_profile.influences)


func setup_styling() -> void:
	health_bar.add_theme_stylebox_override("fill", create_stylebox(STYLE.HEALTH_COLOR))
	health_bar.add_theme_stylebox_override("background", create_stylebox(STYLE.BAR_BG_COLOR))

	energy_bar.add_theme_stylebox_override("fill", create_stylebox(STYLE.ENERGY_COLOR))
	energy_bar.add_theme_stylebox_override("background", create_stylebox(STYLE.BAR_BG_COLOR))


func create_stylebox(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style


func show_ant_info(ant: Ant) -> void:
	if not ant:
		return
	current_ant = ant

	# Update basic info
	title_label.text = "Ant #%d" % ant.id
	colony_label.text = "Colony: %s" % (str(ant.colony.name) if ant.colony else "None")

	# Update status bars
	update_status_bars()

	# Update food info
	food_label.text = "Carrying Food: %s" % ("Yes" if ant.is_carrying_food else "No")

	# Handle deferred initialization race condition
	if _panel_ready:
		show()
	else:
		_pending_show = true

	# Queue redraw for selection circle
	queue_redraw()


func update_ant_info() -> void:
	if not current_ant or not is_instance_valid(current_ant):
		return

	# Update status bars
	update_status_bars()

	# Update food info
	food_label.text = "Carrying Food: %s" % ("Yes" if current_ant.is_carrying_food else "No")

	# Update profile section
	_update_profile_section()


func update_status_bars() -> void:
	if not current_ant:
		return

	health_bar.max_value = current_ant.health_max
	health_bar.value = current_ant.health_level
	health_value_label.text = "%d/%d" % [int(current_ant.health_level), int(current_ant.health_max)]

	energy_bar.max_value = current_ant.energy_max
	energy_bar.value = current_ant.energy_level
	energy_value_label.text = "%d/%d" % [int(current_ant.energy_level), int(current_ant.energy_max)]

	_update_bar_colors()


func _update_bar_colors() -> void:
	if not current_ant:
		return

	var health_pct: float = current_ant.health_level / current_ant.health_max
	var energy_pct: float = current_ant.energy_level / current_ant.energy_max

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

	health_bar.add_theme_stylebox_override("fill", create_stylebox(health_color))
	energy_bar.add_theme_stylebox_override("fill", create_stylebox(energy_color))


func _update_profile_section() -> void:
	if not current_ant:
		return

	profile_name_label.text = "Profile: %s" % (current_ant.profile.name if current_ant.profile else "None")

	if current_ant.influence_manager and current_ant.influence_manager.active_profile:
		active_profile_label.text = "Active: %s" % current_ant.influence_manager.active_profile.name
	else:
		active_profile_label.text = "Active: None"


func clear_legend() -> void:
	for child: Node in influences_legend.get_children():
		child.queue_free()
	_influence_colors.clear()


func update_legend(influences: Array) -> void:
	clear_legend()

	if not current_ant or not is_instance_valid(current_ant):
		return

	# Calculate total magnitude for normalization
	var total_magnitude: float = 0.0
	var influence_data: Array[Dictionary] = [] as Array[Dictionary]

	# First pass: collect data and calculate total magnitude
	for influence: Influence in influences:
		if _should_ignore_influence(influence):
			continue

		var weight: float = influence.get_current_weight()
		if weight < STYLE.INFLUENCE_SETTINGS.MIN_WEIGHT_THRESHOLD:
			continue

		total_magnitude += weight
		influence_data.append({
			"name": influence.type,
			"weight": weight
		})

	# Second pass: create legend entries
	for data: Dictionary in influence_data:
		var normalized_weight: float = data.weight / total_magnitude if total_magnitude > 0 else 0.0
		_add_legend_entry(data.name, normalized_weight)


func _add_legend_entry(type_name: String, normalized_weight: float) -> void:
	var entry: HBoxContainer = HBoxContainer.new()

	# Color indicator
	var color: Color = _get_influence_color(type_name)
	var color_rect: ColorRect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(16, 16)
	color_rect.color = color
	entry.add_child(color_rect)

	# Spacer
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(8, 0)
	entry.add_child(spacer)

	# Name label
	var name_label: Label = Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text = type_name.capitalize()
	entry.add_child(name_label)

	# Weight label
	var weight_label: Label = Label.new()
	weight_label.custom_minimum_size.x = 70
	weight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weight_label.text = "%.1f%%" % (normalized_weight * 100)
	entry.add_child(weight_label)

	influences_legend.add_child(entry)


func _get_influence_color(type_name: String) -> Color:
	if not _influence_colors.has(type_name):
		# Generate consistent color based on type name hash
		var hash_value: int = type_name.hash()
		var hue: float = fmod(float(hash_value), 360.0) / 360.0
		_influence_colors[type_name] = Color.from_hsv(hue, 0.7, 0.9)
	return _influence_colors[type_name]


func _should_ignore_influence(influence: Influence) -> bool:
	return influence.type in STYLE.INFLUENCE_SETTINGS.IGNORE_TYPES


#region Signal Handlers - Profile
func _on_edit_profile_pressed() -> void:
	if not current_ant or not current_ant.profile:
		return

	var editor: AntProfileEditorPopup = AntProfileEditorPopup.new()
	add_child(editor)
	editor.edit_profile(current_ant.profile)
	await editor.closed
	_update_profile_section()


func _on_view_influence_profile_pressed() -> void:
	if not current_ant or not current_ant.influence_manager:
		return

	var active: InfluenceProfile = current_ant.influence_manager.active_profile
	if not active:
		return

	var popup: InfluenceProfileViewPopup = InfluenceProfileViewPopup.new()
	add_child(popup)
	popup.show_profile(active)
#endregion


#region Signal Handlers - Visualization
func _on_show_nav_path_check_toggled(toggled_on: bool) -> void:
	if current_ant and current_ant.nav_agent:
		current_ant.nav_agent.debug_enabled = toggled_on


func _on_show_heatmap_toggled(enabled: bool) -> void:
	if current_ant and heatmap:
		heatmap.debug_draw(current_ant, enabled)


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
