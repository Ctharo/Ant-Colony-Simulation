class_name RestAction
extends AntAction

## Rate at which health is restored per second
@export var health_rate: float = 20.0
## Rate at which energy is restored per second
@export var energy_rate: float = 20.0
## Whether to rest until fully restored
@export var rest_until_full: bool = true
## Maximum rest time (if not resting until full)
@export var max_rest_time: float = 5.0
## Whether to only rest at colony
@export var only_at_colony: bool = true

## Override for internal can start
func _can_start_internal() -> bool:
	if not is_instance_valid(ant):
		return false
		
	# Check if we need to rest
	if not ant.should_rest():
		return false
		
	# Check if we need to be at colony
	if only_at_colony and not ant.is_colony_in_range():
		return false
		
	return true

## Start resting
func _start_internal() -> bool:
	if not is_instance_valid(ant):
		return false
		
	if rest_until_full:
		# Set large duration for rest until full
		duration = 999999.0
	else:
		duration = max_rest_time
		
	logger.debug("Starting to rest" + (" until full" if rest_until_full else " for " + str(max_rest_time) + " seconds"))
	return true

## Update resting
func _update_internal(delta: float) -> void:
	if not is_instance_valid(ant):
		fail("Invalid ant reference")
		return
		
	# Apply healing rates
	ant.health_level += health_rate * delta
	ant.energy_level += energy_rate * delta
	
	# If resting until full, check if we're full
	if rest_until_full and ant.is_fully_rested():
		complete()
		return
		
	# If at colony, make sure we're still there
	if only_at_colony and not ant.is_colony_in_range():
		interrupt()
		return
		
	# Otherwise, progress is handled by the base class timer
	pass

## Clean up on completion
func _complete_internal() -> void:
	if is_instance_valid(ant):
		logger.debug("Rest completed: Health=" + str(ant.health_level) + ", Energy=" + str(ant.energy_level))

## Clean up on failure
func _fail_internal() -> void:
	# Nothing specific to clean up
	pass

## Clean up on interruption
func _interrupt_internal() -> void:
	# Nothing specific to clean up
	pass
