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
var name: String = "":
	set(value):
		name = value

## Priority level of this task
var priority: int = Priority.MEDIUM:
	set(value):
		priority = value

## Reference to the ant performing the task
var ant: Ant:
	set(value):
		ant = value
		_update_behavior_references()

## Array of behaviors available to this task
var behaviors: Array[Behavior] = []:
	set(value):
		behaviors = value
		if is_instance_valid(ant):
			_update_behavior_references()

## Array of conditions for this task
var conditions: Array[Condition] = []:
	set(value):
		conditions = value

## Currently active behavior
var active_behavior: Behavior:
	set(value):
		var old_behavior = active_behavior
		active_behavior = value
		if old_behavior != value:
			if old_behavior:
				old_behavior.interrupt()
			if value and is_instance_valid(ant):
				value.start(ant)

## Cache for condition evaluation results
var _condition_cache: Dictionary = {}

## Initialize the task with a priority
func _init(p_priority: int = Priority.MEDIUM) -> void:
	priority = p_priority

## Add a behavior to this task
func add_behavior(behavior: Behavior) -> void:
	if not is_instance_valid(behavior):
		push_error("Cannot add invalid behavior to task")
		return
		
	behaviors.append(behavior)
	behavior.name = behavior.name if not behavior.name.is_empty() else "Behavior" + str(behaviors.size())
	
	if is_instance_valid(ant):
		behavior.ant = ant

## Add a condition to this task
func add_condition(condition: Condition) -> void:
	if not is_instance_valid(condition):
		push_error("Cannot add invalid condition to task")
		return
		
	conditions.append(condition)

## Start the task
func start(p_ant: Ant) -> void:
	if state == State.ACTIVE:
		return
		
	if not is_instance_valid(p_ant):
		push_error("Cannot start task with invalid ant reference")
		return
		
	ant = p_ant
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
		if not is_instance_valid(behavior):
			continue
			
		if behavior.should_activate(context) and behavior.priority > highest_priority:
			highest_priority_behavior = behavior
			highest_priority = behavior.priority
	
	# Switch behaviors if needed
	if highest_priority_behavior != active_behavior:
		active_behavior = highest_priority_behavior
	
	# Update active behavior
	if is_instance_valid(active_behavior):
		active_behavior.update(delta, context)
		
		# Check if behavior completed
		if active_behavior.state == Behavior.State.COMPLETED:
			active_behavior = null
			# Check if we should complete the task
			if behaviors.is_empty() or _all_behaviors_completed():
				state = State.COMPLETED
				completed.emit()

## Interrupt the task
func interrupt() -> void:
	if state == State.ACTIVE:
		state = State.INTERRUPTED
		if is_instance_valid(active_behavior):
			active_behavior.interrupt()
		active_behavior = null
		interrupted.emit()

## Reset the task to its initial state
func reset() -> void:
	state = State.INACTIVE
	active_behavior = null
	clear_condition_cache()
	
	# Reset all behaviors
	for behavior in behaviors:
		if is_instance_valid(behavior):
			behavior.reset()

## Clear the condition evaluation cache
func clear_condition_cache() -> void:
	_condition_cache.clear()

## Check if all conditions are met
func _check_conditions(context: Dictionary) -> bool:
	if conditions.is_empty():
		return true
	
	for condition in conditions:
		if not is_instance_valid(condition):
			continue
			
		if not condition.is_met(ant, _condition_cache, context):
			return false
	return true

## Check if all behaviors have completed
func _all_behaviors_completed() -> bool:
	for behavior in behaviors:
		if not is_instance_valid(behavior):
			continue
			
		if behavior.state != Behavior.State.COMPLETED:
			return false
	return true

## Update ant references in all behaviors
func _update_behavior_references() -> void:
	if not is_instance_valid(ant):
		return
		
	for behavior in behaviors:
		if is_instance_valid(behavior):
			behavior.ant = ant

## Get the current active behavior
func get_active_behavior() -> Behavior:
	return active_behavior

## Get all conditions for this task
func get_conditions() -> Array[Condition]:
	return conditions

## Get debug information about the task
func get_debug_info() -> Dictionary:
	return {
		"name": name,
		"state": State.keys()[state],
		"priority": priority,
		"behavior_count": behaviors.size(),
		"active_behavior": active_behavior.name if is_instance_valid(active_behavior) else "None",
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
			if is_instance_valid(condition):
				var config = condition.config
				print("%s    - %s" % [indent_str, config.get("type", "Unknown")])
	
	if not behaviors.is_empty():
		print("%s  Behaviors:" % indent_str)
		for behavior in behaviors:
			if is_instance_valid(behavior):
				print("%s    - %s (Priority: %d, State: %s)" % [
					indent_str,
					behavior.name,
					behavior.priority,
					Behavior.State.keys()[behavior.state]
				])
