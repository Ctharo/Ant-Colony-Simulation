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

## Condition evaluation system
var _condition_system: ConditionSystem

## Last known active task for change detection
var _last_active_task: Task

var _context_registry: ContextRegistry

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

func _setup_context_providers() -> void:
	# Register context providers based on condition system requirements
	for property in _condition_system.get_required_properties():
		var path: Path = Path.parse(property)

		# Determine update frequency based on property type
		# This could be configured via property metadata or condition requirements
		var frequency = _get_property_frequency(path)
		var can_interrupt = _can_property_interrupt(path)

		_context_registry.register_value(
			path.full,
			frequency,
			func(): return ant.get_property_value(path.full),
			can_interrupt
		)

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

	_context_registry.update(update_timer)
	var context := gather_context()

	if root_task.state != Task.State.ACTIVE:
		logger.info("Starting root task: %s" % root_task.name)
		root_task.start(ant)

	var previous_active = get_active_task()
	var previous_behavior = previous_active.get_active_behavior() if previous_active else null

	root_task.update(update_timer, context)

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

# TODO: Not working
func _get_property_frequency(_path: Path) -> Context.UpdateFrequency:
	return Context.UpdateFrequency.NORMAL  # Default frequency

# TODO: Not working
func _can_property_interrupt(_path: Path) -> bool:
	return false

## Gathers context information used by tasks and behaviors for decision making
## [return] A dictionary containing the current context information
func gather_context() -> Dictionary:
	return _context_registry.get_context()

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
func evaluate_condition(condition: Condition) -> bool:
	var context = gather_context()
	return _condition_system.evaluate_condition(condition, context)

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

		assert(AntConfigs.behavior_configs)
		assert(AntConfigs.task_configs)
		assert(AntConfigs.condition_configs)

		# Create condition system
		tree._condition_system = ConditionSystem.new(_ant)

		# Create context provider
		tree._context_registry = ContextRegistry.new()
		tree._setup_context_providers()

		# Create task behaviors
		var behaviors = AntConfigs.create_task_behaviors(
			_root_type,
			_ant,
			tree._condition_system
		)

		if behaviors.is_empty():
			logger.error("Failed to create behaviors for task: %s" % _root_type)
			return tree

		# Create the task itself
		var task = Task.new(Task.Priority[AntConfigs._task_configs[_root_type].get("priority", "MEDIUM")], tree._condition_system)
		task.name = _root_type
		task.ant = _ant

		# Add task conditions
		var task_config = AntConfigs._task_configs[_root_type]
		if "conditions" in task_config:
			for condition_data in task_config.conditions:
				var condition = AntConfigs.create_condition(condition_data)
				task.add_condition(condition)

		# Add behaviors to task
		for behavior in behaviors:
			task.add_behavior(behavior)

		tree.root_task = task
		logger.info("Successfully built task tree with root task: %s" % _root_type)

		return tree

#endregion
