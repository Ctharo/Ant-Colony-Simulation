class_name BehaviorTreeBuilder
extends RefCounted

## Builder class for constructing the behavior tree

## The ant for this behavior tree
var ant: Ant

## Default conditions configuration file path
const DEFAULT_CONDITIONS_PATH = "res://conditions.json"

var conditions_path: String = DEFAULT_CONDITIONS_PATH

## Default behaviors configuration file path
const DEFAULT_BEHAVIORS_PATH = "res://behaviors.json"

var behaviors_path: String = DEFAULT_BEHAVIORS_PATH

## Root behavior type to create
var root_behavior_type: String = "Root"

## Priority for root behavior
var root_priority: int = Behavior.Priority.MEDIUM

## Additional behavior types to force-load (optional)
var required_behaviors: Array[String] = []

func _init(_ant: Ant):
	ant = _ant

## Set the root behavior type
func with_root_behavior(type: String, priority: int = Behavior.Priority.MEDIUM) -> BehaviorTreeBuilder:
	root_behavior_type = type
	root_priority = priority
	return self

## Add required behavior types to ensure they're loaded
func with_required_behaviors(behavior_types: Array[String]) -> BehaviorTreeBuilder:
	required_behaviors = behavior_types
	return self

## Build and return the configured behavior tree
func build() -> BehaviorTree:
	# Create tree instance
	var tree := BehaviorTree.new()
	tree.ant = ant
	
	# Initialize behavior configuration
	tree.behavior_config = BehaviorConfig.new()
	var load_result = tree.behavior_config.load_configs(behaviors_path, conditions_path)
	if load_result != OK:
		push_error("Failed to load configs from: %s and/or %s" % [behaviors_path, conditions_path])
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
