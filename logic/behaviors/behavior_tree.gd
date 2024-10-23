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

## Default configuration file path
const DEFAULT_CONFIG_PATH = "res://behaviors.json"

## Builder class for constructing the behavior tree
class Builder:
	## The ant for this behavior tree
	var ant: Ant
	
	## Configuration path for behaviors
	var config_path: String = DEFAULT_CONFIG_PATH
	
	## Root behavior type to create
	var root_behavior_type: String = "Root"
	
	## Priority for root behavior
	var root_priority: int = Behavior.Priority.MEDIUM
	
	## Additional behavior types to force-load (optional)
	var required_behaviors: Array[String] = []
	
	func _init(_ant: Ant):
		ant = _ant
	
	## Set a custom configuration file path
	func with_config_path(path: String) -> Builder:
		config_path = path
		return self
	
	## Set the root behavior type
	func with_root_behavior(type: String, priority: int = Behavior.Priority.MEDIUM) -> Builder:
		root_behavior_type = type
		root_priority = priority
		return self
	
	## Add required behavior types to ensure they're loaded
	func with_required_behaviors(behavior_types: Array[String]) -> Builder:
		required_behaviors = behavior_types
		return self
	
	## Build and return the configured behavior tree
	func build() -> BehaviorTree:
		# Create tree instance
		var tree := BehaviorTree.new()
		tree.ant = ant
		
		# Initialize behavior configuration
		tree.behavior_config = BehaviorConfig.new()
		var load_result = tree.behavior_config.load_from_json(config_path)
		if load_result != OK:
			push_error("Failed to load behavior config from: %s" % config_path)
			return tree
		
		# Create root behavior
		var root = tree.behavior_config.create_behavior(root_behavior_type, root_priority, ant)
		if not root:
			push_error("Failed to create root behavior of type: %s" % root_behavior_type)
			return tree
		
		root.name = root_behavior_type  # Ensure root is named
		tree.root_behavior = root
		
		print("Successfully built behavior tree:")
		tree.print_behavior_hierarchy()
		return tree
	
	## Validate that all required behaviors are configured
	func _validate_behaviors(config: BehaviorConfig) -> bool:
		# Check root behavior
		if not root_behavior_type in config.behavior_configs:
			push_error("Root behavior type '%s' not found in configuration" % root_behavior_type)
			return false
			
		# Check required behaviors
		for behavior_type in required_behaviors:
			if not behavior_type in config.behavior_configs:
				push_error("Required behavior type '%s' not found in configuration" % behavior_type)
				return false
				
		# Validate sub-behaviors recursively
		return _validate_sub_behaviors(config, root_behavior_type, [])
	
	## Recursively validate sub-behaviors
	func _validate_sub_behaviors(config: BehaviorConfig, behavior_type: String, 
							   visited: Array) -> bool:
		# Prevent infinite recursion
		if behavior_type in visited:
			return true
		visited.append(behavior_type)
		
		var behavior_config = config.behavior_configs.get(behavior_type)
		if not behavior_config:
			return false
			
		# Check sub-behaviors
		if "sub_behaviors" in behavior_config:
			for sub_behavior in behavior_config["sub_behaviors"]:
				var sub_type = sub_behavior["type"]
				if not sub_type in config.behavior_configs:
					push_error("Sub-behavior type '%s' not found in configuration" % sub_type)
					return false
				if not _validate_sub_behaviors(config, sub_type, visited):
					return false
					
		return true
	
	## Verify the created behavior hierarchy
	func _verify_behavior_hierarchy(behavior: Behavior) -> bool:
		if not behavior:
			return false
			
		# Check that behavior has proper references
		if not behavior.ant:
			push_error("Behavior '%s' missing ant reference" % behavior.name)
			return false
			
		# Verify sub-behaviors recursively
		for sub_behavior in behavior.sub_behaviors:
			if not _verify_behavior_hierarchy(sub_behavior):
				return false
				
		return true

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
static func create(ant: Ant) -> Builder:
	return Builder.new(ant)

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

## Context builder for gathering ant state and environment information
class ContextBuilder:
	var ant: Ant
	var context: Dictionary = {}
	
	func _init(_ant: Ant):
		ant = _ant
	
	## Add ant properties to context
	func with_ant_properties() -> ContextBuilder:
		if not is_instance_valid(ant):
			push_error("ContextBuilder: Invalid ant reference")
			return self
		
		context["current_energy"] = ant.energy.current_level
		context["max_energy"] = ant.energy.max_level
		context["carried_food_mass"] = ant.foods.mass()
		context["max_carry_capacity"] = ant.strength.carry_max()
		return self
	
	## Add environment information to context
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
	
	## Add threshold values to context
	func with_thresholds() -> ContextBuilder:
		context["home_threshold"] = 10.0
		context["low_energy_threshold"] = 30.0
		context["overload_threshold"] = 0.9
		return self
	
	## Build and return the context dictionary
	func build() -> Dictionary:
		return context

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
