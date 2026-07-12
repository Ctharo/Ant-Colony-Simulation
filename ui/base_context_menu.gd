class_name BaseContextMenu
extends Control

signal button_pressed(index: int)
## Radius of the circular menu layout
@export var radius = 70.0
## Menu opacity when fully open (the old code always tweened to 1.0)
@export_range(0.0, 1.0) var menu_opacity := 0.85
## Styling for selection indicator
const SELECTION_STYLE = {
	"CIRCLE_COLOR": Color(Color.WHITE, 0.5),
	"CIRCLE_WIDTH": 2.0
}
## Standard button dimensions
@export var button_size = Vector2(125, 40)
## Duration of open/close animations
const ANIMATION_DURATION = 0.3
## Angular gap between buttons in radians
@export var button_gap = 0.05
## Hover animation properties
const HOVER_SCALE = 1.05
const HOVER_DURATION = 0.1

#region Public Properties
## Whether the menu is currently open
var is_open := false
## Reference to the main camera
var camera: CameraController
## Screen position of the menu (derived from the world anchor each frame)
@onready var screen_position: Vector2:
	get: return _screen_position

var world_position: Vector2:
	get: return _world_position
var _world_position: Vector2  # world-space anchor — the single source of truth
#endregion

#region Private Variables
var _indicator: SelectionIndicator
var _screen_position: Vector2
var _selection_radius := 12.0
var _menu_buttons: Array[Button] = []
var _tracked_object = null  # Generic tracked object reference
#endregion

func _ready() -> void:
	# Initialize menu in closed state
	modulate.a = 0
	scale = Vector2.ZERO
	# Control has zero size; pivot (0,0) sits exactly on the anchor point,
	# so the whole menu scales open from its center.
	pivot_offset = Vector2.ZERO

func setup(p_camera: Camera2D) -> void:
	camera = p_camera

func _process(_delta: float) -> void:
	if not camera:
		return

	if _tracked_object is Node2D and is_instance_valid(_tracked_object):
		_world_position = _tracked_object.global_position

	# The world anchor is authoritative: re-project it to screen every
	# frame so the menu stays glued to the clicked spot (and to its
	# selection circle) while the camera pans or zooms.
	_screen_position = _world_to_screen(_world_position)
	position = _screen_position

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

## Shows the menu anchored at a WORLD position (preferred entry point)
func show_at_world(world_pos: Vector2, circle_radius: float = 12.0) -> void:
	_selection_radius = circle_radius

	if _tracked_object is Node2D and is_instance_valid(_tracked_object):
		_world_position = _tracked_object.global_position
	else:
		_world_position = world_pos

	_screen_position = _world_to_screen(_world_position)
	position = _screen_position
	show()
	_animate_open()
	_spawn_indicator()

## Shows the menu at a SCREEN position (kept for compatibility);
## converts to world immediately so panning can't detach it.
func show_at(pos: Vector2, circle_radius: float = 12.0) -> void:
	show_at_world(_screen_to_world(pos), circle_radius)

## Creates a button with label within a container
func _create_button(text: String, style_normal: StyleBox,
		style_hover: StyleBox) -> Button:
	var button = Button.new()
	button.custom_minimum_size = button_size
	button.size = button_size

	# Start centered on the anchor so the open animation expands the ring
	# outward from the center instead of from the anchor's top-left.
	button.position = -button_size / 2.0
	# Hover scaling pivots around the button's own center, not its corner.
	button.pivot_offset = button_size / 2.0

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

## Animates the radial menu opening, calculating screen positions for
## buttons without rotating them for better readability
func _animate_open() -> void:
	if is_open:
		return

	is_open = true

	# Calculate layout parameters
	var num_buttons: int = _menu_buttons.size()
	if num_buttons == 0:
		return
	var angle_per_button: float = (TAU - (button_gap * num_buttons)) / num_buttons

	# Setup animation tween
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	# Animate menu container properties
	tween.tween_property(self, "modulate:a", menu_opacity, ANIMATION_DURATION)
	tween.tween_property(self, "scale", Vector2.ONE, ANIMATION_DURATION)

	# Position each button around the circle
	for i in range(num_buttons):
		var button: Button = _menu_buttons[i]

		# Calculate the angle for this button
		var angle: float = -PI/2 + i * (angle_per_button + button_gap)

		# Calculate target position using polar coordinates
		var target_pos: Vector2 = Vector2(
			cos(angle) * radius,
			sin(angle) * radius
		) - button_size/2

		# Animate container position (starts at -button_size/2, the center)
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


func _spawn_indicator() -> void:
	if is_instance_valid(_indicator):
		return

	_indicator = SelectionIndicator.new()
	_indicator.menu = self

	# Parent it into the world canvas (NOT the UI CanvasLayer).
	var world_root: Node = get_tree().get_first_node_in_group("sandbox")
	if not world_root and camera:
		world_root = camera.get_parent()
	if world_root:
		world_root.add_child(_indicator)
	else:
		_indicator = null  # no world to draw in; degrade gracefully


func _exit_tree() -> void:
	if is_instance_valid(_indicator):
		_indicator.queue_free()

func _world_to_screen(world_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_pos
func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos

class SelectionIndicator:
	extends Node2D

	var menu: BaseContextMenu

	func _ready() -> void:
		top_level = true   # immune to whatever it gets parented under
		z_index = 10       # draw above entities

	func _process(_delta: float) -> void:
		# Self-destruct if the menu is gone (covers every close path)
		if not is_instance_valid(menu):
			queue_free()
			return
		global_position = menu.world_position
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(menu) or not is_instance_valid(menu.camera):
			return

		var zoom: float = menu.camera.zoom.x
		var sel_r: float = menu._selection_radius
		var color: Color = BaseContextMenu.SELECTION_STYLE.CIRCLE_COLOR
		var width: float = BaseContextMenu.SELECTION_STYLE.CIRCLE_WIDTH

		# Selection circle: drawn at origin in WORLD units. The camera
		# scales it naturally; width divided by zoom keeps constant
		# screen thickness.
		if sel_r > 0.0:
			draw_arc(Vector2.ZERO, sel_r, 0, TAU, 32, color, width / zoom)

		# Leader line to the menu, both endpoints taken via
		# get_global_transform_with_canvas() so world-canvas and UI-layer
		# nodes meet in the same viewport space.
		var xform: Transform2D = get_global_transform_with_canvas()
		var inv: Transform2D = xform.affine_inverse()

		var anchor_screen: Vector2 = xform.origin
		var menu_screen: Vector2 = menu.get_global_transform_with_canvas().origin

		var d: float = menu_screen.distance_to(anchor_screen)
		var sel_r_screen: float = sel_r * zoom
		if d <= menu.radius + sel_r_screen + 4.0:
			return  # anchor still inside the button ring; no line

		var dir: Vector2 = (anchor_screen - menu_screen) / d
		var start_local: Vector2 = inv * (menu_screen + dir * menu.radius)
		var end_local: Vector2 = inv * (anchor_screen - dir * sel_r_screen)

		draw_dashed_line(start_local, end_local, color, width / zoom, 6.0 / zoom)
