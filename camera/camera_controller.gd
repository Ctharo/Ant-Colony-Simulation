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
const ZOOM_STEP := 1.1              # multiplicative per wheel notch
const FAST_PAN_MULTIPLIER := 3.0    # shift + direction
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
	if not is_instance_valid(self):
		return

	_update_hovered_entity()
	_handle_keyboard_input(delta)
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

#region Keyboard Focus Guard
## True when the keyboard "belongs" to something other than the camera:
##  - a LineEdit/TextEdit is focused in the main viewport, OR
##  - any visible embedded tool window (ManagedWindow, dialogs, ...) has
##    window focus. Embedded Windows are separate viewports, so the old
##    get_viewport().gui_get_focus_owner() check could never see focus
##    inside the designer — that's why WASD kept panning while typing.
static func is_keyboard_captured(tree: SceneTree) -> bool:
	if tree == null:
		return false
	var focus: Control = tree.root.gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return true
	return _any_window_captures_keyboard(tree.root)


static func _any_window_captures_keyboard(node: Node) -> bool:
	for child in node.get_children():
		if child is Window:
			var w := child as Window
			if not w.visible:
				continue
			# A focused tool window owns the keyboard outright; also
			# catch text focus inside it even if focus state is odd.
			if w.has_focus():
				return true
			var inner: Control = w.gui_get_focus_owner()
			if inner is LineEdit or inner is TextEdit:
				return true
			if _any_window_captures_keyboard(w):
				return true
	return false
#endregion

#region Input Handling
func _handle_keyboard_input(delta: float) -> void:
	var input_dir = Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if input_dir == Vector2.ZERO:
		return

	if CameraController.is_keyboard_captured(get_tree()):
		return

	stop_tracking()

	var speed := KEYBOARD_PAN_SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= FAST_PAN_MULTIPLIER

	# Divide by zoom so on-screen pan speed feels the same at
	# every zoom level (matches what edge panning already does).
	position += input_dir.normalized() * speed * delta / zoom.x
	target_position = position


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_handle_zoom(ZOOM_STEP)
		MOUSE_BUTTON_WHEEL_DOWN:
			_handle_zoom(1.0 / ZOOM_STEP)
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


func _handle_zoom(factor: float) -> void:
	var new_zoom: float = clampf(zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(new_zoom, zoom.x):
		return

	var mouse_world_before: Vector2 = get_global_mouse_position()
	zoom = Vector2.ONE * new_zoom

	if is_instance_valid(tracked_entity):
		return  # stay centered on the tracked entity

	var mouse_world_after: Vector2 = get_global_mouse_position()
	position += mouse_world_before - mouse_world_after
	target_position = position
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
## Converts screen position to world coordinates via the actual canvas
## transform — exact under any zoom/offset, unlike the old manual math.
func screen_to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position
#endregion

## NOTE: the cursor indicator is no longer drawn here. Camera-space _draw()
## renders one frame behind input during pans (the circle-lag bug). It now
## lives in SandboxUI._draw() in screen space.
