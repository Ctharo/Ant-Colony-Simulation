class_name AntConfigManager
extends Node

## File path for storing behaviors
const BEHAVIORS_FILE = "user://behaviors.json"
const DEFAULT_BEHAVIORS_FILE = "res://default_behaviors.json"

## Registry for condition checks
var condition_registry: Dictionary = {}

## Registry for action creators
var action_registry: Dictionary = {}

### Initialize the AntConfigManager
#func _init():
	#_register_default_conditions()
	#_register_default_actions()
#
### Register default condition checks
#func _register_default_conditions() -> void:
	#register_condition("is_carrying_food", func(ant: Ant) -> bool: return ant.is_carrying_food())
	#register_condition("energy_above", func(ant: Ant, value: float) -> bool: return ant.energy.current_level > value)
	#register_condition("energy_below", func(ant: Ant, value: float) -> bool: return ant.energy.current_level < value)
	#register_condition("food_in_view", func(ant: Ant) -> bool: return not ant.food_in_view().is_empty())
	#register_condition("food_pheromone_nearby", func(ant: Ant) -> bool: return ant.food_pheromone_nearby())
#
### Register default action creators
#func _register_default_actions() -> void:
	#register_action("move", func(data: Dictionary) -> AntAction: return AntAction.MoveAction.new(data["target"]))
	#register_action("harvest", func(data: Dictionary) -> AntAction: return AntAction.HarvestAction.new(data["target"]))
	#register_action("store", func(data: Dictionary) -> AntAction: return AntAction.StoreAction.new(data["target"]))
	#register_action("attack", func(data: Dictionary) -> AntAction: return AntAction.AttackAction.new(data["target"]))

## Register a new condition check
## name: The name of the condition to register
## check: The callable function that performs the condition check
func register_condition(name: String, check: Callable) -> void:
	if name in condition_registry:
		push_warning("Overwriting existing condition: %s" % name)
	condition_registry[name] = check

## Register a new action creator
## name: The name of the action to register
## creator: The callable function that creates the action
func register_action(name: String, creator: Callable) -> void:
	if name in action_registry:
		push_warning("Overwriting existing action: %s" % name)
	action_registry[name] = creator

## Save behaviors to a JSON file
## behaviors: Array of behavior data to save
func save_behaviors(behaviors: Array) -> void:
	var file = FileAccess.open(BEHAVIORS_FILE, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify({"behaviors": behaviors}, "", false)
		file.store_string(json_string)
		file.close()
	else:
		push_error("Failed to save behaviors file. Error code: %s" % FileAccess.get_open_error())

## Load behaviors from a JSON file
## Returns: Array of behavior data
func load_behaviors() -> Array:
	var behaviors: Array = []
	
	# Try to load from user file
	if FileAccess.file_exists(BEHAVIORS_FILE):
		var file = FileAccess.open(BEHAVIORS_FILE, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			var json = JSON.parse_string(json_string)
			if json and "behaviors" in json:
				behaviors = json["behaviors"]
			else:
				push_error("Failed to parse user behaviors file. Invalid JSON format.")
		else:
			push_error("Failed to open user behaviors file. Error code: %s" % FileAccess.get_open_error())
	
	# If user file doesn't exist or is empty, load default behaviors
	if behaviors.is_empty():
		print("User behaviors file not found or empty. Loading default behaviors.")
		var default_file = FileAccess.open(DEFAULT_BEHAVIORS_FILE, FileAccess.READ)
		if default_file:
			var json_string = default_file.get_as_text()
			default_file.close()
			var json = JSON.parse_string(json_string)
			if json and "behaviors" in json:
				behaviors = json["behaviors"]
				# Save the default behaviors to the user file
				save_behaviors(behaviors)
			else:
				push_error("Failed to parse default behaviors file. Invalid JSON format.")
		else:
			push_error("Failed to open default behaviors file. Error code: %s" % FileAccess.get_open_error())
	
	return behaviors

## Create an AntBehavior object from behavior data
## behavior_data: Dictionary containing behavior configuration
## Returns: AntBehavior object
func create_behavior(behavior_data: Dictionary) -> AntBehavior:
	if not "name" in behavior_data or not "id" in behavior_data:
		push_error("Invalid behavior data: missing name or id")
		return null
	
	var behavior = AntBehavior.new()
	behavior.name = behavior_data["name"]
	behavior.id = behavior_data["id"]
	
	# Create and add conditions
	if "conditions" in behavior_data:
		for condition_data in behavior_data["conditions"]:
			var condition = create_condition(condition_data)
			if condition:
				behavior.add_condition(condition)
			else:
				push_warning("Failed to create condition for behavior: %s" % behavior.name)
	
	# Create and add actions
	if "actions" in behavior_data:
		for action_data in behavior_data["actions"]:
			var action = create_action(action_data)
			if action:
				behavior.add_action(action)
			else:
				push_warning("Failed to create action for behavior: %s" % behavior.name)
	
	return behavior

## Create a Condition object from condition data
## condition_data: Dictionary containing condition configuration
## Returns: Condition object or null if invalid
func create_condition(condition_data: Dictionary) -> Condition:
	if "check" in condition_data:
		return create_leaf_condition(condition_data["check"])
	elif "and" in condition_data:
		var and_condition = Condition.AndCondition.new()
		for sub_condition in condition_data["and"]:
			var condition = create_condition(sub_condition)
			if condition:
				and_condition.add_condition(condition)
			else:
				push_warning("Failed to create sub-condition for AND condition")
		return and_condition
	elif "or" in condition_data:
		var or_condition = Condition.OrCondition.new()
		for sub_condition in condition_data["or"]:
			var condition = create_condition(sub_condition)
			if condition:
				or_condition.add_condition(condition)
			else:
				push_warning("Failed to create sub-condition for OR condition")
		return or_condition
	elif "not" in condition_data:
		var sub_condition = create_condition(condition_data["not"])
		if sub_condition:
			return Condition.NotCondition.new(sub_condition)
		else:
			push_warning("Failed to create sub-condition for NOT condition")
			return null
	else:
		push_error("Invalid condition format: %s" % condition_data)
		return null

## Create a LeafCondition from a condition string
## condition_string: String representation of the condition
## Returns: LeafCondition object or null if invalid
func create_leaf_condition(condition_string: String) -> Condition.LeafCondition:
	var parts = condition_string.split(" ")
	if parts.is_empty():
		push_error("Invalid condition string: empty")
		return null
	
	var condition_name = parts[0]
	var args = parts.slice(1)
	
	if condition_name in condition_registry:
		var check = condition_registry[condition_name]
		return Condition.LeafCondition.new(func(ant: Ant) -> bool:
			return check.callv([ant] + args), condition_string)
	else:
		push_error("Unknown condition: %s" % condition_name)
		return null

## Create an AntAction object from action data
## action_data: Dictionary containing action configuration
## Returns: AntAction object or null if invalid
func create_action(action_data: Dictionary) -> AntAction:
	if not "type" in action_data:
		push_error("Invalid action data: missing type")
		return null
	
	var action_type = action_data["type"]
	if action_type in action_registry:
		return action_registry[action_type].call(action_data)
	else:
		push_error("Unknown action type: %s" % action_type)
		return null

## Get all behaviors from the loaded data
## Returns: Array of AntBehavior objects
func get_all_behaviors() -> Array[AntBehavior]:
	var behaviors_data = load_behaviors()
	var behaviors: Array[AntBehavior] = []
	for behavior_data in behaviors_data:
		var behavior = create_behavior(behavior_data)
		if behavior:
			behaviors.append(behavior)
		else:
			push_warning("Failed to create behavior from data: %s" % behavior_data)
	return behaviors
