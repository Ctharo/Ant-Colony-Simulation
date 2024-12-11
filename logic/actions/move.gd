class_name Move
extends Action

#region Properties
@export var influence_profile: InfluenceProfile
## Minimum distance to consider target reached
@export var arrival_threshold: float = 5.0
## Movement speed in pixels per second
@export var speed: float = 35.0
## Whether to rotate towards movement direction
@export var face_direction: bool = true
## How quickly to turn (0-1, lower = smoother)
@export_range(0.0, 1.0) var turn_speed: float = 0.1
## Maximum angle for random movement deviation
@export var max_random_angle: float = PI/3  # 60 degrees

const TARGET_DISTANCE: float = 15.0
#region Internal State
var _velocity: Vector2 = Vector2.ZERO
var _target_reached: bool = false
var _current_target: Vector2
var _current_rotation: float = 0.0
var _nav_agent: NavigationAgent2D

## Read-only property for current target position
var target_position: Vector2:
	get:
		return _current_target
#endregion

func _setup_dependencies(dependencies: Dictionary) -> void:
	super._setup_dependencies(dependencies)
	_setup_navigation()


func _setup_navigation() -> void:
	if not entity:
		logger.error("Cannot setup navigation without entity")
		return
		
	_nav_agent = entity.get_node_or_null("%NavigationAgent2D")
	if not _nav_agent:
		logger.error("No NavigationAgent2D found on entity")
		return
	

func _post_initialize() -> void:
	if face_direction:
		_current_rotation = entity.rotation if entity else 0.0

## Check if position is navigable
func _is_navigable(location: Vector2) -> bool:
	var space_state = entity.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = location
	query.collision_mask = 1  # Adjust mask based on your collision layers
	return space_state.intersect_point(query).is_empty()

## Start movement execution
func _start_execution() -> void:
	super._start_execution()
	if not influence_profile:
		influence_profile = load("res://resources/influence/configs/wandering_for_food.tres")
	_velocity = Vector2.ZERO
	_nav_agent.target_position = calculate_target_position()

func calculate_target_position() -> Vector2:
	var total_weight = 0.0
	var weighted_direction = Vector2.ZERO
	
	# Sum up all weighted directions
	for influence: Influence in influence_profile.influences:
		var weight = influence.weight.get_value(true)
		var dir = influence.direction.get_value(true)
		total_weight += weight
		weighted_direction += dir * weight
	
	# Normalize the weighted direction before applying distance
	if total_weight > 0:
		weighted_direction = (weighted_direction / total_weight).normalized()
	
	# Return position offset by the normalized direction
	return entity.global_position + weighted_direction * TARGET_DISTANCE

## Update movement execution
func _update_execution(delta: float) -> void:
	if not _nav_agent:
		return
		
	var current_pos = entity.global_position
	var distance_to_target = current_pos.distance_to(_current_target) if _current_target else INF
	
	# Get new target when we're close, but not exactly at target
	# This should make movement more continuous
	if distance_to_target <= _nav_agent.target_desired_distance * 1.5:  # Increased threshold
		_current_target = calculate_target_position()
		_nav_agent.target_position = _current_target
		return
		
	# If navigation is finished but we haven't reached target, keep moving toward it
	if _nav_agent.is_navigation_finished():
		# Only get new target if we're really stuck
		if distance_to_target > _nav_agent.target_desired_distance * 2:
			_current_target = calculate_target_position()
			_nav_agent.target_position = _current_target
			return
			
	# Get new target if we don't have one
	if not _current_target:
		_current_target = calculate_target_position()
		_nav_agent.target_position = _current_target
		
	var next_pos = _nav_agent.get_next_path_position()
	var direction = (next_pos - current_pos).normalized()
	var target_velocity = direction * speed
	
	# Increased lerp factor for smoother acceleration
	_velocity = _velocity.lerp(target_velocity, 0.15)  # Slightly faster response
	
	# Update position
	entity.velocity = _velocity
	if face_direction:
		entity.global_rotation = _velocity.angle()
	entity.move_and_slide()
	
func _complete_execution() -> void:
	_target_reached = true
	_velocity = Vector2.ZERO
	entity.velocity = Vector2.ZERO
	super._complete_execution()
