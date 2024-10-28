class_name Task
extends RefCounted

## Signals for task state changes
signal started
signal completed
signal interrupted
signal state_changed(new_state: State)

## Task states
enum State {
	INACTIVE,    ## Task is not running
	ACTIVE,      ## Task is currently running
	COMPLETED,   ## Task has completed successfully
	INTERRUPTED  ## Task was interrupted before completion
}

## Task priority levels
enum Priority {
	LOWEST = 0,
	LOW = 25,
	MEDIUM = 50,
	HIGH = 75,
	HIGHEST = 100
}

## Current state of the task
var state: State = State.INACTIVE:
	set(value):
		if state != value:
			state = value
			state_changed.emit(state)

## Name of the task for debugging
var name: String = ""

## Priority level of this task
var priority: int = Priority.MEDIUM

## Reference to the ant performing the task
var ant: Ant

## Array of behaviors available to this task
var behaviors: Array[Behavior] = []

## Array of condition configurations for this task
var conditions: Array[Dictionary] = []

## Currently active behavior
var active_behavior: Behavior

## Cache for condition evaluation results
var _condition_cache: Dictionary = {}

## Initialize the task with a priority
func _init(_priority: int = Priority.MEDIUM) -> void:
	priority = _priority

## Add a behavior to this task
func add_behavior(behavior: Behavior) -> void:
	behaviors.append(behavior)
	behavior.name = behavior.name if behavior.name else "Behavior" + str(behaviors.size())

## Add a condition configuration to this task
func add_condition(config: Dictionary) -> void:
	conditions.append(config)

## Start the task
func start(_ant: Ant) -> void:
	if state == State.ACTIVE:
		return
		
	ant = _ant
	state = State.ACTIVE
	started.emit()

## Update the task and its behaviors
func update(delta: float, context: Dictionary) -> void:
	if state != State.ACTIVE:
		return
	
	# Check task conditions
	if not _check_conditions(context):
		interrupt()
		return
	
	# Find highest priority valid behavior
	var highest_priority_behavior: Behavior = null
	var highest_priority: int = -1
	
	for behavior in behaviors:
		if behavior.should_activate(context) and behavior.priority > highest_priority:
			highest_priority_behavior = behavior
			highest_priority = behavior.priority
	
	# Switch behaviors if needed
	if highest_priority_behavior != active_behavior:
		if active_behavior:
			active_behavior.interrupt()
		active_behavior = highest_priority_behavior
		if active_behavior:
			active_behavior.start(ant)
	
	# Update active behavior
	if active_behavior:
		active_behavior.update(delta, context)
		
		# Check if behavior completed
		if active_behavior.state == Behavior.State.COMPLETED:
			active_behavior = null
			# Task might complete here depending on your requirements
			# For now, we'll keep looking for new behaviors to run
	elif behaviors.is_empty():
		# No behaviors left to run
		state = State.COMPLETED
		completed.emit()

## Interrupt the task
func interrupt() -> void:
	if state == State.ACTIVE:
		state = State.INTERRUPTED
		if active_behavior:
			active_behavior.interrupt()
			active_behavior = null
		interrupted.emit()

## Reset the task to its initial state
func reset() -> void:
	state = State.INACTIVE
	if active_behavior:
		active_behavior.interrupt()
	active_behavior = null
	clear_condition_cache()
	
	# Reset all behaviors
	for behavior in behaviors:
		behavior.reset()

## Clear the condition evaluation cache
func clear_condition_cache() -> void:
	_condition_cache.clear()

## Check if all conditions are met
func _check_conditions(context: Dictionary) -> bool:
	if conditions.is_empty():
		return true
	
	for condition in conditions:
		if not ConditionEvaluator.evaluate(condition, context):
			return false
	return true

## Get the current active behavior
func get_active_behavior() -> Behavior:
	return active_behavior

## Get debug information about the task
func get_debug_info() -> Dictionary:
	return {
		"name": name,
		"state": State.keys()[state],
		"priority": priority,
		"behavior_count": behaviors.size(),
		"active_behavior": active_behavior.name if active_behavior else "None",
		"condition_count": conditions.size()
	}

## Print debug hierarchy
func print_hierarchy(indent: int = 0) -> void:
	var indent_str = "  ".repeat(indent)
	print("%s- Task: %s (Priority: %d, State: %s)" % [
		indent_str,
		name,
		priority,
		State.keys()[state]
	])
	
	if not conditions.is_empty():
		print("%s  Conditions:" % indent_str)
		for condition in conditions:
			print("%s    - %s" % [indent_str, condition.get("type", "Unknown")])
	
	if not behaviors.is_empty():
		print("%s  Behaviors:" % indent_str)
		for behavior in behaviors:
			print("%s    - %s (Priority: %d)" % [
				indent_str,
				behavior.name,
				behavior.priority
			])

func get_conditions() -> Array[Dictionary]:
	return conditions
