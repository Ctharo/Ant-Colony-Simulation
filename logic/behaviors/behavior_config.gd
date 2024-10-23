class_name BehaviorConfig
extends RefCounted

## Signal emitted when behaviors are loaded
signal behaviors_loaded

## Dictionary of loaded behavior configurations
var behavior_configs: Dictionary = {}

## Dictionary mapping behavior types to their classes
const BEHAVIOR_TYPES = {
	"CollectFood": Behavior.CollectFood,
	"SearchForFood": Behavior.SearchForFood,
	"HarvestFood": Behavior.HarvestFood,
	"ReturnToColony": Behavior.ReturnToColony,
	"StoreFood": Behavior.StoreFood,
	"Rest": Behavior.Rest,
	"FollowHomePheromones": Behavior.FollowHomePheromones,
	"FollowFoodPheromones": Behavior.FollowFoodPheromones,
	"WanderForHome": Behavior.WanderForHome,
	"WanderForFood": Behavior.WanderForFood
}

## Dictionary mapping condition types to their classes
const CONDITION_TYPES = {
	"FoodInView": Condition.FoodInView,
	"CarryingFood": Condition.CarryingFood,
	"AtHome": Condition.AtHome,
	"FoodPheromoneSensed": Condition.FoodPheromoneSensed,
	"HomePheromoneSensed": Condition.HomePheromoneSensed,
	"LowEnergy": Condition.LowEnergy,
	"OverloadedWithFood": Condition.OverloadedWithFood
}

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

## Load behavior configurations from JSON file
func load_from_json(filepath: String) -> Error:
	print("Loading behavior configurations from: ", filepath)
	
	var file := FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		push_error("Failed to open behavior config file: %s" % filepath)
		return FileAccess.get_open_error()
	
	var json := JSON.new()
	var json_string := file.get_as_text()
	var parse_result := json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse behavior config JSON: %s" % json.get_error_message())
		return parse_result
	
	behavior_configs = json.data
	print("Successfully loaded behavior configurations")
	behaviors_loaded.emit()
	return OK

## Create a complete behavior instance with all its components
func create_behavior(behavior_type: String, priority: int, ant: Ant = null) -> Behavior:
	print("Creating behavior: ", behavior_type)
	
	if not behavior_type in behavior_configs:
		push_error("No configuration found for behavior type: %s" % behavior_type)
		return null
	
	if not behavior_type in BEHAVIOR_TYPES:
		push_error("No behavior class found for type: %s" % behavior_type)
		return null
	
	var config = behavior_configs[behavior_type]
	var behavior_class = BEHAVIOR_TYPES[behavior_type]
	
	# Create behavior builder
	var builder = Behavior.BehaviorBuilder.new(behavior_class, priority)
	
	# Add conditions from configuration
	if "conditions" in config:
		_add_conditions_from_config(builder, config["conditions"])
	
	# Add actions from configuration
	if "actions" in config:
		_add_actions_from_config(builder, config["actions"], ant)
	
	# Build the behavior first
	var behavior = builder.build()
	
	# Set name and initialize
	behavior.name = behavior_type
	if ant:
		behavior.ant = ant
	
	# Add sub-behaviors after initial creation
	if "sub_behaviors" in config:
		_add_sub_behaviors_from_config(behavior, config["sub_behaviors"], ant)
	
	return behavior

## Add conditions to the behavior builder from configuration
func _add_conditions_from_config(builder: Behavior.BehaviorBuilder, conditions_config: Array) -> void:
	for condition_data in conditions_config:
		var condition = create_condition(condition_data)
		if condition:
			builder.with_condition(condition)

## Create a condition from configuration data
func create_condition(condition_data: Dictionary) -> Condition:
	# Handle operator conditions (AND, OR, NOT)
	if condition_data.get("type") == "Operator":
		return _create_operator_condition(condition_data)
	
	# Handle regular conditions
	var condition_type = condition_data["type"]
	if not condition_type in CONDITION_TYPES:
		push_error("Unknown condition type: %s" % condition_type)
		return null
	
	var condition_class = CONDITION_TYPES[condition_type]
	var builder = condition_class.create()
	
	# Add parameters if specified
	if "params" in condition_data:
		for param_key in condition_data["params"]:
			builder.with_param(param_key, condition_data["params"][param_key])
	
	return builder.build()

## Create an operator condition (AND, OR, NOT)
func _create_operator_condition(operator_data: Dictionary) -> Condition:
	var operator_type = operator_data["operator_type"]
	var operands: Array[Condition] = []
	
	# Create conditions for all operands
	for operand_data in operator_data["operands"]:
		var operand = create_condition(operand_data)
		if operand:
			operands.append(operand)
	
	# Create the appropriate operator
	match operator_type:
		"and":
			return Operator.and_condition(operands)
		"or":
			return Operator.or_condition(operands)
		"not":
			if operands.size() != 1:
				push_error("NOT operator must have exactly one operand")
				return null
			return Operator.not_condition(operands[0])
		_:
			push_error("Unknown operator type: %s" % operator_type)
			return null

## Add actions to the behavior builder from configuration
func _add_actions_from_config(builder: Behavior.BehaviorBuilder, actions_config: Array, ant: Ant) -> void:
	for action_data in actions_config:
		var action = create_action(action_data, ant)
		if action:
			builder.with_action(action)

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
