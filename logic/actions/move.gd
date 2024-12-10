class_name Move
extends Action

#region Properties
## Expression returning target to move towards
@export var target: Logic
## Target position to move to
var target_position: Vector2

## Whether the movement should be continuous
@export var is_continuous: bool = false

## Enable random movement
var is_random: bool :
	get:
		return target == null

## Maximum random movement range
@export var random_range: float = 50.0

## Minimum distance to consider target reached
var arrival_threshold: float = 5.0

## Movement speed in pixels per second
var speed: float = 35.0

## Whether to rotate towards movement direction
@export var face_direction: bool = true

## How quickly to turn (0-1, lower = smoother)
@export_range(0.0, 1.0) var turn_speed: float = 0.1

## Maximum angle for random movement deviation
@export var max_random_angle: float = PI/3  # 60 degrees

## Color configuration for debug visualization
@export_group("Debug Colors")
@export var forward_color: Color = Color.RED
@export var pheromone_color: Color = Color.YELLOW
@export var colony_color: Color = Color.GREEN
@export var ant_color: Color = Color.PURPLE
@export var random_color: Color = Color.BLUE
@export var exploration_color: Color = Color.ORANGE
#endregion

#region Internal State
var _velocity: Vector2 = Vector2.ZERO
var _target_reached: bool = false
var _current_target: Vector2
var _current_rotation: float = 0.0
var _nav_agent: NavigationAgent2D
#endregion

#region Protected Methods
func initialize(entity: Node) -> void:
	super.initialize(entity)
	_nav_agent = entity.get_node_or_null("%NavigationAgent2D")
	if not _nav_agent:
		logger.error("No NavigationAgent2D found on entity")
		return
		
	# Configure navigation agent
	_nav_agent.path_desired_distance = 4.0  # Distance at which a path point is considered reached
	_nav_agent.target_desired_distance = 4.0  # Distance at which final target is considered reached
	_nav_agent.path_max_distance = 50.0  # Maximum distance path can deviate to avoid obstacles
	_nav_agent.avoidance_enabled = true  # Enable dynamic avoidance
	_nav_agent.radius = 10.0  # Agent's physical size for avoidance
	_nav_agent.neighbor_distance = 50.0  # Distance to look for neighbors for avoidance
	_nav_agent.max_neighbors = 10  # Maximum number of neighbors to consider for avoidance
		
## Get new random target position based on current direction
func _get_random_target() -> Vector2:
	# Get current facing direction
	var current_direction = Vector2.RIGHT.rotated(_current_rotation)
	
	# Random angle within constraints relative to current direction
	var random_angle = randf_range(-max_random_angle, max_random_angle)
	var target_direction = current_direction.rotated(random_angle)
	
	# Random distance within range
	var distance = randf_range(random_range * 0.2, random_range)
	
	# Calculate target position
	return _entity.global_position + target_direction * distance

## Check if position is navigable
func _is_navigable(location: Vector2) -> bool:
	var space_state = _entity.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = location
	query.collision_mask = 1  # Adjust mask based on your collision layers
	return space_state.intersect_point(query).is_empty()

## Update movement execution
func _update_execution(delta: float) -> void:
	if not _nav_agent:
		return
		
	var current_pos = _entity.global_position
	
	# Break down the random target check
	var needs_new_target = false
	var has_no_target = not _current_target
	var target_reached = false
	
	if _current_target:
		target_reached = _nav_agent.is_target_reached()
		
	needs_new_target = is_random and (has_no_target or target_reached)
	
	if needs_new_target:
		logger.debug("Getting new random target. Has no target: %s, Target reached: %s" % [has_no_target, target_reached])
		_current_target = _get_random_target()
		_nav_agent.target_position = _current_target
	
	# Check if navigation is stuck
	if _nav_agent.is_navigation_finished():
		if not target_reached:
			logger.trace("Navigation finished but target not reached, finding new target")
			_current_target = _get_random_target()
			_nav_agent.target_position = _current_target
		return
		
	var next_pos = _nav_agent.get_next_path_position()
	var direction = (next_pos - current_pos).normalized()
	var target_velocity = direction * speed
	
	# Update velocity
	_velocity = _velocity.lerp(target_velocity, 0.1)  # Smooth acceleration
	
	# Update position
	_entity.velocity = _velocity
	if face_direction:
		_entity.global_rotation = _velocity.angle()
	_entity.move_and_slide()


## Start movement execution
func _start_execution() -> void:
	super._start_execution()
	
	_current_rotation = _entity.rotation
	
	if is_random:
		_current_target = _get_random_target()
	else:
		_current_target = target.get_value().global_position
		
	if _nav_agent:
		_nav_agent.target_position = _current_target
		
	_velocity = Vector2.ZERO
	_target_reached = false
#endregion
