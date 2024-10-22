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
		root_behavior = value

## The ant associated with this behavior tree
var ant: Ant:
	get:
		return ant
	set(value):
		ant = value

## Last known active behavior for change detection
var _last_active_behavior: Behavior

## Context builder for gathering ant state and environment information
class ContextBuilder:
	## The ant whose context is being built
	var ant: Ant
	
	## The context dictionary being built
	var context: Dictionary = {}
	
	func _init(_ant: Ant):
		ant = _ant
	
	## Add ant properties to the context
	func with_ant_properties() -> ContextBuilder:
		if not is_instance_valid(ant):
			push_error("ContextBuilder: Invalid ant reference")
			return self
			
		context["current_position"] = ant.global_position
		context["current_energy"] = ant.energy.current_level
		context["max_energy"] = ant.energy.max_level
		context["carried_food_mass"] = ant.foods.mass()
		context["max_carry_capacity"] = ant.strength.carry_max()
		return self
	
	## Add environment information to the context
	func with_environment_info() -> ContextBuilder:
		if not is_instance_valid(ant):
			push_error("ContextBuilder: Invalid ant reference")
			return self
			
		context["visible_food"] = ant.food_in_view()
		context["food_in_reach"] = ant.food_in_reach()
		context["ants_in_view"] = ant.ants_in_view()
		context["food_pheromones"] = ant.pheromones_sensed("food")
		context["home_pheromones"] = ant.pheromones_sensed("home")
		context["distance_to_home"] = ant.global_position.distance_to(ant.colony.global_position)
		return self
	
	## Add threshold values to the context
	func with_thresholds() -> ContextBuilder:
		context["home_threshold"] = 10.0
		context["low_energy_threshold"] = 30.0
		context["overload_threshold"] = 0.9
		return self
	
	## Build and return the final context dictionary
	func build() -> Dictionary:
		return context

## Builder for constructing the behavior tree
class Builder:
	## The ant for this behavior tree
	var ant: Ant
	
	## The root behavior for this tree
	var root_behavior: Behavior
	
	func _init(_ant: Ant):
		ant = _ant
	
	## Set the root behavior for the tree
	func with_root_behavior(behavior: Behavior) -> Builder:
		root_behavior = behavior
		return self
	
	## Build and return the configured behavior tree
	func build() -> BehaviorTree:
		var tree := BehaviorTree.new()
		tree.ant = ant
		tree.root_behavior = root_behavior
		return tree

## Initialize the BehaviorTree with an ant
static func create(ant: Ant) -> Builder:
	return Builder.new(ant)

## Update the behavior tree
func _process(delta: float) -> void:
	if not is_instance_valid(ant) or not root_behavior:
		push_warning("BehaviorTree: Ant or root behavior not set")
		return
		
	var params := gather_context()
	root_behavior.update(delta, params)
	
	# Check for active behavior changes
	var current_active := get_active_behavior()
	if current_active != _last_active_behavior:
		_last_active_behavior = current_active
		active_behavior_changed.emit(current_active)
	
	# Clear condition caches after update
	_clear_condition_caches_recursive(root_behavior)
	
	tree_updated.emit()

## Gather context information for behaviors
func gather_context() -> Dictionary:
	return ContextBuilder.new(ant)\
		.with_ant_properties()\
		.with_environment_info()\
		.with_thresholds()\
		.build()

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
		var active_sub_behavior := _get_active_behavior_recursive(sub_behavior)
		if active_sub_behavior and active_sub_behavior.priority > highest_priority:
			highest_priority_behavior = active_sub_behavior
			highest_priority = active_sub_behavior.priority
	
	return highest_priority_behavior

## Debug utilities
func print_active_behavior_chain() -> void:
	var active := get_active_behavior()
	if active:
		var chain: Array[String] = []
		var current := active
		while current:
			chain.append(current.name)
			current = current.current_sub_behavior
		print("Active behavior chain: ", " -> ".join(chain))

## Serialize the behavior tree to a dictionary
func to_dict() -> Dictionary:
	return {
		"root_behavior": root_behavior.to_dict() if root_behavior else null
	}

## Create a behavior tree from a dictionary
static func from_dict(data: Dictionary, ant: Ant) -> BehaviorTree:
	var tree := BehaviorTree.new()
	tree.ant = ant
	
	if data.has("root_behavior") and data["root_behavior"] != null:
		tree.root_behavior = Behavior.from_dict(data["root_behavior"])
	
	return tree

## Save behavior tree to a JSON file
static func save_to_json(tree: BehaviorTree, filepath: String) -> Error:
	if not tree:
		return ERR_INVALID_PARAMETER
		
	var file := FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	
	var json := JSON.new()
	var data := tree.to_dict()
	var json_string := json.stringify(data, "\t")
	
	file.store_string(json_string)
	return OK

## Load behavior tree from a JSON file
static func load_from_json(filepath: String, ant: Ant) -> BehaviorTree:
	var file := FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		push_error("Failed to open file: %s" % filepath)
		return null
	
	var json := JSON.new()
	var json_string := file.get_as_text()
	var parse_result := json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse JSON: %s" % json.get_error_message())
		return null
	
	return BehaviorTree.from_dict(json.data, ant)
