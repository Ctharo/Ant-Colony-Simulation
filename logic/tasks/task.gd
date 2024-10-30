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

## Whether higher priority behaviors can interrupt lower priority ones
var allow_interruption: bool = true

## Update the task and its behaviors
func update(delta: float, context: Dictionary) -> void:
	if state != Task.State.ACTIVE:
		return
	
	if OS.is_debug_build():
		print("\nUpdating Task: %s" % name)
		print("Current active behavior: %s (State: %s)" % [
			active_behavior.name if active_behavior else "None",
			Behavior.State.keys()[active_behavior.state] if active_behavior else "N/A"
		])
	
	# Check task conditions
	if not _check_conditions(context):
		interrupt()
		return
	
	# First check if current behavior should continue
	if active_behavior and active_behavior.should_activate(context):
		if OS.is_debug_build():
			print("Current behavior valid, checking for higher priority behaviors")
		
		var higher_priority_behavior = _check_higher_priority_behaviors(active_behavior.priority, context)
		if higher_priority_behavior:
			_switch_behavior(higher_priority_behavior)
		else:
			if OS.is_debug_build():
				print("No higher priority behaviors to activate, continuing current behavior")
			active_behavior.update(delta, context)
		return
	
	# If we get here, either there's no active behavior or it's no longer valid
	var next_behavior = _find_next_valid_behavior(context)
	if next_behavior:
		_switch_behavior(next_behavior)
	elif active_behavior:
		active_behavior.interrupt()
		active_behavior = null

## Check only behaviors with higher priority than the current one
func _check_higher_priority_behaviors(current_priority: int, context: Dictionary) -> Behavior:
	# Group behaviors by priority
	var priority_groups: Dictionary = {}
	for behavior in behaviors:
		if not is_instance_valid(behavior):
			continue
		if behavior.priority <= current_priority:
			continue
		if not behavior.priority in priority_groups:
			priority_groups[behavior.priority] = []
		priority_groups[behavior.priority].append(behavior)
	
	# Sort priorities in descending order
	var priorities = priority_groups.keys()
	priorities.sort()
	priorities.reverse()
	
	if OS.is_debug_build():
		print("\nChecking higher priority behaviors (current priority: %d)" % current_priority)
	
	# Check behaviors by priority level
	for _priority in priorities:
		if OS.is_debug_build():
			print("\nChecking priority level: %d" % _priority)
		
		var behaviors_at_priority = priority_groups[_priority]
		var any_conditions_met = false
		
		for behavior in behaviors_at_priority:
			if OS.is_debug_build():
				print("Checking behavior: %s" % behavior.name)
			
			var should_activate = behavior.should_activate(context)
			
			if OS.is_debug_build():
				print("  Should activate: %s" % should_activate)
			
			if should_activate:
				return behavior
			
			any_conditions_met = any_conditions_met or should_activate
		
		# If no behaviors at this priority level could activate,
		# we can skip all lower priorities
		if not any_conditions_met:
			if OS.is_debug_build():
				print("  No behaviors at priority %d could activate, stopping checks" % priority)
			break
	
	return null
	
## Find the next valid behavior
func _find_next_valid_behavior(context: Dictionary) -> Behavior:
	# Group behaviors by priority
	var priority_groups: Dictionary = {}
	for behavior in behaviors:
		if not is_instance_valid(behavior):
			continue
		if not behavior.priority in priority_groups:
			priority_groups[behavior.priority] = []
		priority_groups[behavior.priority].append(behavior)
	
	# Sort priorities in descending order
	var priorities = priority_groups.keys()
	priorities.sort()
	priorities.reverse()
	
	# Check behaviors in priority order
	for priority in priorities:
		var behaviors_at_priority = priority_groups[priority]
		for behavior in behaviors_at_priority:
			if OS.is_debug_build():
				print("\nChecking behavior: %s" % behavior.name)
				print("  Priority: %d" % behavior.priority)
			
			if behavior.should_activate(context):
				return behavior
		
		if OS.is_debug_build() and not behaviors_at_priority.is_empty():
			print("  No behaviors at priority %d could activate" % priority)
	
	return null

## Switch to a new behavior
func _switch_behavior(new_behavior: Behavior) -> void:
	if OS.is_debug_build():
		print("\nSwitching behaviors:")
		print("  From: %s (State: %s)" % [
			active_behavior.name if active_behavior else "None",
			Behavior.State.keys()[active_behavior.state] if active_behavior else "N/A"
		])
		print("  To: %s" % new_behavior.name)
	
	if active_behavior:
		active_behavior.interrupt()
	
	active_behavior = new_behavior
	active_behavior.start(ant)
	
	if OS.is_debug_build():
		print("  After switch - New behavior: %s (State: %s)" % [
			active_behavior.name,
			Behavior.State.keys()[active_behavior.state]
		])

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
	
	if active_behavior:
		active_behavior.interrupt()
	active_behavior = null
	
	# Reset all behaviors
	for behavior in behaviors:
		if is_instance_valid(behavior):
			behavior.reset()
	
	clear_condition_cache()

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
			
		if not condition.is_met(_condition_cache, context):
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
	if not is_instance_valid(active_behavior):
		return null
		
	if active_behavior.state != Behavior.State.ACTIVE:
		return null
		
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

## Print task hierarchy recursively
func _print_task_recursive(task: Task, depth: int) -> void:
	if not is_instance_valid(task):
		push_warning("Invalid task reference in hierarchy")
		return
		
	var indent = "  ".repeat(depth)
	print("\n%s╔══ Task: %s" % [indent, task.name if not task.name.is_empty() else "Unnamed"])
	print("%s║   Priority: %d" % [indent, task.priority])
	print("%s║   State: %s" % [indent, Task.State.keys()[task.state]])
	
	if OS.is_debug_build():
		print("%s║   Current Active Behavior: %s" % [
			indent,
			active_behavior.name if active_behavior else "None"
		])
