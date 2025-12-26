class_name CameraController
extends Camera2D
## Camera controller with panning, zooming, entity tracking, and hover detection

#region Constants
const MIN_ZOOM := 0.1
const MAX_ZOOM := 3.0
const ZOOM_SPEED := 0.1
const PAN_SPEED := 400.0
const KEYBOARD_PAN_SPEED := 500.0
const EDGE_PAN_SPEED := 300.0
const EDGE_PAN_MARGIN := 20.0
const SMOOTHING_FACTOR := 0.85
const HOVER_DISTANCE_BASE := 10.0
#endregion

#region State Variables
var is_panning := false
var last_mouse_position := Vector2.ZERO
var target_position := Vector2.ZERO:
	set(value):
		target_position = value
var current_velocity := Vector2.ZERO
var tracked_entity: Node2D
var hovered_entity: Node2D
var edge_panning_enabled := true
#endregion

#region Lifecycle
func _ready() -> void:
	set_process_input(true)
	set_process(true)


func _process(delta: float) -> void:
	queue_redraw()
	
	if not is_instance_valid(self):
		return
	
	_update_hovered_entity()
	_handle_keyboard_input(delta)
	_handle_edge_panning(delta)
	_update_tracked_entity()
	_apply_momentum()


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(event):
		return
	
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or \
	   event.is_action_pressed("ui_right") or \
	   event.is_action_pressed("ui_up") or \
	   event.is_action_pressed("ui_down"):
		stop_tracking()
#endregion

#region Input Handling
func _handle_keyboard_input(delta: float) -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("ui_left", "ui_right")
	input_dir.y = Input.get_axis("ui_up", "ui_down")
	
	if input_dir != Vector2.ZERO:
		stop_tracking()
		position += input_dir.normalized() * KEYBOARD_PAN_SPEED * delta


func _handle_edge_panning(delta: float) -> void:
	if not edge_panning_enabled or is_panning:
		return
	
	var viewport_size := get_viewport_rect().size
	var mouse_pos := get_viewport().get_mouse_position()
	var pan_direction := Vector2.ZERO
	
	if mouse_pos.x < EDGE_PAN_MARGIN:
		pan_direction.x = -1.0
	elif mouse_pos.x > viewport_size.x - EDGE_PAN_MARGIN:
		pan_direction.x = 1.0
	
	if mouse_pos.y < EDGE_PAN_MARGIN:
		pan_direction.y = -1.0
	elif mouse_pos.y > viewport_size.y - EDGE_PAN_MARGIN:
		pan_direction.y = 1.0
	
	if pan_direction != Vector2.ZERO:
		stop_tracking()
		position += pan_direction.normalized() * EDGE_PAN_SPEED * delta / zoom.x


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_handle_zoom(ZOOM_SPEED, event.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			_handle_zoom(-ZOOM_SPEED, event.position)
		MOUSE_BUTTON_MIDDLE:
			stop_tracking()
			_handle_pan_start(event)


func _handle_pan_start(event: InputEventMouseButton) -> void:
	is_panning = event.pressed
	if is_panning:
		last_mouse_position = event.position
		current_velocity = Vector2.ZERO
	else:
		target_position = position + current_velocity * 10.0


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not is_panning:
		return
	
	var delta := event.position - last_mouse_position
	current_velocity = delta * PAN_SPEED * get_process_delta_time() / zoom.x
	target_position -= current_velocity
	position -= current_velocity
	last_mouse_position = event.position


func _handle_zoom(zoom_factor: float, mouse_position: Vector2) -> void:
	if not is_instance_valid(self):
		return
	
	var new_zoom := Vector2.ONE * clampf(zoom.x + zoom_factor, MIN_ZOOM, MAX_ZOOM)
	var old_zoom := zoom
	
	zoom = new_zoom
	
	var mouse_world_pos := screen_to_world(mouse_position)
	position += (mouse_world_pos - position) * (1 - new_zoom.x / old_zoom.x)
#endregion

#region Entity Tracking
func _update_hovered_entity() -> void:
	var mouse_local := get_local_mouse_position()
	
	if is_instance_valid(hovered_entity):
		var entity_local := to_local(hovered_entity.global_position)
		var hover_distance := _get_entity_hover_distance(hovered_entity)
		if entity_local.distance_to(mouse_local) > hover_distance:
			hovered_entity = null
	
	var entities: Array = []
	entities.append_array(get_tree().get_nodes_in_group("ant"))
	entities.append_array(get_tree().get_nodes_in_group("colony"))
	
	for entity in entities:
		var entity_local := to_local(entity.global_position)
		var hover_distance := _get_entity_hover_distance(entity)
		
		if entity_local.distance_to(mouse_local) < hover_distance:
			hovered_entity = entity
			break


func _get_entity_hover_distance(entity: Node2D) -> float:
	var distance := HOVER_DISTANCE_BASE
	if entity is Colony:
		distance += entity.radius
	return distance


func _update_tracked_entity() -> void:
	if is_instance_valid(tracked_entity):
		target_position = tracked_entity.global_position
		position = target_position


func _apply_momentum() -> void:
	current_velocity = current_velocity * (1.0 - SMOOTHING_FACTOR)


func track_entity(entity: Node2D) -> void:
	stop_tracking()
	tracked_entity = entity


func stop_tracking() -> void:
	tracked_entity = null
#endregion

#region Coordinate Conversion
## Converts screen position to world coordinates
func screen_to_world(screen_position: Vector2) -> Vector2:
	if not is_instance_valid(self):
		return Vector2.ZERO
	
	var viewport_size := get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		return Vector2.ZERO
	
	var relative_pos := screen_position - viewport_size / 2.0
	var scaled_pos := relative_pos / zoom
	return position + scaled_pos


## Alias for screen_to_world for backwards compatibility
func ui_to_global(screen_position: Vector2) -> Vector2:
	return screen_to_world(screen_position)


## Converts world coordinates to screen position
func world_to_screen(world_position: Vector2) -> Vector2:
	if not is_instance_valid(self):
		return Vector2.ZERO
	return get_global_transform_with_canvas() * to_local(world_position)


## Alias for world_to_screen for backwards compatibility
func global_to_ui(world_position: Vector2) -> Vector2:
	return world_to_screen(world_position)


## Get mouse position in world coordinates
func get_mouse_world_position() -> Vector2:
	return screen_to_world(get_viewport().get_mouse_position())
#endregion

#region Drawing
func _draw() -> void:
	_draw_cursor_indicator()


func _draw_cursor_indicator() -> void:
	var mouse_pos := get_local_mouse_position()
	var radius := 8.0
	
	if is_instance_valid(hovered_entity):
		if hovered_entity is Ant:
			radius = 12.0
		elif hovered_entity is Colony:
			radius = hovered_entity.radius + 12.0
		mouse_pos = to_local(hovered_entity.global_position)
	
	draw_arc(mouse_pos, radius, 0, TAU, 32, Color.WHITE)
#endregion
