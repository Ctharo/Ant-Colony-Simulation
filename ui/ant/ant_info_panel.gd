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
	"SELECTION_CIRCLE_WIDTH": 2.0
}

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

# Current ant being displayed
var current_ant: Ant

func _ready() -> void:
	custom_minimum_size = STYLE.PANEL_SIZE
	hide()  # Start hidden
	setup_styling()
	
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
		
func _on_ant_died() -> void:
	unselect_current()

func _on_root_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			unselect_current()  # Right click to unselect

func _draw() -> void:
	if current_ant and current_ant.is_inside_tree():
		# Draw selection circle at ant's position
		draw_arc(
			current_ant.global_position,  # Use ant's global position
			STYLE.SELECTION_CIRCLE_RADIUS,
			0,
			TAU,
			32,
			STYLE.SELECTION_CIRCLE_COLOR,
			STYLE.SELECTION_CIRCLE_WIDTH
		)
