class_name BehaviorConfig
extends RefCounted

## Signal emitted when behaviors are loaded
signal behaviors_loaded

## Dictionary of loaded behavior configurations
var behavior_configs: Dictionary = {}

var ant: Ant

func _init(_ant: Ant):
	ant = _ant

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

## Dictionary mapping operator types to their creation methods
const OPERATOR_TYPES = {
	"and": "and_condition",
	"or": "or_condition",
	"not": "not_condition"
}

## Load behavior configurations from JSON file
func load_from_json(filepath: String) -> Error:
	print("Attempting to load behaviors from: ", filepath)
	var file := FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		push_error("Failed to open behavior config file: %s" % filepath)
		return FileAccess.get_open_error()
	
	var json := JSON.new()
	var json_string := file.get_as_text()
	print("Loaded JSON content: %s" % json_string.substr(0, 100)) # Print first 100 chars
	var parse_result := json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse behavior config JSON: %s" % json.get_error_message())
		return parse_result
	
	behavior_configs = json.data
	print("Successfully loaded behavior types: ", behavior_configs.keys())
	behaviors_loaded.emit()
	return OK

## Create a behavior from its configuration
func create_behavior(behavior_type: String, priority: int) -> Behavior:
	print("Creating behavior type: %s" % behavior_type)
	print("Available configs: %s" % behavior_configs.keys())
	print("Available behavior types: %s" % BEHAVIOR_TYPES.keys())
	
	if not behavior_type in behavior_configs:
		push_error("Unknown behavior type: %s" % behavior_type)
		return null
	
	if not behavior_type in BEHAVIOR_TYPES:
		push_error("No behavior class found for type: %s" % behavior_type)
		return null
	
	var config = behavior_configs[behavior_type]
	print("Config found for: ", behavior_type)
	if "conditions" in config:
		print("Number of conditions: ", config["conditions"].size())
	if "actions" in config:
		print("Number of actions: ", config["actions"].size())
	if "sub_behaviors" in config:
		print("Number of sub_behaviors: ", config["sub_behaviors"].size())

	var behavior_class = BEHAVIOR_TYPES[behavior_type]
	var builder = Behavior.BehaviorBuilder.new(behavior_class, priority)
	
	# Add conditions
	if "conditions" in config:
		print("Adding %d conditions for %s" % [config["conditions"].size(), behavior_type])
		for condition_data in config["conditions"]:
			print("Creating condition: ", condition_data.get("type", "unknown type"))
			var condition = _create_condition(condition_data)
			if condition:
				builder.with_condition(condition)
			else:
				print("Failed to create condition")
	
	# Add actions
	if "actions" in config:
		for action_data in config["actions"]:
			var action = _create_action(action_data)
			if action:
				builder.with_action(action)
	
	# Add sub-behaviors
	if "sub_behaviors" in config:
		for sub_behavior_data in config["sub_behaviors"]:
			var sub_behavior = create_behavior(
				sub_behavior_data["type"],
				sub_behavior_data.get("priority", Behavior.Priority.MEDIUM)
			)
			if sub_behavior:
				builder.with_sub_behavior(sub_behavior)
	
	# Add actions and sub-behaviors tracking
	var final_behavior = builder.build()
	print("Created behavior: ", behavior_type, " with ", final_behavior.conditions.size(), " conditions")
	return final_behavior

## Create a condition from configuration data
func _create_condition(condition_data: Dictionary) -> Condition:
	# Handle operators
	if condition_data.get("type") == "Operator":
		return _create_operator_condition(condition_data)
	
	# Handle regular conditions
	var condition_type = condition_data["type"]
	if not condition_type in CONDITION_TYPES:
		push_error("Unknown condition type: %s" % condition_type)
		return null
	
	var condition_class = CONDITION_TYPES[condition_type]
	var builder = condition_class.create()
	
	# Add parameters
	if "params" in condition_data:
		for param_key in condition_data["params"]:
			builder.with_param(param_key, condition_data["params"][param_key])
	
	return builder.build()

## Create an operator condition from configuration data
func _create_operator_condition(operator_data: Dictionary) -> Condition:
	var operator_type = operator_data["operator_type"]
	if not operator_type in OPERATOR_TYPES:
		push_error("Unknown operator type: %s" % operator_type)
		return null
	
	# Create conditions for all operands
	var operand_conditions: Array[Condition] = []
	for operand_data in operator_data["operands"]:
		var operand = _create_condition(operand_data)
		if operand:
			operand_conditions.append(operand)
	
	# Special handling for NOT operator
	if operator_type == "not":
		if operand_conditions.size() != 1:
			push_error("NOT operator must have exactly one operand")
			return null
		return Operator.not_condition(operand_conditions[0])
	
	# Handle AND and OR operators
	var operator_method = OPERATOR_TYPES[operator_type]
	return Operator.new().callv(operator_method, [operand_conditions])

## Create an action from configuration data
func _create_action(action_data: Dictionary) -> Action:
	var action_type = action_data["type"]
	if not action_type in ACTION_TYPES:
		push_error("Unknown action type: %s" % action_type)
		return null
	
	var action_class = ACTION_TYPES[action_type]
	var builder = action_class.create()
	
	# Add parameters
	if "params" in action_data:
		for param_key in action_data["params"]:
			builder.with_param(param_key, action_data["params"][param_key])
	
	# Set cooldown if specified
	if "cooldown" in action_data:
		builder.with_cooldown(action_data["cooldown"])
	
	return builder.build()

## Save behavior configurations to JSON file
func save_to_json(filepath: String) -> Error:
	var file := FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open file for writing: %s" % filepath)
		return FileAccess.get_open_error()
	
	var json_string := JSON.stringify(behavior_configs, "\t")
	file.store_string(json_string)
	return OK

## Example usage function showing how to create a JSON config
static func create_example_config() -> Dictionary:
	return {
		"CollectFood": {
			"conditions": [
				{
					"type": "Operator",
					"operator_type": "not",
					"operands": [
						{
							"type": "LowEnergy",
							"params": {
								"threshold": 20.0
							}
						}
					]
				}
			],
			"sub_behaviors": [
				{
					"type": "SearchForFood",
					"priority": 50
				},
				{
					"type": "HarvestFood",
					"priority": 75
				},
				{
					"type": "ReturnToColony",
					"priority": 100
				}
			]
		}
	}
