## A hierarchical tree structure for managing AI behavior tasks and their execution
class_name TaskTree
extends Node

#region Signals
## Signal emitted when the tree's active task changes
signal active_task_changed(task: Task)
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
			if root_task and is_instance_valid(ant):
				root_task.start(ant)

## The ant agent associated with this task tree
var ant: Ant:
	get:
		return ant
	set(value):
		if value != ant:
			ant = value

## Last known active task for change detection
var _last_active_task: Task



var logger: Logger

var update_timer: float = 0.0
#endregion

func _init() -> void:
	logger = Logger.new("task_tree", DebugLogger.Category.TASK)

func _process(delta: float) -> void:
	update_timer += delta
	if update_timer >= 1.0:
		update_timer = 0.0
		update(delta)

#region Public Methods
## Creates a new TaskTree instance with the specified ant agent
## [param _ant] The ant agent to associate with this task tree
## [return] A new TaskTreeBuilder instance for configuring the task tree
static func create(_ant: Ant) -> Builder:
	return Builder.new(_ant)

## Updates the task tree's state and propagates updates to child tasks
## [param delta] The time elapsed since the last update
func update(delta: float) -> bool:
	update_timer += delta
	if update_timer < 1.0:
		return false
	logger.trace("Updating task tree")
	if not is_instance_valid(ant):
		logger.error("Ant reference is invalid")
		return false

	if not root_task:
		logger.error("No root task set")
		return false

	if root_task.state != Task.State.ACTIVE:
		logger.info("Starting root task: %s" % root_task.name)
		root_task.start(ant)

	var previous_active = get_active_task()
	var previous_behavior = previous_active.get_active_behavior() if previous_active else null

	root_task.update(update_timer)

	var current_active = get_active_task()
	var current_behavior = current_active.get_active_behavior() if current_active else null

	if current_active != previous_active:
		logger.info("Task Transition: %s -> %s" % [
			previous_active.name if previous_active else "None",
			current_active.name if current_active else "None"
		])

	if current_active != _last_active_task:
		_last_active_task = current_active
		active_task_changed.emit(current_active)

	update_timer = 0.0
	tree_updated.emit()
	return true


## Resets the task tree to its initial state
func reset() -> void:
	if root_task:
		root_task.reset()
	_last_active_task = null


## Returns the currently active task in the tree
## [return] The active Task instance or null if no task is active
func get_active_task() -> Task:
	return _get_active_task_recursive(root_task)

## Evaluate an expression with the current context
func evaluate_expression(expression: LogicExpression) -> Variant:
	return expression.evaluate()

## Prints the chain of active tasks for debugging purposes
func print_active_task_chain() -> void:
	var active := get_active_task()
	if active:
		var chain: Array[String] = []
		chain.append(active.name)
		if active.get_active_behavior():
			chain.append(active.get_active_behavior().name)
		logger.info("Active task chain: -> ".join(chain))
#endregion

#region Private Helper Methods
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

#region Builder
## Builder class for constructing the task tree
class Builder:

	var _ant: Ant
	var _root_type: String = "Root"
	var logger: Logger

	func _init(p_ant: Ant) -> void:
		logger = Logger.new("task_tree_builder", DebugLogger.Category.TASK)
		_ant = p_ant

	func with_root_task(type: String) -> Builder:
		_root_type = type
		return self

	func build() -> TaskTree:
		var tree := TaskTree.new()
		tree.ant = _ant

		# Create the task from config
		var task = Task.new()

		if not task:
			logger.error("Failed to create task: %s" % _root_type)
			return tree

		tree.root_task = task
		logger.info("Successfully built task tree with root task: %s" % _root_type)

		return tree

#endregion
