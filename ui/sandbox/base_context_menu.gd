class_name BaseContextMenu
extends Control

## Radius of the circular menu layout
@export var RADIUS = 70.0
## Styling for selection indicator
const SELECTION_STYLE = {
	"CIRCLE_COLOR": Color(Color.WHITE, 0.5),
	"CIRCLE_WIDTH": 2.0
}
## Standard button dimensions
@export var BUTTON_SIZE = Vector2(125, 40)
## Duration of open/close animations
const ANIMATION_DURATION = 0.3
## Angular gap between buttons in radians
@export var BUTTON_GAP = 0.05
## Hover animation properties
const HOVER_SCALE = 1.05
const HOVER_DURATION = 0.1
signal button_pressed(index: int)

#region Public Properties
## Whether the menu is currently open
var is_open := false
## Reference to the main camera
var camera: CameraController
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
	var button = _create_button(text, style_normal, style_hover)
	add_child(button)
	var button_index = _menu_buttons.size()
	button.pressed.connect(func(): button_pressed.emit(button_index))
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

## Creates a button with label within a container
func _create_button(text: String, style_normal: StyleBox,
		style_hover: StyleBox) -> Button:
	var button = Button.new()
	button.custom_minimum_size = BUTTON_SIZE
	
	# Clone the styles to modify them
	var normal_style = style_normal.duplicate()
	var hover_style = style_hover.duplicate()
	
	# Set up the hover style with black border
	hover_style.border_color = Color.BLACK
	hover_style.border_width_left = 2
	hover_style.border_width_top = 2
	hover_style.border_width_right = 2
	hover_style.border_width_bottom = 2
	
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.text = text
	
	# Add hover animations
	button.mouse_entered.connect(func(): _on_button_hover(button, true))
	button.mouse_exited.connect(func(): _on_button_hover(button, false))
	
	return button

## Handles button hover state changes
func _on_button_hover(button: Button, is_hover: bool) -> void:
	var target_scale = Vector2.ONE * HOVER_SCALE if is_hover else Vector2.ONE
	
	# Create hover animation tween
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(button, "scale", target_scale, HOVER_DURATION)

## Animates the radial menu opening, calculating screen positions for buttons
## without rotating them for better readability
func _animate_open() -> void:
	if is_open:
		return
		
	is_open = true
	
	# Calculate layout parameters
	var num_buttons: int = _menu_buttons.size()
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
		var button: Button = _menu_buttons[i]
		
		# Calculate the angle for this button
		var angle: float = -PI/2 + i * (angle_per_button + BUTTON_GAP)
		
		# Calculate target position using polar coordinates
		var target_pos: Vector2 = Vector2(
			cos(angle) * RADIUS,
			sin(angle) * RADIUS
		) - BUTTON_SIZE/2
				
		# Animate container position
		tween.tween_property(
			button,
			"position",
			target_pos,
			ANIMATION_DURATION
		)

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
	tween.tween_property(self, "modulate:a", 0.0, ANIMATION_DURATION/2)
	tween.tween_property(self, "scale", Vector2.ZERO, ANIMATION_DURATION/2)
	
	tween.tween_callback(queue_free).set_delay(ANIMATION_DURATION/2)
