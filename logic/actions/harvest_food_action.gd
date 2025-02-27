class_name HarvestFoodAction
extends AntAction

## Food to harvest (if specified)
var target_food: Food
## Whether to automatically find nearest food when starting
@export var auto_find_nearest: bool = true
## Distance considered "in reach" for food
@export var reach_distance: float = 20.0
## Time it takes to pick up food
@export var harvest_time: float = 1.0

## Temporary variable to hold food being targeted
var _current_target: Food

## Find the nearest food in reach
func find_nearest_food() -> Food:
	if not is_instance_valid(ant):
		return null

	var foods_in_reach = ant.get_foods_in_reach()
	if foods_in_reach.is_empty():
		return null

	# Sort by distance
	foods_in_reach.sort_custom(func(a: Food, b: Food) -> bool:
		var dist_a = ant.global_position.distance_squared_to(a.global_position)
		var dist_b = ant.global_position.distance_squared_to(b.global_position)
		return dist_a < dist_b
	)

	# Return closest available food
	for food in foods_in_reach:
		if is_instance_valid(food) and food.is_available:
			return food

	return null

## Override for internal can start
func _can_start_internal() -> bool:
	if not is_instance_valid(ant):
		return false

	# Check if we're already carrying food
	if ant.is_carrying_food:
		return false

	# If we have a target, check if it's valid
	if target_food and (not is_instance_valid(target_food) or not target_food.is_available):
		target_food = null

	# Find nearest food if needed
	if auto_find_nearest and not target_food:
		target_food = find_nearest_food()

	# Can't start if no food to harvest
	if not target_food:
		return false

	return true

## Start harvesting
func _start_internal() -> bool:
	if not is_instance_valid(ant) or not is_instance_valid(target_food):
		return false

	_current_target = target_food

	# Set duration based on harvest time
	duration = harvest_time

	logger.debug("Starting to harvest food: " + str(_current_target))
	return true

## Update harvesting
func _update_internal(_delta: float) -> void:
	if not is_instance_valid(ant):
		fail("Invalid ant reference")
		return

	# Check if food is still valid
	if not is_instance_valid(_current_target) or not _current_target.is_available:
		fail("Food no longer available")
		return

	# Check if food is still in reach
	if ant.global_position.distance_to(_current_target.global_position) > reach_distance:
		fail("Food out of reach")
		return

	# Progress is handled automatically by the base class timer
	pass

## Complete harvesting
func _complete_internal() -> void:
	if not is_instance_valid(ant):
		return

	if is_instance_valid(_current_target) and _current_target.is_available:
		_current_target.set_state(Food.State.CARRIED)
		_current_target.global_position = ant.mouth_marker.global_position
		ant._carried_food = _current_target

		logger.debug("Harvested food successfully")
	else:
		logger.warning("Food no longer valid when completing harvest")
		fail("Food unavailable at completion")

## Clean up on failure
func _fail_internal() -> void:
	_current_target = null

## Clean up on interruption
func _interrupt_internal() -> void:
	_current_target = null
