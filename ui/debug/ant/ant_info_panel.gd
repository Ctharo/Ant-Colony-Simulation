class_name AntInfoPanel
extends PanelContainer


# Custom styling
const STYLE = {
	"BAR_BG_COLOR": Color(0.2, 0.2, 0.2),
	"HEALTH_COLOR": Color(0.2, 0.8, 0.2),
	"ENERGY_COLOR": Color(0.2, 0.2, 0.8),
	"LOW_COLOR": Color.RED,
	"MED_COLOR": Color.CORAL,
	"PANEL_SIZE": Vector2(300, 400),
	"SELECTION_CIRCLE_COLOR": Color(Color.WHITE, 0.5),
	"SELECTION_CIRCLE_RADIUS": 12.0,
	"SELECTION_CIRCLE_WIDTH": 2.0,
	"INFLUENCE_SETTINGS": {
		"OVERALL_COLOR": Color.WHITE,  # Keep overall influence white
		"ARROW_LENGTH": 50.0,        # Base length for the overall influence arrow
		"ARROW_WIDTH": 2.0,          # Base width for influence arrows
		"ARROW_HEAD_SIZE": 8.0,      # Base size for arrow heads
		"OVERALL_SCALE": 1.5,        # Scale factor for overall influence arrow
		"IGNORE_TYPES": ["random"],  # Influence types to ignore in visualization
		"MIN_WEIGHT_THRESHOLD": 0.01 # Minimum weight to show an influence
	}
}

var _influence_colors: Dictionary = {}
var heatmap: HeatmapManager

# UI Components
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

@onready var influences_legend: VBoxContainer = %InfluencesLegend

# Current ant being displayed
var current_ant: Ant

func _ready() -> void:
	custom_minimum_size = STYLE.PANEL_SIZE
	hide()  # Start hidden
	setup_styling()
	clear_legend()

	heatmap = get_tree().get_first_node_in_group("heatmap")


func _process(_delta: float) -> void:
	_update_ui()
	queue_redraw()

func _update_ui() -> void:
	if not (current_ant and is_visible()):
		return

	update_status_bars()
	if current_ant and current_ant != null:
		# Update action text
		action_label.text = "Action: %s" % (current_ant.action_manager._current_action_id if current_ant.action_manager else "None")
		# Update food text
		food_label.text = "Carried Food: %.1f units" % (current_ant.foods.mass if current_ant.foods else 0.0)
		# Update role text
		role_label.text = "Role: %s" % current_ant.role
	else:
		action_label.text = ""
		food_label.text = ""
		role_label.text = ""

	if Engine.get_physics_frames() % 20 != 0:
		return
	update_legend(current_ant.influence_manager.active_profile.influences)


func setup_styling() -> void:
	# Style the health bar
	health_bar.add_theme_stylebox_override("fill", create_stylebox(STYLE.HEALTH_COLOR))
	health_bar.add_theme_stylebox_override("background", create_stylebox(STYLE.BAR_BG_COLOR))

	# Style the energy bar
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

func show_ant_info(ant: Ant) -> void:
	if not ant:
		return
	current_ant = ant
	show()


	# Update basic info
	title_label.text = "Ant #%d" % ant.id
	colony_label.text = "Colony: %s" % (str(ant.colony.name) if ant.colony else "None")
	action_label.text = "Action: %s" % (ant.action_manager._current_action_id if ant.action_manager else "None")

	# Update status bars
	update_status_bars()

	# Update food info
	food_label.text = "Carried Food: %.1f units" % (ant.foods.mass if ant.foods else 0.0)

	# Queue redraw for selection circle
	queue_redraw()

func clear_legend() -> void:
	for child in influences_legend.get_children():
		child.queue_free()
	_influence_colors.clear()

# Update the legend update function to pass weights
func update_legend(influences: Array) -> void:
	clear_legend()

	# Add overall influence to legend first
	add_legend_entry("Overall", STYLE.INFLUENCE_SETTINGS.OVERALL_COLOR, 1.0)

	# Add divider
	var separator = HSeparator.new()
	influences_legend.add_child(separator)

	# Get influence manager
	var influence_manager: InfluenceManager = current_ant.action_manager._states[current_ant.action_manager._current_action_id].influence_manager

	# Calculate total weight first
	var total_weight = 0.0
	var weights = []

	# First pass: calculate total weight
	for influence in influences:
		var weight = influence_manager.eval_system.get_value(influence.weight)
		weights.append(weight)
		total_weight += weight

	# Second pass: add legend entries with normalized weights
	for i in range(influences.size()):
		var influence = influences[i]
		var weight = weights[i]
		var normalized_weight = weight / total_weight if total_weight > 0 else 0.0

		# Skip influences below threshold
		if normalized_weight < STYLE.INFLUENCE_SETTINGS.MIN_WEIGHT_THRESHOLD:
			continue

		add_legend_entry(
			influence.name,
			influence.color if not _should_ignore_influence(influence) else Color(Color.WHITE, 0),
			normalized_weight
		)

# Modified legend entry function with weight display
func add_legend_entry(p_name: String, color: Color, normalized_weight: float) -> void:
	var entry = HBoxContainer.new()

	# Color indicator
	var influence_type = p_name.to_snake_case().trim_suffix("_influence")
	if not influence_type in STYLE.INFLUENCE_SETTINGS.IGNORE_TYPES:
		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(16, 16)
		color_rect.color = color
		entry.add_child(color_rect)
	else:
		var s = Control.new()
		s.custom_minimum_size = Vector2(17, 0)
		entry.add_child(s)

	# Spacing
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(5, 0)
	entry.add_child(spacer)

	# Name label
	var name_label = Label.new()
	name_label.text = p_name.trim_suffix(" influence").capitalize()
	entry.add_child(name_label)

	# Weight label with fixed width for alignment
	var weight_label = Label.new()
	weight_label.custom_minimum_size.x = 70
	weight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Display percentage with one decimal place
	weight_label.text = "%.1f%%" % (normalized_weight * 100)

	# Add some spacing before the percentage
	var weight_spacer = Control.new()
	weight_spacer.custom_minimum_size = Vector2(10, 0)
	entry.add_child(weight_spacer)

	entry.add_child(weight_label)

	influences_legend.add_child(entry)

func _on_show_nav_path_check_toggled(toggled_on: bool) -> void:
	if current_ant:
		current_ant.nav_agent.debug_enabled = toggled_on

func _on_close_pressed() -> void:
	queue_free()

func update_status_bars() -> void:
	if not current_ant:
		return

	# Update health bar and color
	var health_percent = (current_ant.health_level / current_ant.health_max) * 100.0
	health_bar.value = health_percent
	health_value_label.text = "%d/%d" % [current_ant.health_level, current_ant.health_max]
	update_bar_color(health_bar, health_percent, STYLE.HEALTH_COLOR)

	# Update energy bar and color
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


## Check if an influence should be ignored in visualization
func _should_ignore_influence(influence: Influence) -> bool:
	var influence_type = influence.name.to_snake_case().trim_suffix("_influence")
	return influence_type in STYLE.INFLUENCE_SETTINGS.IGNORE_TYPES

func _on_show_heatmap_toggled(enabled: bool) -> void:
	if current_ant:
		if enabled:
			heatmap.debug_draw(current_ant, true)
		else:
			heatmap.debug_draw(current_ant, false)

func _exit_tree() -> void:
	if current_ant:
		current_ant.nav_agent.debug_enabled = false
		heatmap.debug_draw(current_ant, false)
