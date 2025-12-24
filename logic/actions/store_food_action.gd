class_name StoreFoodAction
extends AntAction

## Time it takes to store food
@export var store_time: float = 1.0

## Override for internal can start
func _can_start_internal() -> bool:
	if not is_instance_valid(ant):
		return false

	# Must be carrying food to store it
	if not ant.is_carrying_food:
		return false

	# Must be at the colony to store food
	if not ant.is_colony_in_range():
		return false

	return true

## Start storing
func _start_internal() -> bool:
	if not is_instance_valid(ant):
		return false

	# Set duration based on store time
	duration = store_time
	logger.debug("Starting to store food at colony")
	return true

## Update storing
func _update_internal(_delta: float) -> void:
	if not is_instance_valid(ant):
		fail("Invalid ant reference")
		return

	# Check if we're still carrying food
	if not ant.is_carrying_food:
		fail("No longer carrying food")
		return

	# Check if we're still at the colony
	if not ant.is_colony_in_range():
		fail("No longer at colony")
		return

	# Progress is handled automatically by the base class timer
	pass

## Complete storing
func _complete_internal() -> void:
	if not is_instance_valid(ant):
		return

	if not is_instance_valid(ant.colony):
		fail("Colony reference invalid")
		return

	if ant.is_carrying_food and is_instance_valid(ant._carried_food):
		ant.colony.store_food(ant._carried_food)
		ant._carried_food = null

		logger.debug("Stored food at colony successfully")
	else:
		logger.warning("Food no longer valid when completing store")
		fail("Food no longer valid")

## Clean up on failure
func _fail_internal() -> void:
	# Nothing specific to clean up
	pass

## Clean up on interruption
func _interrupt_internal() -> void:
	# Nothing specific to clean up
	pass
