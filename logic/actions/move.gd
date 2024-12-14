class_name Move
extends Action

#region Properties
## List of influences for this movement 
@export var influences: Array[Influence]
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

#region Internal State
var _entity_state: Dictionary = {}

func _get_entity_state(entity_id: String) -> Dictionary:
	if not _entity_state.has(entity_id):
		_entity_state[entity_id] = {
			"velocity": Vector2.ZERO,
			"target_reached": false,
			"current_target": Vector2.ZERO,
			"current_rotation": 0.0,
			"nav_agent": null,
			"rng": RandomNumberGenerator.new()
		}
		# Seed RNG uniquely for each entity
		_entity_state[entity_id]["rng"].seed = hash(entity_id + str(Time.get_ticks_msec()))
	return _entity_state[entity_id]

func _setup_dependencies(dependencies: Dictionary) -> void:
	super._setup_dependencies(dependencies)
	var state = _get_entity_state(entity.name)
	state.nav_agent = entity.get_node_or_null("%NavigationAgent2D")
	if not state.nav_agent:
		logger.error("No NavigationAgent2D found on entity")
		return


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
		var state = _get_entity_state(entity.name)
		state.current_rotation = entity.rotation if entity else 0.0

## Check if position is navigable
func _is_navigable(location: Vector2) -> bool:
	var space_state = entity.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = location
	query.collision_mask = 1  # Adjust mask based on your collision layers
	return space_state.intersect_point(query).is_empty()

func _start_execution() -> void:
	super._start_execution()
		
	# Use entity-specific state
	var state = _get_entity_state(entity.name)
	state.velocity = Vector2.ZERO
	state.current_target = calculate_target_position()
	state.nav_agent.target_position = state.current_target

func calculate_target_position() -> Vector2:
	var state = _get_entity_state(entity.name)
	var total_weight = 0.0
	var weighted_direction = Vector2.ZERO
	
	for influence: Influence in influences:
		var weight = influence.weight.get_value(true)
		var dir = influence.direction.get_value(true)
		total_weight += weight
		weighted_direction += dir * weight
	
	if total_weight > 0:
		weighted_direction = (weighted_direction / total_weight).normalized()
	
	# Use entity-specific RNG for random movement
	var distance = state.rng.randf_range(15, 45)
	var angle = state.rng.randf_range(-max_random_angle, max_random_angle)
	weighted_direction = weighted_direction.rotated(angle)
	
	return entity.global_position + weighted_direction * distance

## Update movement execution
func _update_execution(delta: float) -> void:
	var state = _get_entity_state(entity.name)
	if not state.nav_agent:
		return
		
	var current_pos = entity.global_position
	var distance_to_target = current_pos.distance_to(state.current_target) if state.current_target else INF
	
	if distance_to_target <= state.nav_agent.target_desired_distance * 1.5:
		state.current_target = calculate_target_position()
		state.nav_agent.target_position = state.current_target
		return
		
	if state.nav_agent.is_navigation_finished():
		if distance_to_target > state.nav_agent.target_desired_distance * 2:
			state.current_target = calculate_target_position()
			state.nav_agent.target_position = state.current_target
			return
			
	if not state.current_target:
		state.current_target = calculate_target_position()
		state.nav_agent.target_position = state.current_target
		
	var next_pos = state.nav_agent.get_next_path_position()
	var direction = (next_pos - current_pos).normalized()
	var target_velocity = direction * speed
	
	# Entity-specific velocity lerping
	state.velocity = state.velocity.lerp(target_velocity, 0.15)
	
	entity.velocity = state.velocity
	if face_direction:
		entity.global_rotation = state.velocity.angle()
	entity.move_and_slide()
	
func _complete_execution() -> void:
	var state = _get_entity_state(entity.name)
	state.target_reached = true
	state.velocity = Vector2.ZERO
	entity.velocity = Vector2.ZERO
	super._complete_execution()

# Clear entity state when it's no longer needed
func _cleanup_entity(entity_id: String) -> void:
	if _entity_state.has(entity_id):
		_entity_state.erase(entity_id)
