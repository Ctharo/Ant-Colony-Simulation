extends Camera2D

#region Camera Constants
## Minimum zoom level allowed for the camera
const MIN_ZOOM := 0.1

## Maximum zoom level allowed for the camera
const MAX_ZOOM := 3.0

## Speed at which the camera zooms in/out
const ZOOM_SPEED := 0.1

## Base speed for camera panning
const PAN_SPEED := 800.0

## Dampening factor for smooth camera movement
const SMOOTHING_FACTOR := 0.85
#endregion

#region Camera State Variables
## Flag to track if camera is currently being panned
var is_panning := false

## Stores the last known mouse position for pan calculations
var last_mouse_position := Vector2.ZERO

## Target position for smooth camera movement
var target_position := Vector2.ZERO

## Current velocity of the camera movement
var current_velocity := Vector2.ZERO
#endregion

func _ready() -> void:
	# Initialize camera position and settings
	target_position = position
	
	# Ensure drag is enabled for proper panning
	set_process_input(true)
	set_process(true)

func _process(delta: float) -> void:
	if not is_instance_valid(self):
		return
		
	# Smooth camera movement
	if not is_panning:
		position = position.lerp(target_position, SMOOTHING_FACTOR)
		current_velocity = current_velocity * (1.0 - SMOOTHING_FACTOR)

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(event):
		return
		
	# Handle mouse wheel zoom
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	# Handle mouse motion for panning
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_handle_zoom(ZOOM_SPEED, event.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			_handle_zoom(-ZOOM_SPEED, event.position)
		MOUSE_BUTTON_MIDDLE:
			_handle_pan_start(event)

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not is_panning:
		return
		
	var delta := event.position - last_mouse_position
	var scaled_delta := delta * zoom
	
	# Update camera position with momentum
	current_velocity = scaled_delta * PAN_SPEED * get_process_delta_time()
	target_position -= current_velocity
	position -= current_velocity
	
	last_mouse_position = event.position

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

func ui_to_global(screen_position: Vector2) -> Vector2:
	if not is_instance_valid(self):
		return Vector2.ZERO
		
	var viewport_size := get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		return Vector2.ZERO
		
	var relative_pos := screen_position - viewport_size / 2
	var scaled_pos := relative_pos / zoom
	return position + scaled_pos

func global_to_ui(p_global_position: Vector2) -> Vector2:
	if not is_instance_valid(self):
		return Vector2.ZERO
		
	return get_canvas_transform() * p_global_position
