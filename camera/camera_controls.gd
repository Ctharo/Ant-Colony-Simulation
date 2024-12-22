extends Camera2D

## Zoom limits and speed
const MIN_ZOOM := 0.1
const MAX_ZOOM := 3.0
const ZOOM_SPEED := 0.1

## Pan settings
const PAN_SPEED := 800.0
var is_panning := false
var last_mouse_position := Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	# Handle zooming with mouse wheel
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_handle_zoom(ZOOM_SPEED, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_handle_zoom(-ZOOM_SPEED, event.position)
		# Handle middle mouse button for panning
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = event.pressed
			if is_panning:
				last_mouse_position = event.position

	# Handle mouse motion while panning
	elif event is InputEventMouseMotion and is_panning:
		var delta = (event.position - last_mouse_position) * zoom
		position -= delta
		last_mouse_position = event.position

func _handle_zoom(zoom_factor: float, mouse_position: Vector2) -> void:
	# Store the mouse position in viewport coordinates
	var mouse_viewport = mouse_position

	# Get the mouse position in the world before zooming
	var old_world_pos = get_screen_to_canvas(mouse_viewport)

	# Update zoom level
	var new_zoom = Vector2.ONE * clamp(
		zoom.x + zoom_factor,
		MIN_ZOOM,
		MAX_ZOOM
	)
	zoom = new_zoom

	# Get the new mouse position in the world
	var new_world_pos = get_screen_to_canvas(mouse_viewport)

	# Adjust position to keep mouse over the same world position
	position += (new_world_pos - old_world_pos) * zoom

func get_screen_to_canvas(screen_position: Vector2) -> Vector2:
	return screen_position * zoom + position
