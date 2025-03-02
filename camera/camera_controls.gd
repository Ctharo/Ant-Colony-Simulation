class_name CameraController
extends Camera2D

#region Camera Constants
const MIN_ZOOM := 0.1
const MAX_ZOOM := 3.0
const ZOOM_SPEED := 0.1
const PAN_SPEED := 400.0
const KEYBOARD_PAN_SPEED := 500.0
const SMOOTHING_FACTOR := 0.85
const HOVERED_ENTITY_DISTANCE := 10
#endregion

#region Camera State Variables
var is_panning := false
var last_mouse_position := Vector2.ZERO
var target_position := Vector2.ZERO :
	set(value):
		target_position = value
var current_velocity := Vector2.ZERO
var tracked_entity: Node2D
var hovered_entity: Node2D
#endregion

func _ready() -> void:
	set_process_input(true)
	set_process(true)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or \
	   event.is_action_pressed("ui_right") or \
	   event.is_action_pressed("ui_up") or \
	   event.is_action_pressed("ui_down"):
		stop_tracking()

func _handle_keyboard_input(delta: float) -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("ui_left", "ui_right")
	input_dir.y = Input.get_axis("ui_up", "ui_down")

	if input_dir != Vector2.ZERO:
		stop_tracking()
		position += input_dir.normalized() * KEYBOARD_PAN_SPEED * delta

func _process(delta: float) -> void:
	queue_redraw()

	if not is_instance_valid(self):
		return

	if is_instance_valid(hovered_entity):
		if to_local(hovered_entity.global_position).distance_to(get_local_mouse_position()) > HOVERED_ENTITY_DISTANCE:
			hovered_entity = null

	var entities: Array = []
	entities.append_array(get_tree().get_nodes_in_group("ant"))
	entities.append_array(get_tree().get_nodes_in_group("colony"))

	for entity in entities:
		var pos: Vector2 = to_local(entity.global_position)
		var distance = HOVERED_ENTITY_DISTANCE
		if entity is Colony:
			distance += entity.radius

		if pos.distance_to(get_local_mouse_position()) < distance:
			hovered_entity = entity
			break

	_handle_keyboard_input(delta)

	if is_instance_valid(tracked_entity):
		target_position = tracked_entity.global_position
		position = target_position

	current_velocity = current_velocity * (1.0 - SMOOTHING_FACTOR)

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(event):
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_handle_zoom(ZOOM_SPEED, event.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			_handle_zoom(-ZOOM_SPEED, event.position)
		MOUSE_BUTTON_MIDDLE:
			stop_tracking()  # Stop tracking when manual movement starts
			_handle_pan_start(event)

func _handle_pan_start(event: InputEventMouseButton) -> void:
	is_panning = event.pressed
	if is_panning:
		last_mouse_position = event.position
		# Reset velocity when starting new pan
		current_velocity = Vector2.ZERO
	else:
		# Apply final momentum when releasing pan
		target_position = position + current_velocity * 10.0

func _handle_zoom(zoom_factor: float, mouse_position: Vector2) -> void:
	if not is_instance_valid(self):
		return

	# Calculate new zoom level
	var new_zoom: Vector2 = Vector2.ONE * clamp(
		zoom.x + zoom_factor,
		MIN_ZOOM,
		MAX_ZOOM
	)

	# Store old zoom for position adjustment
	var old_zoom := zoom

	# Update zoom
	zoom = new_zoom

	# Adjust position to zoom towards mouse cursor
	var mouse_world_pos := ui_to_global(mouse_position)
	position += (mouse_world_pos - position) * (1 - new_zoom.x / old_zoom.x)

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not is_panning:
		return

	var delta := event.position - last_mouse_position

	# Update camera position with momentum
	current_velocity = delta * PAN_SPEED * get_process_delta_time()
	target_position -= current_velocity
	position -= current_velocity

	last_mouse_position = event.position

func track_entity(entity: Node2D) -> void:
	stop_tracking()  # Clear previous tracking first
	tracked_entity = entity

func stop_tracking() -> void:
	tracked_entity = null

## Converts from screen position to global coordinates
func ui_to_global(screen_position: Vector2) -> Vector2:
	if not is_instance_valid(self):
		return Vector2.ZERO

	var viewport_size := get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		return Vector2.ZERO

	var relative_pos := screen_position - viewport_size / 2
	var scaled_pos := relative_pos / zoom
	return position + scaled_pos

## Converts from global coordinates to screen position
func global_to_ui(p_global_position: Vector2) -> Vector2:
	if not is_instance_valid(self):
		return Vector2.ZERO
	var ui_pos: Vector2 = get_global_transform_with_canvas() * to_local(p_global_position)
	return ui_pos

func _draw() -> void:
	_draw_mouse_pos_circle(get_local_mouse_position())

func _draw_mouse_pos_circle(mouse_pos: Vector2):
	var radius: float = 8
	if is_instance_valid(hovered_entity):
		if hovered_entity is Ant:
			radius = 12
		elif hovered_entity is Colony:
			radius = hovered_entity.radius + 12
		mouse_pos = to_local(hovered_entity.global_position)

	draw_arc(
		   mouse_pos,
		   radius,
		   0,          # Start angle (radians)
		   TAU,        # End angle (full circle)
		   32,         # Number of points
		   Color.WHITE # Circle color
		)
