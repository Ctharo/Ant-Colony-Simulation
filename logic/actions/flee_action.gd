class_name FleeAction
extends AntAction

## Entity to flee from
var flee_from: Node2D
## Whether to automatically find the nearest threat
@export var auto_find_nearest: bool = true
## Minimum safe distance to maintain
@export var safe_distance: float = 150.0
## Maximum flee time (to avoid running too far)
@export var max_flee_time: float = 3.0
## Whether to use navigation
@export var use_navigation: bool = true
## Flee speed multiplier (relative to normal movement rate)
@export var speed_multiplier: float = 1.5

# Internal tracking
var _original_movement_rate: float
var _flee_direction: Vector2
var _last_update_time: float = 0.0
var _update_interval: float = 0.5

## Internal method to find the nearest threat
func _find_nearest_threat() -> Node2D:
	if not is_instance_valid(ant):
		return null

	# Find unfriendly ants in view
	var unfriendly = ant.get_ants_in_view().filter(func(other_ant):
		return other_ant.colony != ant.colony
	)

	if unfriendly.is_empty():
		return null

	# Sort by distance
	unfriendly.sort_custom(func(a, b):
		var dist_a = ant.global_position.distance_squared_to(a.global_position)
		var dist_b = ant.global_position.distance_squared_to(b.global_position)
		return dist_a < dist_b
	)

	return unfriendly[0]

## Check if we can start fleeing
func _can_start_internal() -> bool:
	if not is_instance_valid(ant):
		return false

	# Find threat if needed
	if auto_find_nearest and not is_instance_valid(flee_from):
		flee_from = _find_nearest_threat()

	# Can't flee if no threat
	if not is_instance_valid(flee_from):
		return false

	# Check if threat is close enough to flee
	var distance = ant.global_position.distance_to(flee_from.global_position)
	return distance < safe_distance

## Start fleeing
func _start_internal() -> bool:
	if not is_instance_valid(ant) or not is_instance_valid(flee_from):
		return false

	# Store original movement rate
	_original_movement_rate = ant.movement_rate

	# Apply speed boost
	ant.movement_rate = _original_movement_rate * speed_multiplier

	# Set duration
	duration = max_flee_time

	# Calculate initial flee direction
	_update_flee_direction()

	# Set target position in the flee direction
	var target = ant.global_position + _flee_direction * safe_distance * 1.5

	# Use navigation or direct movement
	if use_navigation:
		return ant.move_to(target)
	else:
		ant.target_position = target
		return true

## Update fleeing behavior
func _update_internal(delta: float) -> void:
	if not is_instance_valid(ant) or not is_instance_valid(flee_from):
		complete() # End fleeing if ant or threat no longer valid
		return

	# Check if we've reached safe distance
	var current_distance = ant.global_position.distance_to(flee_from.global_position)
	if current_distance >= safe_distance:
		complete()
		return

	# Periodically update direction
	_last_update_time += delta
	if _last_update_time >= _update_interval:
		_update_flee_direction()
		_last_update_time = 0.0

		# Set new target position
		var target = ant.global_position + _flee_direction * safe_distance

		if use_navigation:
			ant.move_to(target)
		else:
			ant.target_position = target

## Update the direction to flee
func _update_flee_direction() -> void:
	if not is_instance_valid(ant) or not is_instance_valid(flee_from):
		return

	# Direction away from threat
	_flee_direction = (ant.global_position - flee_from.global_position).normalized()

	# Add slight randomization to avoid straight lines
	var random_angle = randf_range(-PI/4, PI/4)
	_flee_direction = _flee_direction.rotated(random_angle)

## Clean up when complete
func _complete_internal() -> void:
	if is_instance_valid(ant):
		# Restore original movement speed
		ant.movement_rate = _original_movement_rate

		# Stop movement
		ant.stop_movement()

## Clean up on failure
func _fail_internal() -> void:
	if is_instance_valid(ant):
		# Restore original movement speed
		ant.movement_rate = _original_movement_rate

## Clean up on interruption
func _interrupt_internal() -> void:
	if is_instance_valid(ant):
		# Restore original movement speed
		ant.movement_rate = _original_movement_rate
