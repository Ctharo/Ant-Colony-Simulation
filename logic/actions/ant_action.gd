class_name AntAction
extends Resource

## Signal emitted when action starts
signal action_started(ant: Ant)
## Signal emitted when action completes successfully
signal action_completed(ant: Ant)
## Signal emitted when action fails
signal action_failed(ant: Ant, reason: String)
## Signal emitted when action is interrupted
signal action_interrupted(ant: Ant)

enum ActionStatus {
	INACTIVE,  # Action hasn't started
	RUNNING,   # Action is in progress
	COMPLETED, # Action finished successfully
	FAILED     # Action encountered a problem
}

## Unique identifier for this action
@export var name: String:
	set(value):
		name = value
		id = name.to_snake_case()
var id: String

## Short description of what the action does
@export var description: String = ""

## Condition that must be true for action to start
@export var start_condition: Logic

## Condition that if true during execution, will interrupt the action
@export var interrupt_condition: Logic

## How long this action takes to complete (in seconds)
@export var duration: float = 1.0

## Time between ending this action and being able to start it again
@export var cooldown: float = 0.0

## Whether this action can be interrupted
@export var is_interruptable: bool = true

## Priority of this action (higher values take precedence)
@export var priority: int = 0

## Cost of this action in terms of energy
@export var energy_cost: float = 0.0

## The current status of this action
var status: ActionStatus = ActionStatus.INACTIVE

## The ant currently performing this action
var ant: Ant

## Time tracking for duration and cooldown
var elapsed_time: float = 0.0
var cooldown_time: float = 0.0

## Logger for debugging
var logger: Logger

#region Movement Integration
## Movement profile to use while this action is running
@export var movement_profile: InfluenceProfile

## Whether to restore the previous profile when this action completes/fails
@export var restore_previous_profile: bool = true

## Temporarily stores the previous profile to restore later
var _previous_profile: InfluenceProfile

## Set up the movement profile for this action
func _setup_movement_profile() -> void:
	if not is_instance_valid(ant) or not is_instance_valid(movement_profile):
		return
		
	if is_instance_valid(ant.influence_manager):
		# Store current profile for later restoration
		_previous_profile = ant.influence_manager.active_profile
		
		# Set our action's movement profile
		ant.influence_manager.active_profile = movement_profile
		
		logger.debug("Set movement profile to %s for action %s" % [
			movement_profile.name, 
			name
		])

## Restore the previous movement profile
func _restore_movement_profile() -> void:
	if not is_instance_valid(ant) or not is_instance_valid(ant.influence_manager):
		return
		
	if restore_previous_profile and is_instance_valid(_previous_profile):
		ant.influence_manager.active_profile = _previous_profile
		
		logger.debug("Restored movement profile to %s after action %s" % [
			_previous_profile.name,
			name
		])
#endregion

## Initialize the action with an ant
func initialize(p_ant: Ant) -> void:
	ant = p_ant
	status = ActionStatus.INACTIVE
	elapsed_time = 0.0
	cooldown_time = 0.0
	logger = Logger.new("ant_action", DebugLogger.Category.ENTITY)

## Check if action can start
func can_start() -> bool:
	if not is_instance_valid(ant):
		return false

	if cooldown_time > 0.0:
		return false

	if status == ActionStatus.RUNNING:
		return false

	if start_condition and not start_condition.get_value(ant):
		return false

	return _can_start_internal()

## Internal method for specific action start conditions
func _can_start_internal() -> bool:
	return true

## Start the action
func start() -> bool:
	if not can_start():
		return false

	status = ActionStatus.RUNNING
	elapsed_time = 0.0

	# Apply energy cost when starting
	if energy_cost > 0 and is_instance_valid(ant):
		ant.energy_level -= energy_cost

	# Set up movement profile before starting internal implementation
	_setup_movement_profile()
	
	var result = _start_internal()
	if not result:
		status = ActionStatus.FAILED
		_restore_movement_profile()
		
	action_started.emit(ant)
	return result

## Internal method for specific action start implementation
func _start_internal() -> bool:
	return true

## Update the action (called every physics frame while active)
func update(delta: float) -> void:
	if status != ActionStatus.RUNNING:
		return

	# Check for interruption
	if is_interruptable and interrupt_condition and interrupt_condition.get_value(ant):
		interrupt()
		return

	# Update elapsed time
	elapsed_time += delta

	# Check for duration completion
	if duration > 0.0 and elapsed_time >= duration:
		complete()
		return

	# Update the internal action state
	_update_internal(delta)

## Internal method for specific action update implementation
func _update_internal(_delta: float) -> void:
	pass

## Complete the action successfully
func complete() -> void:
	if status != ActionStatus.RUNNING:
		return

	status = ActionStatus.COMPLETED
	cooldown_time = cooldown
	_complete_internal()
	
	# Restore movement profile after completing
	_restore_movement_profile()
	
	action_completed.emit(ant)

## Internal method for specific action completion implementation
func _complete_internal() -> void:
	pass

## Fail the action
func fail(reason: String = "") -> void:
	if status != ActionStatus.RUNNING:
		return

	status = ActionStatus.FAILED
	cooldown_time = cooldown
	_fail_internal()
	
	# Restore movement profile after failing
	_restore_movement_profile()
	
	action_failed.emit(ant, reason)

## Internal method for specific action failure implementation
func _fail_internal() -> void:
	pass

## Interrupt the action
func interrupt() -> void:
	if status != ActionStatus.RUNNING or not is_interruptable:
		return

	status = ActionStatus.INACTIVE
	_interrupt_internal()
	
	# Restore movement profile after interruption
	_restore_movement_profile()
	
	action_interrupted.emit(ant)

## Internal method for specific action interruption implementation
func _interrupt_internal() -> void:
	pass

## Update cooldown (called every physics frame regardless of status)
func update_cooldown(delta: float) -> void:
	if cooldown_time > 0.0:
		cooldown_time = max(0.0, cooldown_time - delta)

## Get the action's current progress (0.0 to 1.0)
func get_progress() -> float:
	if duration <= 0.0 or status != ActionStatus.RUNNING:
		return 0.0
	return min(elapsed_time / duration, 1.0)

## Get a string representation of the action for debugging
func get_debug_string() -> String:
	var status_str = ["INACTIVE", "RUNNING", "COMPLETED", "FAILED"][status]
	return "%s (%s, Priority: %d, Progress: %.1f%%)" % [
		name,
		status_str,
		priority,
		get_progress() * 100.0
	]
