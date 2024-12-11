class_name Move
extends Action

#region Properties
## Maximum random movement range
@export var random_range: float = 50.0
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

@export_group("Debug Colors")
@export var forward_color: Color = Color.RED
@export var pheromone_color: Color = Color.YELLOW
@export var colony_color: Color = Color.GREEN
@export var ant_color: Color = Color.PURPLE
@export var random_color: Color = Color.BLUE
@export var exploration_color: Color = Color.ORANGE

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
		
	# Configure navigation agent
	var nav_config := {
		"path_desired_distance": 4.0,
		"target_desired_distance": 4.0,
		"path_max_distance": 50.0,
		"avoidance_enabled": true,
		"radius": 10.0,
		"neighbor_distance": 50.0,
		"max_neighbors": 10
	}
	
	# Apply configuration
	for property in nav_config:
		if property in _nav_agent:
			_nav_agent.set(property, nav_config[property])
		else:
			logger.warn("Navigation property not found: %s" % property)

func _post_initialize() -> void:
	if face_direction:
		_current_rotation = entity.rotation if entity else 0.0

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
	return entity.global_position + target_direction * distance

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
	
	_current_rotation = entity.rotation
	_current_target = _get_random_target()
		
	if _nav_agent:
		_nav_agent.target_position = _current_target
		
	_velocity = Vector2.ZERO
	_target_reached = false

## Update movement execution
func _update_execution(delta: float) -> void:
	if not _nav_agent:
		return
		
	var current_pos = entity.global_position
	
	# Check if we need a new target
	var target_reached = _current_target and _nav_agent.is_target_reached()
	
	if target_reached or not _current_target:
		logger.debug("Getting new random target")
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
	entity.velocity = _velocity
	if face_direction:
		entity.global_rotation = _velocity.angle()
	entity.move_and_slide()

func _complete_execution() -> void:
	_target_reached = true
	_velocity = Vector2.ZERO
	entity.velocity = Vector2.ZERO
	super._complete_execution()
