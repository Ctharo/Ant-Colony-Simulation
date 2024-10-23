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
			# Ensure the root behavior is properly initialized
			if root_behavior:
				root_behavior.start(ant)

## The ant associated with this behavior tree
var ant: Ant:
	get:
		return ant
	set(value):
		if value != ant:
			ant = value
			# Reinitialize root behavior with new ant if it exists
			if root_behavior:
				root_behavior.start(ant)

## Configuration manager for behaviors
var behavior_config: BehaviorConfig

## Last known active behavior for change detection
var _last_active_behavior: Behavior

## Default configuration file path
const DEFAULT_CONFIG_PATH = "res://behaviors.json"

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
	
	## Configuration path for behaviors
	var config_path: String = DEFAULT_CONFIG_PATH
	
	func _init(_ant: Ant):
		ant = _ant
	
	## Set a custom configuration file path
	func with_config_path(path: String) -> Builder:
		config_path = path
		return self
	
	## Build and return the configured behavior tree
	func build() -> BehaviorTree:
		var tree := BehaviorTree.new()
		tree.ant = ant
		
		# Load behavior configuration
		tree.behavior_config = BehaviorConfig.new(ant)
		var load_result = tree.behavior_config.load_from_json(config_path)
		if load_result != OK:
			push_error("Failed to load behavior config from: %s" % config_path)
			return tree
		
		# Create root behavior (CollectFood is the main behavior)
		var collect_food = tree.behavior_config.create_behavior(
			"CollectFood", 
			Behavior.Priority.MEDIUM
		)
			
		# Add Rest behavior as a high-priority alternative
		var rest_behavior = tree.behavior_config.create_behavior(
			"Rest",
			Behavior.Priority.CRITICAL
		)
		
		# Create composite root using BehaviorBuilder
		var composite_builder = Behavior.BehaviorBuilder.new(Behavior, Behavior.Priority.MEDIUM)
		composite_builder\
			.with_sub_behavior(rest_behavior)\
			.with_sub_behavior(collect_food)
			
		# Build and assign the composite root
		tree.root_behavior = composite_builder.build()
		tree.root_behavior.name = "CompositeRoot"  # Give it a proper name
		
		return tree

## Initialize the BehaviorTree with an ant
static func create(_ant: Ant) -> Builder:
	return Builder.new(_ant)

## Update the behavior tree
func update(delta: float) -> void:
	if not is_instance_valid(ant) or not root_behavior:
		push_warning("BehaviorTree: Ant or root behavior not set")
		return
		
	var params := gather_context()
	print("\n--- Behavior Tree Update ---")
	print("Root behavior: ", root_behavior.name)
	print("Sub-behaviors: ", root_behavior.sub_behaviors.map(func(b): return b.name))
	root_behavior.update(delta, params)
	
	# Update root behavior and track state changes
	if root_behavior.state != Behavior.State.ACTIVE:
		root_behavior.start(ant)
		
	if not root_behavior.update(delta, params):
		print("behavior is finished or inactive, should change?")
	
	# Check for active behavior changes
	var current_active: Behavior = get_active_behavior()
	print("Current active behavior: ", current_active.name if current_active else "None")
	if current_active != _last_active_behavior:
		if current_active:
			print("Active behavior changed to: ", current_active.name)
		else:
			print("No active behavior")
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
		var active_sub_behavior: Behavior = _get_active_behavior_recursive(sub_behavior)
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
		"config_path": behavior_config.get_path() if behavior_config else DEFAULT_CONFIG_PATH,
		"root_behavior": root_behavior.to_dict() if root_behavior else null
	}

## Create a behavior tree from a dictionary
static func from_dict(data: Dictionary, _ant: Ant) -> BehaviorTree:
	return create(_ant)\
		.with_config_path(data.get("config_path", DEFAULT_CONFIG_PATH))\
		.build()
