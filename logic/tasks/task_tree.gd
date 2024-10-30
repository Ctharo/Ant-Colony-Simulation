class_name TaskTree
extends Node

## Signal emitted when the tree's active task changes
signal active_task_changed(task: Task)

## Signal emitted when the tree's active behavior changes
signal active_behavior_changed(behavior: Behavior)

## Signal emitted when the tree updates
signal tree_updated

## The root task of the tree
var root_task: Task:
	get:
		return root_task
	set(value):
		if value != root_task:
			root_task = value
			if root_task:
				if OS.is_debug_build():
					print("\nStarting root task: %s" % root_task.name)
				root_task.start(ant)

## The ant associated with this task tree
var ant: Ant:
	get:
		return ant
	set(value):
		if value != ant:
			ant = value
			if root_task:
				root_task.start(ant)

## Configuration manager for tasks and behaviors
var task_config: TaskConfig

## Last known active task for change detection
var _last_active_task: Task

## Print task hierarchy
func print_task_hierarchy() -> void:
	if root_task:
		# Make sure we have latest context
		var context = gather_context()
		
		# Update the context one last time to ensure states are current
		root_task.update(0.0, context)
		
		print("\nTask Tree Hierarchy:")
		_print_task_recursive(root_task, 0)
	else:
		print("No root task set")

## Print task hierarchy recursively with current state
func _print_task_recursive(task: Task, depth: int) -> void:
	if not is_instance_valid(task):
		push_warning("Invalid task reference in hierarchy")
		return
		
	var indent = "  ".repeat(depth)
	print("\n%s╔══ Task: %s" % [indent, task.name if not task.name.is_empty() else "Unnamed"])
	print("%s║   Priority: %d" % [indent, task.priority])
	print("%s║   State: %s" % [indent, Task.State.keys()[task.state]])
	
	var active_behavior = task.get_active_behavior()
	if active_behavior:
		print("%s║   Current Active Behavior: %s (State: %s)" % [
			indent,
			active_behavior.name,
			Behavior.State.keys()[active_behavior.state]
		])
	else:
		print("%s║   Current Active Behavior: None" % indent)
	
	# Print task conditions with context
	var task_conditions = task.get_conditions()
	if not task_conditions.is_empty():
		print("%s║" % indent)
		print("%s║   Conditions:" % indent)
		for condition in task_conditions:
			_print_condition_recursive(condition, indent + "║   ")
	
	# Print behaviors with their conditions and current states
	var behaviors = task.behaviors
	if not behaviors.is_empty():
		print("%s║" % indent)
		print("%s║   Behaviors:" % indent)
		for behavior in behaviors:
			if not is_instance_valid(behavior):
				continue
				
			# Highlight if this is the active behavior
			var is_active = (behavior == active_behavior)
			var active_marker = " (ACTIVE)" if is_active else ""
			
			print("%s║   ├── %s%s" % [indent, behavior.name, active_marker])
			print("%s║   │   Priority: %d" % [indent, behavior.priority])
			print("%s║   │   State: %s" % [indent, Behavior.State.keys()[behavior.state]])
			
			# Print behavior conditions
			var behavior_conditions = behavior.get_conditions()
			if not behavior_conditions.is_empty():
				print("%s║   │" % indent)
				print("%s║   │   Conditions:" % indent)
				for condition in behavior_conditions:
					_print_condition_recursive(condition, indent + "║   │   ")
			
			# Print behavior actions
			if not behavior.actions.is_empty():
				print("%s║   │" % indent)
				print("%s║   │   Actions:" % indent)
				for action in behavior.actions:
					if is_instance_valid(action):
						print("%s║   │   └── %s" % [indent, action.get_script().resource_path.get_file()])
			print("%s║" % indent)

## Recursively print condition hierarchy with results
func _print_condition_recursive(condition: Condition, indent: String, result: bool = false) -> void:
	if not is_instance_valid(condition):
		return
		
	var condition_config = condition.config
	var condition_type = condition_config.get("type", "Unknown")
	var result_str = " [✓]" if result else " [✗]"
	
	match condition_type:
		"Operator":
			var operator = condition_config.get("operator_type", "Unknown").to_upper()
			print("%s╟── Operator: %s%s" % [indent, operator, result_str])
			
			if condition_config.has("operands"):
				for i in range(condition_config.operands.size()):
					var operand = condition_config.operands[i]
					print("%s║   └── Operand %d:" % [indent, i + 1])
					var context = gather_context()
					var sub_condition = Condition.create_from_config(operand)
					var sub_result = sub_condition.is_met({}, context)
					_print_condition_recursive(sub_condition, indent + "    ", sub_result)
		_:
			if condition_config.has("evaluation"):
				var eval = condition_config.evaluation
				var property_name = eval.get("property", "unknown")
				var operator = eval.get("operator", "EQUALS")
				var value = eval.get("value", "N/A")
				var value_from = eval.get("value_from", "")
				var condition_desc = "%s %s" % [property_name, operator]
				if value != "N/A":
					condition_desc += " %s" % value
				elif not value_from.is_empty():
					condition_desc += " %s" % value_from
				print("%s╟── PropertyCheck: %s%s" % [indent, condition_desc, result_str])
			else:
				print("%s╟── %s%s" % [indent, condition_type, result_str])

## Log behavior transition with consistent formatting
func _log_behavior_transition(previous_behavior: Behavior, current_behavior: Behavior, task: Task) -> void:
	print("\n╔══ Behavior Transition")
	print("║   Task: %s" % task.name)
	print("║   From: %s" % (previous_behavior.name if previous_behavior else "None"))
	print("║   To: %s" % current_behavior.name)
	print("║   Priority: %d" % current_behavior.priority)
	
	# Print conditions with their complete evaluation chain
	var conditions = current_behavior.get_conditions()
	if not conditions.is_empty():
		print("║")
		print("║   Conditions:")
		var context = gather_context()
		for condition in conditions:
			var result = condition.is_met({}, context)
			_print_condition_recursive(condition, "║   ", result)
	print("╚══")

## Update the task tree with detailed state transition logging
func update(delta: float) -> void:
	if not is_instance_valid(ant):
		push_warning("TaskTree: Ant reference is invalid")
		return
		
	if not root_task:
		push_warning("TaskTree: No root task set")
		return
	
	if OS.is_debug_build():
		print("\n=== Task Tree Update ===")
	
	# Gather context for this update cycle
	var context := gather_context()
	
	# Update root task
	if root_task.state != Task.State.ACTIVE:
		if OS.is_debug_build():
			print("Starting root task: %s" % root_task.name)
		root_task.start(ant)
	
	# Record previous state for logging
	var previous_active = get_active_task()
	var previous_behavior = previous_active.get_active_behavior() if previous_active else null
	
	root_task.update(delta, context)
	
	# Check for and log state changes
	var current_active = get_active_task()
	var current_behavior = current_active.get_active_behavior() if current_active else null
	
	if OS.is_debug_build():
		if current_active != previous_active:
			print("\n╔══ Task Transition")
			print("║   From: %s" % (previous_active.name if previous_active else "None"))
			print("║   To: %s" % current_active.name)
			print("╚══")
		
		if current_behavior != previous_behavior:
			_log_behavior_transition(previous_behavior, current_behavior, current_active)
	
	if current_active != _last_active_task:
		_last_active_task = current_active
		active_task_changed.emit(current_active)
	
	# Clean up after update
	_clear_condition_caches_recursive(root_task)
	tree_updated.emit()


## Initialize the TaskTree with an ant
static func create(_ant: Ant) -> TaskTreeBuilder:
	return TaskTreeBuilder.new(_ant)


## Gather context information for tasks and behaviors
func gather_context() -> Dictionary:
	return ContextBuilder.new(ant, task_config.condition_configs).build()

## Reset the task tree to its initial state
func reset() -> void:
	if root_task:
		root_task.reset()
	_last_active_task = null

## Get the current active task
func get_active_task() -> Task:
	return _get_active_task_recursive(root_task)

## Clear condition caches recursively
func _clear_condition_caches_recursive(task: Task) -> void:
	if not task:
		return
	
	task.clear_condition_cache()
	for behavior in task.behaviors:
		behavior.clear_condition_cache()

## Recursively get the highest priority active task
func _get_active_task_recursive(task: Task) -> Task:
	if not task:
		return null
	
	if task.state == Task.State.ACTIVE:
		return task
	
	var highest_priority_task: Task = null
	var highest_priority: int = -1
	
	for behavior in task.behaviors:
		if behavior.state == Behavior.State.ACTIVE and behavior.priority > highest_priority:
			# If a behavior is active, its parent task is considered active
			highest_priority_task = task
			highest_priority = behavior.priority
	
	return highest_priority_task

## Print the active task chain for debugging
func print_active_task_chain() -> void:
	var active := get_active_task()
	if active:
		var chain: Array[String] = []
		chain.append(active.name)
		if active.get_active_behavior():
			chain.append(active.get_active_behavior().name)
		print("Active task chain: ", " -> ".join(chain))
