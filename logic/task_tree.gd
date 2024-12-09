class_name TaskTree
extends Node

#region Signals
## Signal emitted when the tree's active task changes
signal active_task_changed(task: Task)
## Signal emitted when the active behavior changes
signal active_behavior_changed(behavior: Behavior)
## Signal emitted when the tree updates
signal tree_updated
#endregion

#region Properties
## The root task of the tree
var _root_task: Task  # Changed to private variable with underscore

var root_task: Task:  # Property for controlled access
	get:
		return _root_task
	set(value):
		if value != _root_task:
			_root_task = value  # Set the private variable directly
			if _root_task:
				_root_task.initialize(_evaluation_system)
				if is_instance_valid(ant):
					_root_task.start(ant)

## The ant agent associated with this task tree
var ant: Ant:
	get:
		return ant
	set(value):
		if value != ant:
			ant = value
			if root_task:
				root_task.start(ant)

## Last known active task for change detection
var _last_active_task: Task

## System for evaluating conditions
var _evaluation_system: EvaluationSystem

## Logger instance
var logger: Logger

## Update timer for controlling update frequency
var update_timer: float = 0.0

## Update interval in seconds
const UPDATE_INTERVAL: float = 1.0
#endregion

#region Initialization
func _init() -> void:
	logger = Logger.new("task_tree", DebugLogger.Category.TASK)
	_evaluation_system = EvaluationSystem.new()

func _ready() -> void:
	_evaluation_system.initialize(self)
#endregion

#region Engine Callbacks
func _process(delta: float) -> void:
	update_timer += delta
	if update_timer >= UPDATE_INTERVAL:
		update(delta)
#endregion

#region Public Methods
## Creates a new TaskTree instance with the specified ant agent
static func create(_ant: Ant) -> Builder:
	return Builder.new(_ant)

## Updates the task tree's state and propagates updates
func update(delta: float) -> bool:
	if not _validate_tree_state():
		return false

	var previous_active = get_active_task()
	var previous_behavior = previous_active.get_active_behavior() if previous_active else null

	root_task.update(delta)

	var current_active = get_active_task()
	var current_behavior = current_active.get_active_behavior() if current_active else null

	_handle_state_changes(previous_active, current_active, previous_behavior, current_behavior)

	update_timer = 0.0
	tree_updated.emit()
	return true

## Resets the task tree to its initial state
func reset() -> void:
	if root_task:
		root_task.reset()
	_last_active_task = null

## Returns the currently active task in the tree
func get_active_task() -> Task:
	return _get_active_task_recursive(root_task)

## Evaluate an expression with the current context
func evaluate_expression(expression: Logic) -> Variant:
	return expression.evaluate()

## Prints the chain of active tasks for debugging
func print_active_task_chain() -> void:
	var active := get_active_task()
	if active:
		var chain: Array[String] = []
		chain.append(active.name)
		if active.get_active_behavior():
			chain.append(active.get_active_behavior().name)
		logger.info("Active task chain: -> ".join(chain))
#endregion

#region Private Methods
## Setup the root task and initialize it
func _setup_root_task(task: Task) -> void:
	root_task = task
	if root_task:
		root_task.initialize(_evaluation_system)
		if is_instance_valid(ant):
			root_task.start(ant)

## Validate the tree is in a valid state for updating
func _validate_tree_state() -> bool:
	if not is_instance_valid(ant):
		logger.error("Ant reference is invalid")
		return false

	if not root_task:
		logger.error("No root task set")
		return false

	if root_task.state != Task.State.ACTIVE:
		logger.info("Starting root task: %s" % root_task.name)
		root_task.start(ant)

	return true

## Handle state changes in tasks and behaviors
func _handle_state_changes(previous_task: Task, current_task: Task, 
						 previous_behavior: Behavior, current_behavior: Behavior) -> void:
	if current_task != previous_task:
		logger.info("Task Transition: %s -> %s" % [
			previous_task.name if previous_task else "None",
			current_task.name if current_task else "None"
		])

	if current_task != _last_active_task:
		_last_active_task = current_task
		active_task_changed.emit(current_task)

	if current_behavior != previous_behavior:
		active_behavior_changed.emit(current_behavior)

## Recursively finds the highest priority active task
func _get_active_task_recursive(task: Task) -> Task:
	if not task:
		return null

	if task.state == Task.State.ACTIVE:
		return task

	var highest_priority_task: Task = null
	var highest_priority: int = -1

	for behavior in task.behaviors:
		if behavior.state == Behavior.State.ACTIVE and behavior.priority > highest_priority:
			highest_priority_task = task
			highest_priority = behavior.priority

	return highest_priority_task
#endregion

#region Builder
## Builder class for constructing the task tree
class Builder:
	var _ant: Ant
	var _root_task: Task
	var _behaviors: Array[Behavior] = []
	var _conditions: Array[Logic] = []
	var logger: Logger

	func _init(p_ant: Ant) -> void:
		logger = Logger.new("task_tree_builder", DebugLogger.Category.TASK)
		_ant = p_ant
		_root_task = Task.new()
		_root_task.name = "Root"

	## Add a behavior to the root task
	func add_behavior(behavior: Behavior) -> Builder:
		_behaviors.append(behavior)
		return self

	## Add a condition to the root task
	func add_condition(condition: Logic) -> Builder:
		_conditions.append(condition)
		return self

	## Set the name of the root task
	func with_name(name: String) -> Builder:
		_root_task.name = name
		return self

	## Set the priority of the root task
	func with_priority(priority: int) -> Builder:
		_root_task.priority = priority
		return self

	## Build and return the configured TaskTree
	func build() -> TaskTree:
		var tree := TaskTree.new()
		tree.ant = _ant

		# Configure root task
		for behavior in _behaviors:
			_root_task.add_behavior(behavior)

		for condition in _conditions:
			_root_task.add_condition(condition)

		tree.root_task = _root_task
		logger.info("Successfully built task tree with root task: %s" % _root_task.name)

		return tree
#endregion
