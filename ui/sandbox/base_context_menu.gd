class_name BaseContextMenu
extends Control

## Radius of the circular menu layout
const RADIUS = 70.0
## Width of the curved button
const BUTTON_ARC_WIDTH = 125.0
## Height of the curved button
const BUTTON_ARC_HEIGHT = 40.0
## Styling for selection indicator
const SELECTION_STYLE = {
	"CIRCLE_COLOR": Color(Color.WHITE, 0.5),
	"CIRCLE_WIDTH": 2.0
}
## Standard button dimensions
const BUTTON_SIZE = Vector2(125, 40)
## Duration of open/close animations
const ANIMATION_DURATION = 0.3
## Angular gap between buttons in radians
const BUTTON_GAP = 0.05

#region Public Properties
## Whether the menu is currently open
var is_open := false
## Reference to the main camera
var camera: Camera2D
## Screen position of the menu
@onready var screen_position: Vector2:
	get: return _screen_position
## World position of the menu
@onready var world_position: Vector2:
	get: return camera.ui_to_global(_screen_position)
#endregion

#region Private Variables
var _screen_position: Vector2
var _selection_radius := 12.0
var _button_containers: Array[Control] = []
var _menu_buttons: Array[Button] = []
var tracked_ant: Ant = null
var tracked_colony: Colony = null
#endregion

func _ready() -> void:
	# Initialize menu in closed state
	modulate.a = 0
	scale = Vector2.ZERO

func setup(p_camera: Camera2D) -> void:
	camera = p_camera

func _process(_delta: float) -> void:
	if not camera:
		return

	# Update position based on tracked objects
	if tracked_ant and is_instance_valid(tracked_ant):
		_screen_position = camera.global_to_ui(tracked_ant.global_position)
	elif tracked_colony and is_instance_valid(tracked_colony):
		_screen_position = camera.global_to_ui(tracked_colony.global_position)

	position = screen_position
	queue_redraw()

## Creates and adds a new button to the menu
func add_button(text: String, style_normal: StyleBox, style_hover: StyleBox) -> Button:
	var container = _create_button_container()
	var button = _create_button(container, text, style_normal, style_hover)

	_button_containers.append(container)
	_menu_buttons.append(button)
	return button

## Shows the menu at a specific position
func show_at(pos: Vector2, circle_radius: float = 12.0) -> void:
	_screen_position = pos
	_selection_radius = circle_radius
	position = pos
	show()
	_animate_open()

func _draw() -> void:
	if _selection_radius > 0 and camera:
		var scaled_radius = _selection_radius * camera.zoom.x
		draw_arc(
			Vector2.ZERO,
			scaled_radius,
			0,
			TAU,
			32,
			SELECTION_STYLE.CIRCLE_COLOR,
			SELECTION_STYLE.CIRCLE_WIDTH * camera.zoom.x
		)

## Creates a container for a button
func _create_button_container() -> Control:
	var container = Control.new()
	container.custom_minimum_size = BUTTON_SIZE
	add_child(container)
	return container

## Creates a button with label within a container
func _create_button(container: Control, text: String, style_normal: StyleBox,
		style_hover: StyleBox) -> Button:
	var button = Button.new()
	button.custom_minimum_size = container.custom_minimum_size
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)

	# Center the pivot point for rotation
	button.pivot_offset = BUTTON_SIZE / 2
	button.position = -BUTTON_SIZE / 2

	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = BUTTON_SIZE
	label.size = BUTTON_SIZE
	button.add_child(label)

	container.add_child(button)
	return button

func _animate_open() -> void:
	if is_open:
		return

	is_open = true
	var num_buttons = _button_containers.size()
	var angle_per_button = (TAU - (BUTTON_GAP * num_buttons)) / num_buttons

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	# Fade in and scale up the entire menu
	tween.tween_property(self, "modulate:a", 1.0, ANIMATION_DURATION)
	tween.tween_property(self, "scale", Vector2.ONE, ANIMATION_DURATION)

	# Position and rotate each button
	for i in range(num_buttons):
		var container = _button_containers[i]
		var button = _menu_buttons[i]

		# Calculate final position and rotation
		var angle = -PI/2 + i * (angle_per_button + BUTTON_GAP)
		var target_pos = Vector2(cos(angle), sin(angle)) * RADIUS

		# Animate container position
		tween.tween_property(container, "position", target_pos, ANIMATION_DURATION)

		# Animate container rotation, keeping text upright
		var target_rotation = angle + PI/2
		tween.tween_property(container, "rotation", target_rotation, ANIMATION_DURATION)

func close() -> void:
	if is_open:
		_animate_close()

func _animate_close() -> void:
	if not is_open:
		return

	is_open = false
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_BACK)

	# Fade out and scale down the entire menu
	tween.tween_property(self, "modulate:a", 0.0, ANIMATION_DURATION)
	tween.tween_property(self, "scale", Vector2.ZERO, ANIMATION_DURATION)

	# Reset positions and rotations
	for container in _button_containers:
		tween.tween_property(container, "position", Vector2.ZERO, ANIMATION_DURATION)
		tween.tween_property(container, "rotation", 0.0, ANIMATION_DURATION)

	tween.tween_callback(queue_free)
