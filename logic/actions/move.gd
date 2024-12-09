class_name Move
extends Action

#region Properties
## Target position to move to (can be a static Vector2 or dynamic position)
@export var target_position: Vector2

## Whether the movement should be continuous (keep updating target position)
@export var is_continuous: bool = false

@export var is_random: bool = false

## Minimum distance to consider target reached
@export var arrival_threshold: float = 5.0

## Movement speed in pixels per second
@export var speed: float = 100.0

## Whether to rotate towards movement direction
@export var face_direction: bool = true

## Maximum steering force to apply
@export var max_steering: float = 200.0

## Maximum speed when steering
@export var max_speed: float = 150.0
#endregion

#region Internal State
var _velocity: Vector2 = Vector2.ZERO
var _target_reached: bool = false
#endregion

#region Protected Methods
## Validate movement parameters
func _validate_params() -> bool:
	# Check required parameters
	if not _entity:
		logger.error("No entity assigned to move action")
		return false
		
	if not target_position:
		logger.error("No target position set for move action")
		return false
		
	return true

## Update movement execution
func _update_execution(delta: float) -> void:
	var current_pos = _entity.global_position
	var direction = (target_position - current_pos).normalized()
	var distance = current_pos.distance_to(target_position)
	
	if distance < arrival_threshold:
		if not is_continuous:
			_target_reached = true
			_complete_execution()
		return
		
	# Apply steering behavior
	var desired_velocity = direction * speed
	var steering = (desired_velocity - _velocity).limit_length(max_steering)
	_velocity = (_velocity + steering).limit_length(max_speed)
	
	# Update position
	_entity.velocity = _velocity
	_entity.move_and_slide()
	
	# Update rotation if needed
	if face_direction and _velocity.length() > 0:
		_entity.rotation = _velocity.angle()

## Start movement execution
func _start_execution() -> void:
	super._start_execution()
	if is_random:
		target_position = _entity.global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))

	_velocity = Vector2.ZERO
	_target_reached = false
#endregion
