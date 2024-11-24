## A hierarchical tree structure for managing AI behavior tasks and their execution
class_name TaskTree
extends BaseNode

#region Signals
## Signal emitted when the tree's active task changes
signal active_task_changed(task: Task)
signal active_behavior_changed(behavior: Behavior)

## Signal emitted when the tree updates
signal tree_updated
#endregion

## Builder class for constructing the task tree
class Builder:
	extends BaseRefCounted

	var _ant: Ant
	var _root_type: String = "Root"
	var _tasks_path: String = "res://config/ant_tasks.json"
	var _conditions_path: String = "res://config/ant_conditions.json"

	func _init(p_ant: Ant) -> void:
		_ant = p_ant

	func with_root_task(type: String) -> Builder:
		_root_type = type
		return self

	func with_config_paths(tasks_path: String, conditions_path: String) -> Builder:
		_tasks_path = tasks_path
		_conditions_path = conditions_path
		return self

	func build() -> TaskTree:
		var tree := TaskTree.new()
		tree.ant = _ant

		# Load conditions first since tasks depend on them
		var result = ConditionSystem.load_condition_configs(_conditions_path)
		if result != OK:
			push_error("Failed to load condition configs from: %s" % _conditions_path)
			return tree

		# Load task configurations
		result = Task.load_task_configs(_tasks_path)
		if result != OK:
			push_error("Failed to load task configs from: %s" % _tasks_path)
			return tree

		# Create condition system
		tree._condition_system = ConditionSystem.new(_ant)

		# Create task behaviors
		var behaviors = Task.create_task_behaviors(
			_root_type,
			_ant,
			tree._condition_system
		)

		if behaviors.is_empty():
			push_error("Failed to create behaviors for task: %s" % _root_type)
			return tree

		# Create the task itself
		var task = Task.new(Task.Priority[Task._task_configs[_root_type].get("priority", "MEDIUM")], tree._condition_system)
		task.name = _root_type
		task.ant = _ant

		# Add task conditions
		var task_config = Task._task_configs[_root_type]
		if "conditions" in task_config:
			for condition_data in task_config.conditions:
				var condition = ConditionSystem.create_condition(condition_data)
				task.add_condition(condition)

		# Add behaviors to task
		for behavior in behaviors:
			task.add_behavior(behavior)

		tree.root_task = task
		_debug("Successfully built task tree with root task: %s" % _root_type)

		return tree

#endregion

#region Properties
## The root task of the tree that serves as the entry point for task execution
var root_task: Task:
	get:
		return root_task
	set(value):
		if value != root_task:
			root_task = value
			if root_task and is_instance_valid(ant):
				root_task.start(ant, _condition_system)

## The ant agent associated with this task tree
var ant: Ant:
	get:
		return ant
	set(value):
		if value != ant:
			ant = value

## Condition evaluation system
var _condition_system: ConditionSystem

## Last known active task for change detection
var _last_active_task: Task
#endregion

func _ready() -> void:
	log_from = "task_tree"
	log_category = DebugLogger.Category.TASK

#region Public Methods
## Creates a new TaskTree instance with the specified ant agent
## [param _ant] The ant agent to associate with this task tree
## [return] A new TaskTreeBuilder instance for configuring the task tree
static func create(_ant: Ant) -> Builder:
	return Builder.new(_ant)

## Updates the task tree's state and propagates updates to child tasks
## [param delta] The time elapsed since the last update
func update(delta: float) -> void:
	if not is_instance_valid(ant):
		_error("Ant reference is invalid")
		return

	if not root_task:
		_error("No root task set")
		return

	_debug("=== Task Tree Update ===")

	_condition_system.clear_cache()

	var context := gather_context()

	if root_task.state != Task.State.ACTIVE:
		_info("Starting root task: %s" % root_task.name)
		root_task.start(ant)

	var previous_active = get_active_task()
	var previous_behavior = previous_active.get_active_behavior() if previous_active else null

	root_task.update(delta, context)

	var current_active = get_active_task()
	var current_behavior = current_active.get_active_behavior() if current_active else null

	if current_active != previous_active:
		_info("Task Transition: %s -> %s" % [
			previous_active.name if previous_active else "None",
			current_active.name if current_active else "None"
		])

	if current_behavior != previous_behavior:
		_log_behavior_transition(previous_behavior, current_behavior, current_active)

	if current_active != _last_active_task:
		_last_active_task = current_active
		active_task_changed.emit(current_active)

	tree_updated.emit()

## Gathers context information used by tasks and behaviors for decision making
## [return] A dictionary containing the current context information
func gather_context() -> Dictionary:
	var context = {}

	# Add required properties
	for property in _condition_system.get_required_properties():
		var path := Path.parse(property)
		context[path.full] = _condition_system.get_property_value(path)

	return context

## Resets the task tree to its initial state
func reset() -> void:
	if root_task:
		root_task.reset()
	_last_active_task = null
	_condition_system.clear_cache()

## Returns the currently active task in the tree
## [return] The active Task instance or null if no task is active
func get_active_task() -> Task:
	return _get_active_task_recursive(root_task)

## Evaluate a condition with the current context
func evaluate_condition(condition: ConditionSystem.Condition) -> bool:
	var context = gather_context()
	return _condition_system.evaluate_condition(condition, context)

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
		_info("Active task chain: -> ".join(chain))
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

		for behavior: Behavior in behaviors:
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
func _print_condition_recursive(condition: ConditionSystem.Condition, indent: String) -> void:
	if not is_instance_valid(condition):
		return

	var result = evaluate_condition(condition)
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
					var sub_condition = ConditionSystem.create_condition(operand)
					_print_condition_recursive(sub_condition, indent + "    ")
		_:
			if condition_config.has("evaluation"):
				var eval = condition_config.evaluation
				var property_name = eval.get("property", "unknown")
				var operator = eval.get("operator", "EQUALS")
				var value = eval.get("value", "N/A")
				var value_from = eval.get("value_from", "")
				var condition_desc = "%s %s" % [property_name, operator]
				if str(value) != "N/A":
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
	transition_info += "║   Task: %s\n" % task.name if task else "None"
	transition_info += "║   From: %s\n" % (previous_behavior.name if previous_behavior else "None")
	transition_info += "║   To: %s\n" % (current_behavior.name if current_behavior else "None")
	transition_info += "║   Priority: %d" % (current_behavior.priority if current_behavior else -1)

	_info(transition_info)

	# Print conditions with their complete evaluation chain
	var conditions = current_behavior.get_conditions() if current_behavior else []
	if not conditions.is_empty():
		var conditions_info = "║\n║   Conditions:"
		_debug(conditions_info)

		for condition in conditions:
			_print_condition_recursive(condition, "║   ")

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
	_debug(conditions_header)

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
