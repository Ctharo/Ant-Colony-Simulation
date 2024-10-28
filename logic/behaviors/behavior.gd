class_name Behavior
extends RefCounted
## Interface between the [class Task] and the [class Action], passing parameters 

## Signals for behavior state changes
signal started
signal completed
signal interrupted
signal state_changed(new_state: State)

## Behavior states
enum State {
	INACTIVE,    ## Behavior is not running
	ACTIVE,      ## Behavior is currently running
	COMPLETED,   ## Behavior has completed its task
	INTERRUPTED  ## Behavior was interrupted
}

## Behavior priority levels
enum Priority {
	LOWEST = 0,
	LOW = 25,
	MEDIUM = 50,
	HIGH = 75,
	HIGHEST = 100
}

## Current state of the behavior
var state: State = State.INACTIVE:
	set(value):
		if state != value:
			state = value
			state_changed.emit(state)

## Name of the behavior for debugging
var name: String = ""

## Priority level of this behavior
var priority: int = Priority.MEDIUM

## Reference to the ant performing the behavior
var ant: Ant

## Array of condition configurations for this behavior
var condition_configs: Array[Dictionary] = []

## Array of actions to perform
var actions: Array[Action] = []

## Cache for condition evaluation results
var _condition_cache: Dictionary = {}

## Initialize the behavior with a priority
func _init(_priority: int = Priority.MEDIUM):
	priority = _priority

## Add a condition configuration to this behavior
func add_condition_config(config: Dictionary) -> void:
	condition_configs.append(config)

## Get all conditions for this behavior
func get_conditions() -> Array[Dictionary]:
	return condition_configs

## Start the behavior
func start(_ant: Ant) -> void:
	ant = _ant
	state = State.ACTIVE
	started.emit()
	
	# Start all actions
	for action in actions:
		action.start(ant)

## Update the behavior
func update(delta: float, context: Dictionary) -> void:
	if state != State.ACTIVE:
		return
	
	# Check conditions
	if not _check_conditions(context):
		interrupt()
		return
	
	# Update actions
	_update_actions(delta)

## Check if the behavior should activate
func should_activate(context: Dictionary) -> bool:
	return _check_conditions(context)

## Interrupt the behavior
func interrupt() -> void:
	if state == State.ACTIVE:
		state = State.INTERRUPTED
		
		# Cancel all actions
		for action in actions:
			action.interrupt()
		
		interrupted.emit()

## Reset the behavior to its initial state
func reset() -> void:
	state = State.INACTIVE
	clear_condition_cache()
	
	# Reset all actions
	for action in actions:
		action.reset()

## Clear the condition evaluation cache
func clear_condition_cache() -> void:
	_condition_cache.clear()

## Check if all conditions are met using the context
func _check_conditions(context: Dictionary) -> bool:
	if condition_configs.is_empty():
		return true
	
	for config in condition_configs:
		if not ConditionEvaluator.evaluate(config, context):
			return false
	return true

## Update all actions
func _update_actions(delta: float) -> void:
	var all_completed := true
	
	for action in actions:
		if not action.is_completed():
			action.update(delta)
			all_completed = false
	
	if all_completed and not actions.is_empty():
		state = State.COMPLETED
		completed.emit()

## Get debug information about the behavior
func get_debug_info() -> Dictionary:
	return {
		"name": name,
		"priority": priority,
		"state": State.keys()[state],
		"conditions": condition_configs.size(),
		"actions": actions.size()
	}
