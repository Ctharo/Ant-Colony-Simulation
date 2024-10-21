class_name BehaviorTree
extends Node

## The root behavior of the tree
var root_behavior: Behavior

## The ant associated with this behavior tree
var ant: Ant

## Initialize the BehaviorTree
## @param _ant The ant associated with this behavior tree
## @param _root_behavior The root behavior of the tree
func _init(_ant: Ant, _root_behavior: Behavior):
	ant = _ant
	root_behavior = _root_behavior

## Update the behavior tree
## @param delta Time elapsed since the last update
func update(delta: float) -> void:
	var params = _gather_context()
	root_behavior.update(delta, params)

## Gather context information for behaviors
## @return Dictionary containing context information
func _gather_context() -> Dictionary:
	var context = {}
	context["visible_food"] = ant.get_visible_food()
	context["nearby_ants"] = ant.get_nearby_ants()
	context["current_location"] = ant.global_position
	# Add more context information as needed
	return context

## Reset the behavior tree
func reset() -> void:
	root_behavior.reset()

## Add a behavior to the tree
## @param behavior The behavior to add
## @param parent The parent behavior (null for root)
func add_behavior(behavior: Behavior, parent: Behavior = null) -> void:
	if parent == null:
		root_behavior = behavior
	else:
		parent.add_sub_behavior(behavior)

## Remove a behavior from the tree
## @param behavior The behavior to remove
func remove_behavior(behavior: Behavior) -> void:
	if behavior == root_behavior:
		root_behavior = null
	else:
		_remove_behavior_recursive(root_behavior, behavior)

## Recursively remove a behavior from the tree
## @param current The current behavior being checked
## @param to_remove The behavior to remove
## @return True if the behavior was removed, false otherwise
func _remove_behavior_recursive(current: Behavior, to_remove: Behavior) -> bool:
	for i in range(current.sub_behaviors.size()):
		if current.sub_behaviors[i] == to_remove:
			current.sub_behaviors.remove_at(i)
			return true
		elif _remove_behavior_recursive(current.sub_behaviors[i], to_remove):
			return true
	return false

## Get the highest priority active behavior
## @return The highest priority active behavior, or null if none are active
func get_active_behavior() -> Behavior:
	return _get_active_behavior_recursive(root_behavior)

## Recursively get the highest priority active behavior
## @param behavior The current behavior being checked
## @return The highest priority active behavior, or null if none are active
func _get_active_behavior_recursive(behavior: Behavior) -> Behavior:
	if behavior.state == Behavior.BehaviorState.ACTIVE:
		return behavior
	
	var highest_priority_behavior: Behavior = null
	var highest_priority: int = -1
	
	for sub_behavior in behavior.sub_behaviors:
		var active_sub_behavior = _get_active_behavior_recursive(sub_behavior)
		if active_sub_behavior and active_sub_behavior.priority > highest_priority:
			highest_priority_behavior = active_sub_behavior
			highest_priority = active_sub_behavior.priority
	
	return highest_priority_behavior
