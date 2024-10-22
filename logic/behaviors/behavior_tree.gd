class_name BehaviorTree
extends Node

## The root behavior of the tree
var root_behavior: Behavior

## The ant associated with this behavior tree
var ant: Ant

## Context builder for gathering ant state and environment information
class ContextBuilder:
	var ant: Ant
	var context: Dictionary = {}
	
	func _init(_ant: Ant):
		ant = _ant
	
	func with_ant_properties() -> ContextBuilder:
		context["current_position"] = ant.global_position
		context["current_energy"] = ant.energy.current_level
		context["max_energy"] = ant.energy.max_level
		context["carried_food_mass"] = ant.foods.mass()
		context["max_carry_capacity"] = ant.strength.carry_max()
		return self
	
	func with_environment_info() -> ContextBuilder:
		context["visible_food"] = ant.food_in_view()
		context["food_in_reach"] = ant.food_in_reach()
		context["ants_in_view"] = ant.ants_in_view()
		context["food_pheromones"] = ant.pheromones_sensed("food")
		context["home_pheromones"] = ant.pheromones_sensed("home")
		context["distance_to_home"] = ant.global_position.distance_to(ant.colony.global_position)
		return self
	
	func with_thresholds() -> ContextBuilder:
		context["home_threshold"] = 10.0
		context["low_energy_threshold"] = 30.0
		context["overload_threshold"] = 0.9
		return self
	
	func build() -> Dictionary:
		return context

## Builder for constructing the behavior tree
class Builder:
	var ant: Ant
	var root_behavior: Behavior
	
	func _init(_ant: Ant):
		ant = _ant
	
	func with_root_behavior(behavior: Behavior) -> Builder:
		root_behavior = behavior
		return self
	
	func build() -> BehaviorTree:
		var tree = BehaviorTree.new()
		tree.ant = ant
		tree.root_behavior = root_behavior
		return tree

## Initialize the BehaviorTree
static func create(ant: Ant) -> Builder:
	return Builder.new(ant)

## Update the behavior tree
func _process(delta: float) -> void:
	if not ant or not root_behavior:
		push_warning("BehaviorTree: Ant or root behavior not set")
		return
		
	var params = gather_context()
	root_behavior.update(delta, params)
	
	# Clear condition caches after update
	_clear_condition_caches_recursive(root_behavior)

## Gather context information for behaviors
func gather_context() -> Dictionary:
	return ContextBuilder.new(ant)\
		.with_ant_properties()\
		.with_environment_info()\
		.with_thresholds()\
		.build()

## Reset the behavior tree
func reset() -> void:
	if root_behavior:
		root_behavior.reset()

## Get the current active behavior (for debugging)
func get_active_behavior() -> Behavior:
	return _get_active_behavior_recursive(root_behavior)

## Clear condition caches recursively after each update
func _clear_condition_caches_recursive(behavior: Behavior) -> void:
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

## Debug utilities
func print_active_behavior_chain() -> void:
	var active = get_active_behavior()
	if active:
		var chain = []
		var current = active
		while current:
			chain.append(current.name)
			current = current.current_sub_behavior
		print("Active behavior chain: ", " -> ".join(chain))

## Get a string representation of the behavior tree
func _get_tree_string() -> String:
	return _get_tree_string_recursive(root_behavior)

## Recursively build a string representation of the behavior tree
func _get_tree_string_recursive(behavior: Behavior, depth: int = 0) -> String:
	if not behavior:
		return ""
	
	var indent = "  ".repeat(depth)
	var result = "%s%s (Priority: %d, State: %s)\n" % [
		indent,
		behavior.name,
		behavior.priority,
		Behavior.State.keys()[behavior.state]
	]
	
	for sub_behavior in behavior.sub_behaviors:
		result += _get_tree_string_recursive(sub_behavior, depth + 1)
	
	return result
