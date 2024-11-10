## A hierarchical tree structure for managing AI behavior tasks and their execution
class_name TaskTree
extends Node

#region Signals
## Signal emitted when the tree's active task changes
signal active_task_changed(task: Task)

## Signal emitted when the tree's active behavior changes
signal active_behavior_changed(behavior: Behavior)

## Signal emitted when the tree updates
signal tree_updated
#endregion

#region Properties
## The root task of the tree that serves as the entry point for task execution
var root_task: Task:
	get:
		return root_task
	set(value):
		if value != root_task:
			root_task = value
			if root_task:
				root_task.start(ant)

## The ant agent associated with this task tree
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

var _cache: Cache = Cache.new()

## Last known active task for change detection
var _last_active_task: Task
#endregion

#region Public Methods
## Creates a new TaskTree instance with the specified ant agent
## [param _ant] The ant agent to associate with this task tree
## [return] A new TaskTreeBuilder instance for configuring the task tree
static func create(_ant: Ant) -> TaskTreeBuilder:
	return TaskTreeBuilder.new(_ant)

## Updates the task tree's state and propagates updates to child tasks
## [param delta] The time elapsed since the last update
func update(delta: float) -> void:
	clear_cache()

	if not is_instance_valid(ant):
		_error("TaskTree: Ant reference is invalid")
		return

	if not root_task:
		_error("TaskTree: No root task set")
		return

	_debug("=== Task Tree Update ===")

	# Gather context for this update cycle
	var context := gather_context()

	# Update root task
	if root_task.state != Task.State.ACTIVE:
		_info("Starting root task: %s" % root_task.name)
		root_task.start(ant)

	# Record previous state for logging
	var previous_active = get_active_task()
	var previous_behavior = previous_active.get_active_behavior() if previous_active else null

	root_task.update(delta, context)

	# Check for and log state changes
	var current_active = get_active_task()
	var current_behavior = current_active.get_active_behavior() if current_active else null

	if current_active != previous_active:
		_info("Task Transition: %s -> %s" % [
				previous_active.name if previous_active else "None",
				current_active.name
			]
		)

	if current_behavior != previous_behavior:
		_log_behavior_transition(previous_behavior, current_behavior, current_active)

	if current_active != _last_active_task:
		_last_active_task = current_active
		active_task_changed.emit(current_active)

	# Clean up after update
	tree_updated.emit()

## Gathers context information used by tasks and behaviors for decision making
## [return] A dictionary containing the current context information
func gather_context() -> Dictionary:
	return ContextBuilder.new(ant, task_config.condition_configs).build()

## Resets the task tree to its initial state
func reset() -> void:
	if root_task:
		root_task.reset()
	_last_active_task = null

## Returns the currently active task in the tree
## [return] The active Task instance or null if no task is active
func get_active_task() -> Task:
	return _get_active_task_recursive(root_task)

func clear_cache() -> void:
	_cache.clear()

## Cache condition result during update
func cache_condition_result(condition: Condition, context: Dictionary, result: bool) -> void:
	var cache_key = _get_condition_cache_key(condition, context)
	_cache.cache_value(cache_key, result)

## Generate cache key for condition
func _get_condition_cache_key(condition: Condition, context: Dictionary) -> String:
	var condition_str = JSON.stringify(condition.config)
	var context_values = []

	# Get required properties as Path objects
	for prop_str in condition.get_required_properties():
		var path := Path.parse(prop_str)
		if context.has(path.full):
			context_values.append("%s=%s" % [path.full, context[path.full]])

	return "%s|%s" % [condition_str, "|".join(context_values)]

## Prints the complete task hierarchy for debugging purposes
func print_task_hierarchy() -> void:
	if root_task:
		# Make sure we have latest context
		var context = gather_context()

		# Update the context one last time to ensure states are current
		root_task.update(0.0, context)

		_info("\nTask Tree Hierarchy:")
		_print_task_recursive(root_task, 0)
	else:
		_warn("No root task set")

## Prints the chain of active tasks for debugging purposes
func print_active_task_chain() -> void:
	var active := get_active_task()
	if active:
		var chain: Array[String] = []
		chain.append(active.name)
		if active.get_active_behavior():
			chain.append(active.get_active_behavior().name)
		DebugLogger.info(DebugLogger.Category.TASK, "Active task chain: -> ".join(chain))
#endregion

#region Private Helper Methods
## Recursively prints the task hierarchy with state information
## [param task] The task to print
## [param depth] The current depth in the hierarchy for indentation
func _print_task_recursive(task: Task, depth: int) -> void:
	if not is_instance_valid(task):
		_error("Invalid task reference in hierarchy")
		return

	var indent = "  ".repeat(depth)
	var active_behavior = task.get_active_behavior()

	# Combine task information into a single log message
	var task_info = "\n%s╔══ Task: %s\n" % [indent, task.name if not task.name.is_empty() else "Unnamed"]
	task_info += "%s║   Priority: %d\n" % [indent, task.priority]
	task_info += "%s║   State: %s\n" % [indent, Task.State.keys()[task.state]]

	if active_behavior:
		task_info += "%s║   Current Active Behavior: %s (State: %s)" % [
			indent,
			active_behavior.name,
			Behavior.State.keys()[active_behavior.state]
		]
	else:
		task_info += "%s║   Current Active Behavior: None" % indent

	_debug(task_info)

	# Print task conditions with context
	var task_conditions = task.get_conditions()
	if not task_conditions.is_empty():
		var conditions_info = "%s║\n%s║   Conditions:" % [indent, indent]
		_debug(conditions_info)
		for condition in task_conditions:
			_print_condition_recursive(condition, indent + "║   ")

	# Print behaviors section
	var behaviors = task.behaviors
	if not behaviors.is_empty():
		var behaviors_header = "%s║\n%s║   Behaviors:" % [indent, indent]
		_debug(behaviors_header)

		for behavior in behaviors:
			if not is_instance_valid(behavior):
				continue

			var is_active = (behavior == active_behavior)
			var behavior_info = _format_behavior_info(behavior, indent, is_active)
			_debug(behavior_info)

			# Print behavior conditions
			if not behavior.get_conditions().is_empty():
				_print_behavior_conditions(behavior, indent)

			# Print behavior actions
			if not behavior.actions.is_empty():
				_print_behavior_actions(behavior, indent)

## Recursively prints condition hierarchy with evaluation results
## [param condition] The condition to print
## [param indent] Current indentation string
## [param result] The evaluation result of the condition
func _print_condition_recursive(condition: Condition, indent: String, result: bool = false) -> void:
	if not is_instance_valid(condition):
		return

	var condition_config = condition.config
	var condition_type = condition_config.get("type", "Unknown")
	var result_str = " [✓]" if result else " [✗]"

	match condition_type:
		"Operator":
			var operator = condition_config.get("operator_type", "Unknown").to_upper()
			_info("%s╟── Operator: %s%s" % [indent, operator, result_str])

			if condition_config.has("operands"):
				for i in range(condition_config.operands.size()):
					var operand = condition_config.operands[i]
					_info("%s║   └── Operand %d:" % [indent, i + 1])
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
				_info("%s╟── PropertyCheck: %s%s" % [indent, condition_desc, result_str])
			else:
				_info("%s╟── %s%s" % [indent, condition_type, result_str])

## Logs behavior transitions with detailed information
## [param previous_behavior] The previously active behavior
## [param current_behavior] The newly active behavior
## [param task] The task containing these behaviors
func _log_behavior_transition(previous_behavior: Behavior, current_behavior: Behavior, task: Task) -> void:
	var transition_info = "\n╔══ Behavior Transition\n"
	transition_info += "║   Task: %s\n" % task.name
	transition_info += "║   From: %s\n" % (previous_behavior.name if previous_behavior else "None")
	transition_info += "║   To: %s\n" % current_behavior.name
	transition_info += "║   Priority: %d" % current_behavior.priority

	_info(transition_info)

	# Print conditions with their complete evaluation chain
	var conditions = current_behavior.get_conditions()
	if not conditions.is_empty():
		var context = gather_context()
		var conditions_info = "║\n║   Conditions:"
		DebugLogger.debug(DebugLogger.Category.CONDITION, conditions_info)

		for condition in conditions:
			var result = condition.is_met({}, context)
			_print_condition_recursive(condition, "║   ", result)

	_info("╚══")

## Formats behavior information for logging
## [param behavior] The behavior to format information for
## [param indent] Current indentation string
## [param is_active] Whether the behavior is currently active
## [return] Formatted behavior information string
func _format_behavior_info(behavior: Behavior, indent: String, is_active: bool) -> String:
	var active_marker = " (ACTIVE)" if is_active else ""
	var info = "%s║   ├── %s%s\n" % [indent, behavior.name, active_marker]
	info += "%s║   │   Priority: %d\n" % [indent, behavior.priority]
	info += "%s║   │   State: %s" % [indent, Behavior.State.keys()[behavior.state]]
	return info

## Prints behavior conditions for debugging
## [param behavior] The behavior whose conditions to print
## [param indent] Current indentation string
func _print_behavior_conditions(behavior: Behavior, indent: String) -> void:
	var conditions_header = "%s║   │\n%s║   │   Conditions:" % [indent, indent]
	DebugLogger.debug(DebugLogger.Category.CONDITION, conditions_header)

	for condition in behavior.get_conditions():
		_print_condition_recursive(condition, indent + "║   │   ")

## Prints behavior actions for debugging
## [param behavior] The behavior whose actions to print
## [param indent] Current indentation string
func _print_behavior_actions(behavior: Behavior, indent: String) -> void:
	var actions_header = "%s║   │\n%s║   │   Actions:" % [indent, indent]
	_debug(actions_header)

	for action in behavior.actions:
		if is_instance_valid(action):
			var action_info = "%s║   │   └── %s" % [
				indent,
				action.get_script().resource_path.get_file()
			]
			_debug(action_info)


## Recursively finds the highest priority active task
## [param task] The task to start searching from
## [return] The highest priority active task or null if none found
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
#endregion

#region Logging Methods
## Logs a trace message
## [param message] The message to log
func _trace(message: String) -> void:
	DebugLogger.trace(DebugLogger.Category.TASK,
		message,
		{"From": "task_tree"}
	)

## Logs a warning message
## [param message] The message to log
func _warn(message: String) -> void:
	DebugLogger.warn(DebugLogger.Category.TASK,
		message
	)

## Logs a debug message
## [param message] The message to log
func _debug(message: String) -> void:
	DebugLogger.debug(DebugLogger.Category.TASK,
		message
	)

## Logs an info message
## [param message] The message to log
func _info(message: String) -> void:
	DebugLogger.info(DebugLogger.Category.TASK,
		message
	)

## Logs an error message
## [param message] The message to log
func _error(message: String) -> void:
	DebugLogger.error(DebugLogger.Category.TASK,
		message
	)
#endregion
