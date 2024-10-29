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
var name: String = "":
	set(value):
		name = value

## Priority level of this behavior
var priority: int = Priority.MEDIUM:
	set(value):
		priority = value

## Reference to the ant performing the behavior
var ant: Ant:
	set(value):
		ant = value
		_update_action_references()

## Array of conditions for this behavior
var conditions: Array[Condition] = []:
	set(value):
		conditions = value

## Array of actions to perform
var actions: Array[Action] = []:
	set(value):
		actions = value
		if is_instance_valid(ant):
			_update_action_references()

## Cache for condition evaluation results
var _condition_cache: Dictionary = {}

## Initialize the behavior with a priority
func _init(p_priority: int = Priority.MEDIUM) -> void:
	priority = p_priority

## Add a condition to this behavior
func add_condition(condition: Condition) -> void:
	conditions.append(condition)

## Add an action to this behavior
func add_action(action: Action) -> void:
	actions.append(action)
	if is_instance_valid(ant):
		action.ant = ant

## Get all conditions for this behavior
func get_conditions() -> Array[Condition]:
	return conditions

## Start the behavior
func start(p_ant: Ant) -> void:
	if not is_instance_valid(p_ant):
		push_error("Cannot start behavior with invalid ant reference")
		return
		
	ant = p_ant
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
	if conditions.is_empty():
		return true
	
	for condition in conditions:
		if not condition.is_met(ant, _condition_cache, context):
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

## Update ant references in actions when ant changes
func _update_action_references() -> void:
	if not is_instance_valid(ant):
		return
		
	for action in actions:
		action.ant = ant

## Get debug information about the behavior
func get_debug_info() -> Dictionary:
	return {
		"name": name,
		"priority": priority,
		"state": State.keys()[state],
		"conditions": conditions.size(),
		"actions": actions.size()
	}
