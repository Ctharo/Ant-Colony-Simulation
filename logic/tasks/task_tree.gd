class_name TaskTree
extends Node

## Signal emitted when the tree's active behavior changes
signal active_task_changed(task: Task)

## Signal emitted when the tree updates
signal tree_updated

## The root behavior of the tree
var root_task: Task:
	get:
		return root_task
	set(value):
		if value != root_task:
			root_task = value
			if root_task:
				root_task.start(ant)

## The ant associated with this behavior tree
var ant: Ant:
	get:
		return ant
	set(value):
		if value != ant:
			ant = value
			if root_task:
				root_task.start(ant)

## Configuration manager for behaviors
var behavior_config: BehaviorConfig

## Last known active behavior for change detection
var _last_active_behavior: Behavior

## Print behavior hierarchy
func print_behavior_hierarchy() -> void:
	if root_task:
		print("\nBehavior Tree Hierarchy:")
		_print_task_recursive(root_task, 0)
	else:
		print("No root behavior set")

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
			var condition_name = condition.get_script().get_path().get_file().get_basename()
			print("%s    - %s" % [indent, condition_name])
	
	# Recursively print behaviors
	if not task.behaviors.is_empty():
		print("%s  Behaviors:" % indent)
		for behavior in task.behaviors:
			_print_task_recursive(behavior, depth + 1)
			
## Initialize the BehaviorTree with an ant
static func create(ant: Ant) -> TaskTreeBuilder:
	return TaskTreeBuilder.new(ant)

## Update the behavior tree
func update(delta: float) -> void:
	if not is_instance_valid(ant):
		push_warning("BehaviorTree: Ant reference is invalid")
		return
		
	if not root_task:
		push_warning("BehaviorTree: No root behavior set")
		return
	
	# Gather context for this update cycle
	var context := gather_context()
	
	# Update root behavior
	if root_task.state != Task.State.ACTIVE:
		root_task.start(ant)
	
	root_task.update(delta, context)
	
	# Check for active behavior changes
	var current_active = get_active_task()
	if current_active != _last_active_behavior:
		_last_active_behavior = current_active
		active_task_changed.emit(current_active)
	
	# Clean up after update
	_clear_condition_caches_recursive(root_task)
	tree_updated.emit()

## Gather context information for behaviors
func gather_context() -> Dictionary:
	return ContextBuilder.new(ant, behavior_config.condition_configs).build()

## Reset the behavior tree to its initial state
func reset() -> void:
	if root_task:
		root_task.reset()
	_last_active_behavior = null

## Get the current active behavior
func get_active_task() -> Task:
	return _get_active_task_recursive(root_task)

## Clear condition caches recursively
func _clear_condition_caches_recursive(task: Task) -> void:
	if not task:
		return
	
	task.clear_condition_cache()
	for behavior in task.behaviors:
		_clear_condition_caches_recursive(behavior)

## Recursively get the highest priority active task
func _get_active_task_recursive(task: Task) -> Task:
	if not task:
		return null
	
	if task.state == Task.State.ACTIVE:
		return task
	
	var highest_priority_task: Task = null
	var highest_priority: int = -1
	
	for behavior in task.behaviors:
		if behavior and behavior.priority > highest_priority:
			highest_priority_task = active_behavior
			highest_priority = active_behavior.priority
	
	return highest_priority_task

## Print the active task chain for debugging
func print_active_behavior_chain() -> void:
	var active := get_active_task()
	if active:
		var chain: Array[String] = []
		var current := active
		while current:
			chain.append(current.name)
			current = current.current_sub_behavior
		print("Active task chain: ", " -> ".join(chain))
