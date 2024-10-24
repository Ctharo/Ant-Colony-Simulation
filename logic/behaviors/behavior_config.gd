class_name BehaviorConfig
extends RefCounted

## Signal emitted when behaviors are loaded
signal behaviors_loaded

## Dictionary of loaded behavior and condition configurations
var behavior_configs: Dictionary = {}
var condition_configs: Dictionary = {}

## Dictionary mapping action types to their classes
const ACTION_TYPES = {
	"Move": Action.Move,
	"Harvest": Action.Harvest,
	"FollowPheromone": Action.FollowPheromone,
	"RandomMove": Action.RandomMove,
	"Store": Action.Store,
	"Attack": Action.Attack,
	"MoveToFood": Action.MoveToFood,
	"EmitPheromone": Action.EmitPheromone,
	"Rest": Action.Rest
}

## Load behavior and condition configurations from JSON files
func load_configs(behaviors_path: String, conditions_path: String) -> Error:
	# Load conditions first
	var conditions_file := FileAccess.open(conditions_path, FileAccess.READ)
	if not conditions_file:
		push_error("Failed to open conditions config file: %s" % conditions_path)
		return ERR_FILE_NOT_FOUND
	
	var json := JSON.new()
	var result := json.parse(conditions_file.get_as_text())
	if result != OK:
		push_error("Failed to parse conditions JSON: %s" % json.get_error_message())
		return result
	
	condition_configs = json.data.conditions
	
	# Load behaviors
	var behaviors_file := FileAccess.open(behaviors_path, FileAccess.READ)
	if not behaviors_file:
		push_error("Failed to open behaviors config file: %s" % behaviors_path)
		return ERR_FILE_NOT_FOUND
	
	result = json.parse(behaviors_file.get_as_text())
	if result != OK:
		push_error("Failed to parse behaviors JSON: %s" % json.get_error_message())
		return result
	
	behavior_configs = json.data.behaviors
	behaviors_loaded.emit()
	return OK

## Create a complete behavior instance with all its components
func create_behavior(behavior_type: String, priority: int, ant: Ant = null) -> Behavior:
	print("Creating behavior: ", behavior_type)
	
	if not behavior_type in behavior_configs:
		push_error("No configuration found for behavior type: %s" % behavior_type)
		return null
	
	var config = behavior_configs[behavior_type]
	var behavior = Behavior.new(priority)
	
	# Set basic properties
	behavior.name = behavior_type
	behavior.ant = ant
	
	# Add conditions from configuration
	if "conditions" in config:
		_add_conditions_from_config(behavior, config.conditions)
	
	# Add actions from configuration
	if "actions" in config:
		_add_actions_from_config(behavior, config.actions, ant)
	
	# Add sub-behaviors after initial creation
	if "sub_behaviors" in config:
		_add_sub_behaviors_from_config(behavior, config.sub_behaviors, ant)
	
	return behavior

## Add conditions to the behavior from configuration
func _add_conditions_from_config(behavior: Behavior, conditions_config: Array) -> void:
	for condition_data in conditions_config:
		var condition_config = _resolve_condition_config(condition_data)
		if condition_config:
			behavior.add_condition_config(condition_config)

## Resolve condition configuration from various formats
func _resolve_condition_config(condition_data: Variant) -> Dictionary:
	# Handle string condition names (reference to predefined conditions)
	if condition_data is String:
		if not condition_data in condition_configs:
			push_error("Unknown condition: %s" % condition_data)
			return {}
		return condition_configs[condition_data]
	
	# Handle direct condition objects
	if condition_data is Dictionary:
		if condition_data.get("type") == "Operator":
			match condition_data.operator_type.to_upper():
				"AND":
					var subconds = []
					for subcond in condition_data.operands:
						subconds.append(_resolve_condition_config(subcond))
					return Operator.and_condition(subconds)
				"OR":
					var subconds = []
					for subcond in condition_data.operands:
						subconds.append(_resolve_condition_config(subcond))
					return Operator.or_condition(subconds)
				"NOT":
					var subcond = _resolve_condition_config(condition_data.operands[0])
					return Operator.not_condition(subcond)
		return condition_data
	
	push_error("Invalid condition data: %s" % condition_data)
	return {}

## Add actions to the behavior from configuration
func _add_actions_from_config(behavior: Behavior, actions_config: Array, ant: Ant) -> void:
	for action_data in actions_config:
		var action = create_action(action_data, ant)
		if action:
			behavior.actions.append(action)

## Create an action from configuration data
func create_action(action_data: Dictionary, ant: Ant) -> Action:
	var action_type = action_data["type"]
	if not action_type in ACTION_TYPES:
		push_error("Unknown action type: %s" % action_type)
		return null
	
	var action_class = ACTION_TYPES[action_type]
	var builder = action_class.create()
	
	# Add parameters if specified
	if "params" in action_data:
		for param_key in action_data["params"]:
			builder.with_param(param_key, action_data["params"][param_key])
	
	# Set cooldown if specified
	if "cooldown" in action_data:
		builder.with_cooldown(action_data["cooldown"])
	
	var action = builder.build()
	action.ant = ant
	return action

## Add sub-behaviors to the behavior from configuration
func _add_sub_behaviors_from_config(parent_behavior: Behavior, sub_behaviors_config: Array, ant: Ant) -> void:
	for sub_behavior_data in sub_behaviors_config:
		var sub_behavior = create_behavior(
			sub_behavior_data["type"],
			sub_behavior_data.get("priority", Behavior.Priority.MEDIUM),
			ant
		)
		if sub_behavior:
			parent_behavior.add_sub_behavior(sub_behavior)
			print("Added sub-behavior %s to %s" % [sub_behavior.name, parent_behavior.name])
