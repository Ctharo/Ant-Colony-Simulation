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
	"OVERALL_INFLUENCE_COLOR": Color(1.0, 1.0, 1.0),  # Keep overall influence white
	"INFLUENCE_ARROW_LENGTH": 50.0,
	"INFLUENCE_ARROW_WIDTH": 2.0,
	"INFLUENCE_HEAD_SIZE": 8.0
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
	if not ant:
		unselect_current()
		return
		
	current_ant = ant
	show()
	
	# If ant has a move action, update the legend with its influences
	if ant.action_manager and ant.action_manager._current_action_id:
		var current_action = ant.action_manager._actions[ant.action_manager._current_action_id]
		if current_action is Move:
			update_legend(current_action.influences)
			
	# Update basic info
	title_label.text = "Ant #%d" % ant.id
	colony_label.text = "Colony: %s" % (ant.colony.name if ant.colony else "None")
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

func get_influence_color(influence_name: String) -> Color:
	if influence_name not in _influence_colors:
		# Generate a random saturated color
		_influence_colors[influence_name] = Color.from_hsv(
			randf(),  # Random hue
			0.8,      # High saturation
			0.9       # High value/brightness
		)
	return _influence_colors[influence_name]
	
func update_legend(influences: Array) -> void:
	clear_legend()
	
	# Add overall influence to legend first
	add_legend_entry("Overall", STYLE.OVERALL_INFLUENCE_COLOR)
	
	# Add divider
	var separator = HSeparator.new()
	influences_legend.add_child(separator)
	
	# Add each influence
	for influence: Influence in influences:
		add_legend_entry(influence.name, get_influence_color(influence.name))

func add_legend_entry(name: String, color: Color) -> void:
	var entry = HBoxContainer.new()
	
	# Color indicator
	var color_rect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(16, 16)
	color_rect.color = color
	entry.add_child(color_rect)
	
	# Spacing
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(5, 0)
	entry.add_child(spacer)
	
	# Label
	var label = Label.new()
	label.text = name.capitalize()
	entry.add_child(label)
	
	influences_legend.add_child(entry)

func unselect_current() -> void:
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
	if current_ant and is_visible():
		update_status_bars()
		# Update action text
		action_label.text = "Action: %s" % (current_ant.action_manager._current_action_id if current_ant.action_manager else "None")
		# Update food text
		food_label.text = "Carried Food: %.1f units" % (current_ant.foods.mass if current_ant.foods else 0.0)
		# Update role text
		role_label.text = "Role: %s" % current_ant.role
		queue_redraw()
		
func _on_ant_died(_ant: Ant) -> void:
	unselect_current()

func _on_root_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			unselect_current()  # Right click to unselect

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
	var influences = move_action.influences
	
	# First calculate total influence using the manager
	var total_direction = influence_manager.calculate_weighted_direction(influences)
	
	# Calculate individual influences and find max weight for scaling
	var max_weight = 0.0
	var influence_data = []  # Store calculated influences for drawing
	
	for influence in influences:
		var weight = influence_manager.eval_system.get_value(influence.weight)
		var direction = influence_manager.eval_system.get_value(influence.direction).normalized()
		max_weight = max(max_weight, weight)
		influence_data.append({
			"weight": weight,
			"direction": direction,
			"name": influence.name
		})
	
	# Scale factor for arrow lengths
	var scale_factor = STYLE.INFLUENCE_ARROW_LENGTH / max(max_weight, 0.01)
	
	# Draw individual influence arrows
	for data in influence_data:
		var influence_vector = data.direction * data.weight * scale_factor
		draw_arrow(
			ant_pos,
			ant_pos + influence_vector,
			get_influence_color(data.name),
			STYLE.INFLUENCE_ARROW_WIDTH,
			STYLE.INFLUENCE_HEAD_SIZE
		)
	
	# Draw overall influence arrow
	if total_direction != Vector2.ZERO:
		draw_arrow(
			ant_pos,
			ant_pos + total_direction * STYLE.INFLUENCE_ARROW_LENGTH,
			STYLE.OVERALL_INFLUENCE_COLOR,
			STYLE.INFLUENCE_ARROW_WIDTH * 1.5,  # Slightly thicker
			STYLE.INFLUENCE_HEAD_SIZE * 1.2     # Slightly larger head
		)
			
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
