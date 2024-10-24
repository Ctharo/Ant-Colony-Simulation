class_name BehaviorTree
extends Node

## Signal emitted when the tree's active behavior changes
signal active_behavior_changed(behavior: Behavior)

## Signal emitted when the tree updates
signal tree_updated

## The root behavior of the tree
var root_behavior: Behavior:
	get:
		return root_behavior
	set(value):
		if value != root_behavior:
			root_behavior = value
			if root_behavior:
				root_behavior.start(ant)

## The ant associated with this behavior tree
var ant: Ant:
	get:
		return ant
	set(value):
		if value != ant:
			ant = value
			if root_behavior:
				root_behavior.start(ant)

## Configuration manager for behaviors
var behavior_config: BehaviorConfig

## Last known active behavior for change detection
var _last_active_behavior: Behavior

## Print behavior hierarchy
func print_behavior_hierarchy() -> void:
	if root_behavior:
		print("\nBehavior Tree Hierarchy:")
		_print_behavior_recursive(root_behavior, 0)
	else:
		print("No root behavior set")

## Recursively print behavior hierarchy with improved formatting
func _print_behavior_recursive(behavior: Behavior, depth: int) -> void:
	var indent = "  ".repeat(depth)
	print("%s- %s (Priority: %d)" % [
		indent, 
		behavior.name if not behavior.name.is_empty() else "Unnamed",
		behavior.priority
	])
	
	# Print conditions
	if not behavior.conditions.is_empty():
		print("%s  Conditions:" % indent)
		for condition in behavior.conditions:
			var condition_name = condition.get_script().get_path().get_file().get_basename()
			print("%s    - %s" % [indent, condition_name])
	
	# Print actions
	if not behavior.actions.is_empty():
		print("%s  Actions:" % indent)
		for action in behavior.actions:
			var action_name = action.get_script().get_path().get_file().get_basename()
			print("%s    - %s" % [indent, action_name])
	
	# Recursively print sub-behaviors
	if not behavior.sub_behaviors.is_empty():
		print("%s  Sub-behaviors:" % indent)
		for sub_behavior in behavior.sub_behaviors:
			_print_behavior_recursive(sub_behavior, depth + 1)
			
## Initialize the BehaviorTree with an ant
static func create(ant: Ant) -> BehaviorTreeBuilder:
	return BehaviorTreeBuilder.new(ant)

## Update the behavior tree
func update(delta: float) -> void:
	if not is_instance_valid(ant):
		push_warning("BehaviorTree: Ant reference is invalid")
		return
		
	if not root_behavior:
		push_warning("BehaviorTree: No root behavior set")
		return
	
	# Gather context for this update cycle
	var context := gather_context()
	
	# Update root behavior
	if root_behavior.state != Behavior.State.ACTIVE:
		root_behavior.start(ant)
	
	root_behavior.update(delta, context)
	
	# Check for active behavior changes
	var current_active = get_active_behavior()
	if current_active != _last_active_behavior:
		_last_active_behavior = current_active
		active_behavior_changed.emit(current_active)
	
	# Clean up after update
	_clear_condition_caches_recursive(root_behavior)
	tree_updated.emit()

## Gather context information for behaviors
func gather_context() -> Dictionary:
	return ContextBuilder.new(ant, behavior_config.condition_configs).build()

## Reset the behavior tree to its initial state
func reset() -> void:
	if root_behavior:
		root_behavior.reset()
	_last_active_behavior = null

## Get the current active behavior
func get_active_behavior() -> Behavior:
	return _get_active_behavior_recursive(root_behavior)

## Clear condition caches recursively
func _clear_condition_caches_recursive(behavior: Behavior) -> void:
	if not behavior:
		return
	
	behavior.clear_condition_cache()
	for sub_behavior in behavior.sub_behaviors:
		_clear_condition_caches_recursive(sub_behavior)

## Recursively get the highest priority active behavior
func _get_active_behavior_recursive(behavior: Behavior) -> Behavior:
	if not behavior:
		return null
	
	if behavior.state == Behavior.State.ACTIVE:
		return behavior
	
	var highest_priority_behavior: Behavior = null
	var highest_priority: int = -1
	
	for sub_behavior in behavior.sub_behaviors:
		var active_sub_behavior = _get_active_behavior_recursive(sub_behavior)
		if active_sub_behavior and active_sub_behavior.priority > highest_priority:
			highest_priority_behavior = active_sub_behavior
			highest_priority = active_sub_behavior.priority
	
	return highest_priority_behavior

## Print the active behavior chain for debugging
func print_active_behavior_chain() -> void:
	var active := get_active_behavior()
	if active:
		var chain: Array[String] = []
		var current := active
		while current:
			chain.append(current.name)
			current = current.current_sub_behavior
		print("Active behavior chain: ", " -> ".join(chain))
