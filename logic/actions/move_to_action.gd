class_name MoveToAction
extends AntAction

## Target position to move to
@export var target_position: Vector2
## Distance considered "reached" for the target
@export var arrival_distance: float = 10.0
## Whether to use the shortest path or just move directly
@export var use_navigation: bool = true
## Whether this is a continuous action (no completion on arrival)
@export var is_continuous: bool = false
## Maximum attempts to find a path
@export var max_path_attempts: int = 3

# Internal tracking
var _path_attempts: int = 0
var _last_position: Vector2
var _stuck_time: float = 0.0

## Override for internal can start
func _can_start_internal() -> bool:
	# Can't start if we don't have a target
	if target_position == Vector2.ZERO:
		return false

	# Can't start if we're already at the target
	if is_instance_valid(ant) and ant.global_position.distance_to(target_position) <= arrival_distance:
		return false

	return true

## Start moving
func _start_internal() -> bool:
	if not is_instance_valid(ant):
		return false

	_path_attempts = 0
	_last_position = ant.global_position
	_stuck_time = 0.0

	if use_navigation:
		return ant.move_to(target_position)
	else:
		# Simple direct movement without navigation
		ant.target_position = target_position
		return true

## Update movement progress
func _update_internal(delta: float) -> void:
	if not is_instance_valid(ant):
		fail("Invalid ant reference")
		return

	# Check if we've reached the destination
	if ant.is_navigation_finished() or ant.global_position.distance_to(target_position) <= arrival_distance:
		if is_continuous:
			# Just keep going if we're continuous
			pass
		else:
			# Complete the action
			complete()
			return

	# Check for stuck condition
	var current_pos = ant.global_position
	var moved_distance = current_pos.distance_to(_last_position)

	if moved_distance < 1.0:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
		_last_position = current_pos

	# If stuck for too long, try to fix or fail
	if _stuck_time > 1.0:
		_handle_stuck_condition()

## Handle when ant appears to be stuck
func _handle_stuck_condition() -> void:
	_stuck_time = 0.0
	_path_attempts += 1

	if _path_attempts < max_path_attempts:
		logger.debug("Ant appears stuck, recalculating path (attempt " + str(_path_attempts) + ")")

		# Try to recalculate path with slight offset
		var random_offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		ant.move_to(target_position + random_offset)
	else:
		# Too many attempts, fail the action
		fail("Ant is stuck after " + str(_path_attempts) + " path attempts")

## Clean up on completion
func _complete_internal() -> void:
	if is_instance_valid(ant):
		# Stop movement when done
		ant.stop_movement()

## Clean up on failure
func _fail_internal() -> void:
	if is_instance_valid(ant):
		# Stop movement on failure
		ant.stop_movement()

## Clean up on interruption
func _interrupt_internal() -> void:
	if is_instance_valid(ant):
		# Stop movement on interrupt
		ant.stop_movement()
