class_name AntInfo
extends PanelContainer

#region Constants
const STYLE = {
	"PANEL_SIZE": Vector2(250, 160),
	"EXPANDED_SIZE": Vector2(250, 320),
	"BAR_BG_COLOR": Color(0.2, 0.2, 0.2),
	"HEALTH_COLOR": Color(0.2, 0.8, 0.2),
	"ENERGY_COLOR": Color(0.2, 0.2, 0.8),
	"LOW_COLOR": Color.RED,
	"MED_COLOR": Color.ORANGE,
	"SELECTION_COLOR": Color(1, 1, 1, 0.3),
	"SELECTION_RADIUS": 30.0,
}
#endregion

#region Variables
## Reference to currently displayed ant
var current_ant: Ant = null

## Whether the influences panel is expanded
var is_expanded: bool = false

## Selection circle instance
var selection_circle: Node2D

var camera: Camera2D
#endregion

#region Onready Variables
@onready var title_label: Label = %TitleLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var energy_label: Label = %EnergyLabel
@onready var food_label: Label = %FoodLabel
@onready var profile_label: Label = %ActionLabel
@onready var expand_button: Button = %ExpandButton
@onready var influences_container: VBoxContainer = %InfluencesContainer
@onready var destroy_button: Button = %DestroyButton
@onready var track_button: Button = %TrackButton
@onready var influence_button: Button = %InfluenceButton
@onready var influence_renderer: InfluenceRenderer
#endregion

#region Lifecycle Methods
func _ready() -> void:
	top_level = true
	influences_container.hide()
	custom_minimum_size = STYLE.PANEL_SIZE
	setup_styling()
	setup_selection_circle()

	# Connect signals
	expand_button.pressed.connect(_on_expand_pressed)
	destroy_button.pressed.connect(_on_destroy_pressed)
	track_button.pressed.connect(_on_track_pressed)
	influence_button.pressed.connect(_on_influence_pressed)


	# Set button sizes
	expand_button.custom_minimum_size = Vector2(30, 30)
	destroy_button.custom_minimum_size = Vector2(30, 30)
	track_button.custom_minimum_size = Vector2(30, 30)
	influence_button.custom_minimum_size = Vector2(30, 30)

	# Set button colors
	destroy_button.modulate = Color.RED
	track_button.modulate = Color.BLUE
	influence_button.modulate = Color.GREEN

func _process(_delta: float) -> void:
	if current_ant and is_instance_valid(current_ant):
		_update_display()
		_update_selection_circle()
	else:
		queue_free()
		return
#endregion

#region Public Methods
## Display info for the given ant
func show_ant_info(ant: Ant, p_camera: Camera2D) -> void:
	camera = p_camera
	current_ant = ant
	if not is_instance_valid(ant):
		return

	title_label.text = "Ant #%d" % ant.id
	influence_renderer = InfluenceRenderer.new()
	influence_renderer.set_ant(ant)
	influence_renderer.camera = camera
	selection_circle.show()
	show()
	_update_display()

## Clear current ant and hide panel
func clear() -> void:
	if influence_renderer:
		influence_renderer.set_enabled(false)
	current_ant = null
	selection_circle.hide()
	hide()

## Called when clicked outside
func _on_outside_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if current_ant:
			clear()
#endregion

#region Private Methods
## Set up initial styling
func setup_styling() -> void:
	# Style health bar
	var health_style = StyleBoxFlat.new()
	health_style.bg_color = STYLE.HEALTH_COLOR
	health_style.corner_radius_top_left = 3
	health_style.corner_radius_top_right = 3
	health_style.corner_radius_bottom_left = 3
	health_style.corner_radius_bottom_right = 3
	health_bar.add_theme_stylebox_override("fill", health_style)

	# Style energy bar
	var energy_style = StyleBoxFlat.new()
	energy_style.bg_color = STYLE.ENERGY_COLOR
	energy_style.corner_radius_top_left = 3
	energy_style.corner_radius_top_right = 3
	energy_style.corner_radius_bottom_left = 3
	energy_style.corner_radius_bottom_right = 3
	energy_bar.add_theme_stylebox_override("fill", energy_style)

	# Style background bars
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = STYLE.BAR_BG_COLOR
	bg_style.corner_radius_top_left = 3
	bg_style.corner_radius_top_right = 3
	bg_style.corner_radius_bottom_left = 3
	bg_style.corner_radius_bottom_right = 3
	health_bar.add_theme_stylebox_override("background", bg_style)
	energy_bar.add_theme_stylebox_override("background", bg_style.duplicate())

## Set up selection circle
func setup_selection_circle() -> void:
	selection_circle = Node2D.new()
	selection_circle.z_index = -1
	selection_circle.hide()
	add_child(selection_circle)

	selection_circle.draw.connect(func():
		if current_ant and is_instance_valid(current_ant):
			var center = current_ant.global_position
			selection_circle.draw_circle(center, STYLE.SELECTION_RADIUS, STYLE.SELECTION_COLOR)
	)

## Update the selection circle position
func _update_selection_circle() -> void:
	if selection_circle.visible:
		selection_circle.queue_redraw()

## Update the display with current ant info
func _update_display() -> void:

	# Update bars
	var health_percent = (current_ant.health_level / current_ant.health_max) * 100.0
	health_bar.value = health_percent
	health_label.text = "%.0f/%.0f" % [current_ant.health_level, current_ant.health_max]
	_update_bar_color(health_bar, health_percent, STYLE.HEALTH_COLOR)

	var energy_percent = (current_ant.energy_level / current_ant.energy_max) * 100.0
	energy_bar.value = energy_percent
	energy_label.text = "%.0f/%.0f" % [current_ant.energy_level, current_ant.energy_max]
	_update_bar_color(energy_bar, energy_percent, STYLE.ENERGY_COLOR)

	# Update labels
	food_label.text = "Carried Food: %.1f units" % (current_ant.foods.mass if current_ant.foods else 0.0)
	# Update influences if expanded
	if is_expanded:
		_update_influences()

	global_position = camera.global_to_ui(current_ant.global_position) + Vector2(-size.x/2, 20)

## Update the color of a progress bar based on value
func _update_bar_color(bar: ProgressBar, value: float, normal_color: Color) -> void:
	var style = bar.get_theme_stylebox("fill") as StyleBoxFlat
	if value > 66:
		style.bg_color = normal_color
	elif value > 33:
		style.bg_color = STYLE.MED_COLOR
	else:
		style.bg_color = STYLE.LOW_COLOR

## Clear and update the influences display
func _update_influences() -> void:
	# Clear existing influences
	for child in influences_container.get_children():
		if child is HBoxContainer:  # Skip the header
			child.queue_free()

	if not current_ant:
		return

	var active_profile = current_ant.influence_manager.active_profile

	# Add influence entries
	for influence in active_profile.influences:
		_add_influence_entry(influence)

## Add a single influence entry to the influences container
func _add_influence_entry(influence: Influence) -> void:
	var entry = HBoxContainer.new()

	# Color indicator
	var color_rect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(16, 16)
	color_rect.color = influence.color
	entry.add_child(color_rect)

	# Name and value labels
	var name_label = Label.new()
	name_label.text = influence.name.trim_suffix(" influence").capitalize()
	entry.add_child(name_label)

	# Weight percentage label
	var weight_label = Label.new()
	var weight = influence.weight.get_value(current_ant.evaluation_system)
	weight_label.text = "%.1f%%" % (weight * 100)
	weight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weight_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.add_child(weight_label)

	influences_container.add_child(entry)
#endregion

#region Button Handlers
## Handle expand button press
func _on_expand_pressed() -> void:
	is_expanded = !is_expanded

	if is_expanded:
		custom_minimum_size = STYLE.EXPANDED_SIZE
		influences_container.show()
		expand_button.text = "▼"
		_update_influences()
	else:
		custom_minimum_size = STYLE.PANEL_SIZE
		influences_container.hide()
		expand_button.text = "▶"

func _on_destroy_pressed() -> void:
	if current_ant and is_instance_valid(current_ant):
		current_ant.queue_free()
		clear()

func _on_track_pressed() -> void:
	if current_ant and is_instance_valid(current_ant):
		if not camera:
			camera = get_tree().get_first_node_in_group("camera")
		if not is_instance_valid(camera):
			push_error("Cannot track -> camera not valid")
			return
		if camera and camera.tracked_entity == current_ant:
			camera.stop_tracking()
		else:
			camera.track_entity(current_ant)

func _on_influence_pressed() -> void:
	if influence_renderer:
		influence_renderer.set_enabled(!influence_renderer._enabled)
		influence_button.modulate = Color.GREEN if influence_renderer._enabled else Color.DARK_GREEN
#endregion
