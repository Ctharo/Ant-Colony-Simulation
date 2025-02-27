class_name PatrolAction
extends AntAction

## Waypoints to patrol between
@export var waypoints: Array[Vector2] = []
## Whether to loop back to the first waypoint
@export var loop_patrol: bool = true
## Whether to patrol relative to colony position
@export var relative_to_colony: bool = false
## Distance required to consider a waypoint reached
@export var waypoint_arrival_distance: float = 10.0
## Whether to use random waypoints
@export var use_random_waypoints: bool = false
## Radius around colony for random waypoints
@export var random_waypoint_radius: float = 200.0
## Number of random waypoints to generate
@export var random_waypoint_count: int = 5

# Internal state
var _current_waypoint_index: int = 0
var _absolute_waypoints: Array[Vector2] = []
var _moving_to_waypoint: bool = false

## Can we start patrolling?
func _can_start_internal() -> bool:
	if not is_instance_valid(ant):
		return false
		
	# Handle random waypoint generation
	if use_random_waypoints and waypoints.is_empty():
		_generate_random_waypoints()
		
	# Can't patrol with no waypoints
	return not waypoints.is_empty()

## Generate random waypoints
func _generate_random_waypoints() -> void:
	waypoints.clear()
	
	var center = Vector2.ZERO
	if is_instance_valid(ant) and is_instance_valid(ant.colony):
		center = ant.colony.global_position
	
	for i in range(random_waypoint_count):
		var angle = randf() * TAU
		var distance = randf_range(ant.colony.radius, random_waypoint_radius)
		var waypoint = center + Vector2(cos(angle), sin(angle)) * distance
		waypoints.append(waypoint)

## Start patrolling
func _start_internal() -> bool:
	if not is_instance_valid(ant) or waypoints.is_empty():
		return false
	
	# Calculate absolute waypoint positions if needed
	_absolute_waypoints.clear()
	
	if relative_to_colony and is_instance_valid(ant.colony):
		var colony_pos = ant.colony.global_position
		for waypoint in waypoints:
			_absolute_waypoints.append(colony_pos + waypoint)
	else:
		_absolute_waypoints = waypoints.duplicate()
	
	# Set current waypoint index based on closest waypoint
	_current_waypoint_index = _find_closest_waypoint_index()
	
	# Move to first waypoint
	return _move_to_current_waypoint()

## Find the index of the closest waypoint
func _find_closest_waypoint_index() -> int:
	if not is_instance_valid(ant) or _absolute_waypoints.is_empty():
		return 0
		
	var closest_index = 0
	var closest_distance = INF
	
	for i in range(_absolute_waypoints.size()):
		var dist = ant.global_position.distance_to(_absolute_waypoints[i])
		if dist < closest_distance:
			closest_distance = dist
			closest_index = i
			
	return closest_index

## Move to the current waypoint
func _move_to_current_waypoint() -> bool:
	if not is_instance_valid(ant) or _current_waypoint_index >= _absolute_waypoints.size():
		return false
		
	var target = _absolute_waypoints[_current_waypoint_index]
	_moving_to_waypoint = ant.move_to(target)
	
	logger.debug("Moving to waypoint %d: %s" % [_current_waypoint_index, target])
	return _moving_to_waypoint

## Update patrol
func _update_internal(delta: float) -> void:
	if not is_instance_valid(ant) or _absolute_waypoints.is_empty():
		fail("Invalid ant or waypoints")
		return
		
	# Check if we've reached the current waypoint
	var current_waypoint = _absolute_waypoints[_current_waypoint_index]
	var distance = ant.global_position.distance_to(current_waypoint)
	
	if distance <= waypoint_arrival_distance or ant.is_navigation_finished():
		# Advance to next waypoint
		_current_waypoint_index = (_current_waypoint_index + 1) % _absolute_waypoints.size()
		
		# If we've completed a full loop and not set to loop
		if _current_waypoint_index == 0 and not loop_patrol:
			complete()
			return
			
		# Move to next waypoint
		if not _move_to_current_waypoint():
			fail("Failed to move to next waypoint")
			return
	
	# If we're not moving, try to restart
	if not _moving_to_waypoint:
		if not _move_to_current_waypoint():
			fail("Failed to move to waypoint after stopping")
			return

## Clean up on completion
func _complete_internal() -> void:
	if is_instance_valid(ant):
		ant.stop_movement()

## Clean up on failure
func _fail_internal() -> void:
	if is_instance_valid(ant):
		ant.stop_movement()

## Clean up on interruption
func _interrupt_internal() -> void:
	if is_instance_valid(ant):
		ant.stop_movement()
