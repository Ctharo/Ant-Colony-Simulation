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

## Array of sub-behaviors
var sub_behaviors: Array[Behavior] = []

## Currently active sub-behavior
var current_sub_behavior: Behavior

## Cache for condition evaluation results
var _condition_cache: Dictionary = {}

## Initialize the behavior with a priority
func _init(_priority: int = Priority.MEDIUM):
	priority = _priority

## Add a condition configuration to this behavior
func add_condition_config(config: Dictionary) -> void:
	condition_configs.append(config)

## Add a sub-behavior
func add_sub_behavior(behavior: Behavior) -> void:
	sub_behaviors.append(behavior)

## Start the behavior
func start(_ant: Ant) -> void:
	ant = _ant
	state = State.ACTIVE
	started.emit()
	
	# Start all actions
	for action in actions:
		action.start(ant)

## Update the behavior and its sub-behaviors
func update(delta: float, context: Dictionary) -> void:
	if state != State.ACTIVE:
		return
	
	# Check conditions
	if not _check_conditions(context):
		interrupt()
		return
	
	# Update actions if no sub-behaviors are active
	if sub_behaviors.is_empty():
		_update_actions(delta)
		return
	
	# Try to activate a sub-behavior
	var activated_sub = false
	for sub_behavior in sub_behaviors:
		if sub_behavior.should_activate(context):
			if current_sub_behavior != sub_behavior:
				if current_sub_behavior:
					current_sub_behavior.interrupt()
				current_sub_behavior = sub_behavior
				sub_behavior.start(ant)
			activated_sub = true
			break
	
	# Update current sub-behavior if one is active
	if current_sub_behavior and current_sub_behavior.state == State.ACTIVE:
		current_sub_behavior.update(delta, context)
	# Otherwise update actions
	elif not activated_sub:
		_update_actions(delta)

## Check if the behavior should activate
func should_activate(context: Dictionary) -> bool:
	return _check_conditions(context)

## Interrupt the behavior
func interrupt() -> void:
	if state == State.ACTIVE:
		state = State.INTERRUPTED
		
		# Interrupt current sub-behavior if any
		if current_sub_behavior:
			current_sub_behavior.interrupt()
			current_sub_behavior = null
		
		# Cancel all actions
		for action in actions:
			action.interrupt()
		
		interrupted.emit()

## Reset the behavior to its initial state
func reset() -> void:
	state = State.INACTIVE
	current_sub_behavior = null
	clear_condition_cache()
	
	# Reset all actions
	for action in actions:
		action.reset()
	
	# Reset all sub-behaviors
	for sub_behavior in sub_behaviors:
		sub_behavior.reset()

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

## Check if any sub-behaviors are active
func has_active_sub_behaviors() -> bool:
	if current_sub_behavior and current_sub_behavior.state == State.ACTIVE:
		return true
	return false

## Get the current active sub-behavior (if any)
func get_active_sub_behavior() -> Behavior:
	if current_sub_behavior and current_sub_behavior.state == State.ACTIVE:
		return current_sub_behavior
	return null

## Get debug information about the behavior
func get_debug_info() -> Dictionary:
	return {
		"name": name,
		"priority": priority,
		"state": State.keys()[state],
		"conditions": condition_configs.size(),
		"actions": actions.size(),
		"sub_behaviors": sub_behaviors.size(),
		"current_sub": current_sub_behavior.name if current_sub_behavior else "None"
	}
