class_name Move
extends Action

#region Properties
## Target position to move to (can be a static Vector2 or dynamic position)
@export var target_position: Vector2

## Whether the movement should be continuous
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

## Class to store move-specific instance state
class MoveInstanceState extends ActionInstanceState:
	var velocity: Vector2 = Vector2.ZERO
	var target_reached: bool = false
	var current_target: Vector2
#endregion

#region Protected Methods
## Override instance state creation to use MoveInstanceState
func initialize(entity: Node) -> void:
	if not entity:
		logger.error("Cannot initialize move action with null entity")
		return
		
	var instance_id = entity.get_instance_id()
	if instance_id not in _instance_states:
		_instance_states[instance_id] = MoveInstanceState.new()
		
	super.initialize(entity)

## Override to return move-specific instance state
func _get_instance_state(entity: Node) -> MoveInstanceState:
	if not entity:
		return null
	return _instance_states.get(entity.get_instance_id()) as MoveInstanceState

## Validate movement parameters for an entity
func _validate_params(entity: Node) -> bool:
	if not entity:
		logger.error("No entity assigned to move action")
		return false
		
	var state = _get_instance_state(entity)
	if not state:
		logger.error("No state found for entity in move action")
		return false
		
	if not is_random and not target_position:
		logger.error("No target position set for move action")
		return false
		
	return true

## Update movement execution for an entity
func _update_execution(entity: Node, delta: float) -> void:
	var state = _get_instance_state(entity)
	if not state:
		logger.error("State not found")
		return
	
	var current_pos = entity.global_position
	var target = state.current_target if is_random else target_position
	var direction = (target - current_pos).normalized()
	var distance = current_pos.distance_to(target)
	
	if distance < arrival_threshold:
		if not is_continuous:
			state.target_reached = true
			_complete_execution(entity)
		return
		
	# Apply steering behavior
	var desired_velocity = direction * speed
	var steering = (desired_velocity - state.velocity).limit_length(max_steering)
	state.velocity = (state.velocity + steering).limit_length(max_speed)
	
	# Update position
	entity.velocity = state.velocity
	entity.move_and_slide()
	
	# Update rotation if needed
	if face_direction and state.velocity.length() > 0:
		entity.rotation = state.velocity.angle()

## Start movement execution for an entity
func _start_execution(entity: Node) -> void:
	var state = _get_instance_state(entity)
	if state:
		if is_random:
			state.current_target = entity.global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		else:
			state.current_target = target_position
			
		state.velocity = Vector2.ZERO
		state.target_reached = false
		
	super._start_execution(entity)
#endregion
