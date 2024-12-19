class_name AntInfoPanel
extends PanelContainer

# Custom styling
const STYLE = {
	"BAR_BG_COLOR": Color(0.2, 0.2, 0.2),
	"HEALTH_COLOR": Color(0.2, 0.8, 0.2),
	"ENERGY_COLOR": Color(0.2, 0.2, 0.8),
	"LOW_COLOR": Color(0.8, 0.2, 0.2),
	"MED_COLOR": Color(0.8, 0.8, 0.2),
	"PANEL_SIZE": Vector2(300, 400),
	"SELECTION_CIRCLE_COLOR": Color(1, 1, 1, 0.5),
	"SELECTION_CIRCLE_RADIUS": 12.0,
	"SELECTION_CIRCLE_WIDTH": 2.0,
	"INFLUENCE_SETTINGS": {
		"OVERALL_COLOR": Color(1.0, 1.0, 1.0),  # Keep overall influence white
		"ARROW_LENGTH": 50.0,        # Base length for the overall influence arrow
		"ARROW_WIDTH": 2.0,          # Base width for influence arrows
		"ARROW_HEAD_SIZE": 8.0,      # Base size for arrow heads
		"OVERALL_SCALE": 1.5,        # Scale factor for overall influence arrow
		"IGNORE_TYPES": ["random"],  # Influence types to ignore in visualization
		"MIN_WEIGHT_THRESHOLD": 0.01 # Minimum weight to show an influence
	}
}

var _influence_colors: Dictionary = {}


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

@onready var influences_legend: VBoxContainer = %InfluencesLegend

# Current ant being displayed
var current_ant: Ant

func _ready() -> void:
	custom_minimum_size = STYLE.PANEL_SIZE
	hide()  # Start hidden
	setup_styling()
	clear_legend()

	# Set up rendering mode for our node
	top_level = true  # Make sure we draw above other nodes
	
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
	deselect_current()
	if not ant:
		return
	current_ant = ant
	show()
	
	# If ant has a move action, update the legend with its influences
	if ant.action_manager and ant.action_manager._current_action_id:
		var current_action = ant.action_manager._actions[ant.action_manager._current_action_id]
		if current_action is Move:
			update_legend(current_action.influences)
		if ant.heatmap:
			ant.heatmap.set_debug_draw(ant.colony, true)
			
	# Update basic info
	title_label.text = "Ant #%d" % ant.id
	colony_label.text = "Colony: %s" % (str(ant.colony.name) if ant.colony else "None")
	action_label.text = "Action: %s" % (ant.action_manager._current_action_id if ant.action_manager else "None")
	
	# Update status bars
	update_status_bars()
	
	# Update food info
	food_label.text = "Carried Food: %.1f units" % (ant.foods.mass if ant.foods else 0.0)
	
	# Start monitoring this ant
	if not ant.died.is_connected(_on_ant_died):
		ant.died.connect(_on_ant_died)
	
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
	
	# Get total magnitude for relative weights
	var influence_manager: InfluenceManager = current_ant.action_manager._states[current_ant.action_manager._current_action_id].influence_manager
	var total_magnitude = influence_manager.calculate_weighted_direction(influences).length()
	
	# Add each non-ignored influence with its relative weight
	for influence in influences:
		var weight = influence_manager.eval_system.get_value(influence.weight)
		var relative_weight = weight / total_magnitude if total_magnitude > 0 else 0.0
		var color: Color = influence.color if not _should_ignore_influence(influence) else Color(Color.WHITE, 0)
		add_legend_entry(influence.name, influence.color, relative_weight)

# Modified legend entry function with weight display
func add_legend_entry(name: String, color: Color, relative_weight: float) -> void:
	var entry = HBoxContainer.new()
	
	# Color indicator	
	var influence_type = name.to_snake_case().trim_suffix("_influence")
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
	name_label.text = name.trim_suffix(" influence").capitalize()
	entry.add_child(name_label)
	
	# Weight label with fixed width for alignment
	var weight_label = Label.new()
	weight_label.custom_minimum_size.x = 70
	weight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weight_label.text = "%.1f%%" % (relative_weight * 100)
	
	# Add some spacing before the percentage
	var weight_spacer = Control.new()
	weight_spacer.custom_minimum_size = Vector2(10, 0)
	entry.add_child(weight_spacer)
	
	entry.add_child(weight_label)
	
	influences_legend.add_child(entry)

func deselect_current() -> void:

	if current_ant and current_ant.heatmap:
		current_ant.heatmap.set_debug_draw(current_ant.colony, false)
	current_ant = null

	hide()
	queue_redraw()
	
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

func _process(_delta: float) -> void:
	_update_ui()
	queue_redraw()

func _update_ui() -> void:
	if not (current_ant and is_visible()):
		return
	
	update_status_bars()
	# Update action text
	action_label.text = "Action: %s" % (current_ant.action_manager._current_action_id if current_ant.action_manager else "None")
	# Update food text
	food_label.text = "Carried Food: %.1f units" % (current_ant.foods.mass if current_ant.foods else 0.0)
	# Update role text
	role_label.text = "Role: %s" % current_ant.role
	
	
	if Engine.get_physics_frames() % 20 != 0:
		return
	if current_ant.action_manager and current_ant.action_manager._current_action_id:
		var current_action = current_ant.action_manager._actions[current_ant.action_manager._current_action_id]
		if current_action is Move:
			update_legend(current_action.influences)
			
func _on_ant_died(_ant: Ant) -> void:
	deselect_current()

func _on_root_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			deselect_current()  # Right click to unselect

func _draw() -> void:
	if current_ant and current_ant.is_inside_tree():
		# Draw selection circle
		draw_arc(
			current_ant.global_position,
			STYLE.SELECTION_CIRCLE_RADIUS,
			0,
			TAU,
			32,
			STYLE.SELECTION_CIRCLE_COLOR,
			STYLE.SELECTION_CIRCLE_WIDTH
		)
		
		# Draw influence arrows if ant has an action manager and is moving
		if current_ant.action_manager and current_ant.action_manager._current_action_id:
			var current_action = current_ant.action_manager._actions[current_ant.action_manager._current_action_id]
			if current_action is Move:
				draw_influences(current_action)
				
func draw_influences(move_action: Move) -> void:
	var ant_pos = current_ant.global_position
	var influence_manager = current_ant.action_manager._states[move_action.id].influence_manager
	
	# Filter out ignored influence types
	var valid_influences = move_action.influences.filter(
		func(influence): return not _should_ignore_influence(influence)
	)
	
	# Calculate total influence first
	var total_direction = influence_manager.calculate_weighted_direction(valid_influences)
	var total_magnitude = total_direction.length()
	
	if total_magnitude < STYLE.INFLUENCE_SETTINGS.MIN_WEIGHT_THRESHOLD:
		return
		
	# Normalize total direction
	total_direction = total_direction.normalized()
	
	# Calculate individual influences and collect data
	var influence_data = []
	
	for influence in valid_influences:
		var weight = influence_manager.eval_system.get_value(influence.weight)
		if weight < STYLE.INFLUENCE_SETTINGS.MIN_WEIGHT_THRESHOLD:
			continue
			
		var direction = influence_manager.eval_system.get_value(influence.direction).normalized()
		
		# Scale weight relative to total magnitude
		var relative_weight = weight / total_magnitude
		
		influence_data.append({
			"weight": relative_weight,  # Now relative to total
			"direction": direction,
			"color": influence.color,
			"name": influence.name
		})
	
	# Sort influences by weight/length (shortest first)
	influence_data.sort_custom(
		func(a, b): return a.weight < b.weight
	)
	
	# Draw overall influence arrow first (on bottom)
	var overall_length = STYLE.INFLUENCE_SETTINGS.ARROW_LENGTH * STYLE.INFLUENCE_SETTINGS.OVERALL_SCALE
	draw_arrow(
		ant_pos,
		ant_pos + total_direction * overall_length,
		STYLE.INFLUENCE_SETTINGS.OVERALL_COLOR,
		STYLE.INFLUENCE_SETTINGS.ARROW_WIDTH * STYLE.INFLUENCE_SETTINGS.OVERALL_SCALE,
		STYLE.INFLUENCE_SETTINGS.ARROW_HEAD_SIZE * STYLE.INFLUENCE_SETTINGS.OVERALL_SCALE
	)
	
	# Draw individual influence arrows
	for data in influence_data:
		var arrow_length = STYLE.INFLUENCE_SETTINGS.ARROW_LENGTH * data.weight * STYLE.INFLUENCE_SETTINGS.OVERALL_SCALE
		var influence_vector = data.direction * arrow_length
		
		draw_arrow(
			ant_pos,
			ant_pos + influence_vector,
			data.color,
			STYLE.INFLUENCE_SETTINGS.ARROW_WIDTH,
			STYLE.INFLUENCE_SETTINGS.ARROW_HEAD_SIZE
		)

		
## Check if an influence should be ignored in visualization
func _should_ignore_influence(influence: Influence) -> bool:
	var influence_type = influence.name.to_snake_case().trim_suffix("_influence")
	return influence_type in STYLE.INFLUENCE_SETTINGS.IGNORE_TYPES

func draw_arrow(start: Vector2, end: Vector2, color: Color, width: float, head_size: float) -> void:
	# Draw main line
	draw_line(start, end, color, width)
	
	# Calculate arrow head
	var direction = (end - start).normalized()
	var right = direction.rotated(PI * 3/4) * head_size
	var left = direction.rotated(-PI * 3/4) * head_size
	
	var arrow_points = PackedVector2Array([
		end,
		end + right,
		end + left
	])
	
	# Draw arrow head
	draw_colored_polygon(arrow_points, color)
