class_name TaskTree
extends Node

## Signal emitted when the tree's active task changes
signal active_task_changed(task: Task)

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
		print("\nTask Tree Hierarchy:")
		_print_task_recursive(root_task, 0)
	else:
		print("No root task set")

## Recursively print task hierarchy with improved formatting
func _print_task_recursive(task: Task, depth: int) -> void:
	var indent = "  ".repeat(depth)
	print("%s- %s (Priority: %d)" % [
		indent, 
		task.name if not task.name.is_empty() else "Unnamed",
		task.priority
	])
	
	# Print conditions
	if not task.conditions.is_empty():
		print("%s  Conditions:" % indent)
		for condition in task.conditions:
			print("%s    - %s" % [indent, condition.get("type", "Unknown")])
	
	# Print behaviors
	if not task.behaviors.is_empty():
		print("%s  Behaviors:" % indent)
		for behavior in task.behaviors:
			print("%s    - %s (Priority: %d)" % [
				indent,
				behavior.name,
				behavior.priority
			])

## Initialize the TaskTree with an ant
static func create(ant: Ant) -> TaskTreeBuilder:
	return TaskTreeBuilder.new(ant)

## Update the task tree
func update(delta: float) -> void:
	if not is_instance_valid(ant):
		push_warning("TaskTree: Ant reference is invalid")
		return
		
	if not root_task:
		push_warning("TaskTree: No root task set")
		return
	
	# Gather context for this update cycle
	var context := gather_context()
	
	# Update root task
	if root_task.state != Task.State.ACTIVE:
		root_task.start(ant)
	
	root_task.update(delta, context)
	
	# Check for active task changes
	var current_active = get_active_task()
	if current_active != _last_active_task:
		_last_active_task = current_active
		active_task_changed.emit(current_active)
	
	# Clean up after update
	_clear_condition_caches_recursive(root_task)
	tree_updated.emit()

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
