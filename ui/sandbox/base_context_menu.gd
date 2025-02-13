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

signal button_pressed(index: int)

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
var _tracked_object = null  # Generic tracked object reference
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

	# Update position based on tracked object if it exists and is valid
	if _tracked_object and is_instance_valid(_tracked_object) and _tracked_object.has_method("get_global_position"):
		_screen_position = camera.global_to_ui(_tracked_object.global_position)

	position = screen_position
	queue_redraw()

## Sets an object to track for menu positioning
func track_object(object) -> void:
	_tracked_object = object

## Creates and adds a new button to the menu
func add_button(text: String, style_normal: StyleBox, style_hover: StyleBox) -> Button:
	var container = _create_button_container()
	var button = _create_button(container, text, style_normal, style_hover)
	
	var button_index = _menu_buttons.size()
	button.pressed.connect(func(): button_pressed.emit(button_index))

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

	# Create a container for the label that will counter-rotate
	var label_container = Control.new()
	label_container.custom_minimum_size = BUTTON_SIZE
	label_container.position = BUTTON_SIZE / 2
	label_container.pivot_offset = BUTTON_SIZE / 2
	
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = BUTTON_SIZE
	label.size = BUTTON_SIZE
	label.position = -BUTTON_SIZE / 2
	
	label_container.add_child(label)
	button.add_child(label_container)
	container.add_child(button)
	
	# Store label container for rotation updates
	button.set_meta("label_container", label_container)
	
	return button

## Animates the radial menu opening, calculating screen positions for buttons
## without rotating them for better readability
func _animate_open() -> void:
	if is_open:
		return
		
	is_open = true
	
	# Calculate layout parameters
	var num_buttons: int = _button_containers.size()
	var angle_per_button: float = (TAU - (BUTTON_GAP * num_buttons)) / num_buttons
	
	# Setup animation tween
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Animate menu container properties
	tween.tween_property(self, "modulate:a", 1.0, ANIMATION_DURATION)
	tween.tween_property(self, "scale", Vector2.ONE, ANIMATION_DURATION)
	
	# Position each button around the circle
	for i in range(num_buttons):
		var container: Control = _button_containers[i]
		var button: Button = _menu_buttons[i]
		var label_container: Control = button.get_meta("label_container")
		
		# Calculate the angle for this button
		var angle: float = -PI/2 + i * (angle_per_button + BUTTON_GAP)
		
		# Calculate target position using polar coordinates
		var target_pos: Vector2 = Vector2(
			cos(angle) * RADIUS,
			sin(angle) * RADIUS
		)
		
		# Calculate label offset to maintain readability
		# This keeps text horizontal while following the radial layout
		var label_offset: Vector2 = target_pos.normalized() * LABEL_DISTANCE
		
		# Animate container position
		tween.tween_property(
			container,
			"position",
			target_pos,
			ANIMATION_DURATION
		)

## Constant for label distance from button center
const LABEL_DISTANCE: float = 20.0  # Adjust based on your UI needs
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
	for i in range(_button_containers.size()):
		var container = _button_containers[i]
		var label_container = _menu_buttons[i].get_meta("label_container")
		
		tween.tween_property(container, "position", Vector2.ZERO, ANIMATION_DURATION)
		tween.tween_property(container, "rotation", 0.0, ANIMATION_DURATION)
		tween.tween_property(label_container, "rotation", 0.0, ANIMATION_DURATION)

	tween.tween_callback(queue_free)
