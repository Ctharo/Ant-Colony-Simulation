extends Node

class_name AntBehaviorManager

var data_manager: DataManager
var rule_manager: RuleManager

func _ready():
	data_manager = DataManager
	rule_manager = RuleManager

func evaluate_ant_behavior(ant_id: String, colony_name: String, ant_profile_id: String) -> void:
	var ant_profile = data_manager.get_ant_profile(ant_profile_id)
	var behavior_logic = ant_profile["behavior_logic"]
	
	for rule in behavior_logic:
		if evaluate_condition(ant_id, colony_name, rule):
			execute_action(ant_id, colony_name, rule["action"])

func evaluate_condition(ant_id: String, colony_name: String, rule: Dictionary) -> bool:
	var property_value = get_property_value(ant_id, colony_name, rule["property"])
	var comparison_value = float(rule["value"]) # Assume numerical comparison for simplicity
	var operator = rule["operator"]
	
	match operator:
		"EQUAL": return property_value == comparison_value
		"NOT_EQUAL": return property_value != comparison_value
		"GREATER_THAN": return property_value > comparison_value
		"LESS_THAN": return property_value < comparison_value
		"GREATER_THAN_OR_EQUAL": return property_value >= comparison_value
		"LESS_THAN_OR_EQUAL": return property_value <= comparison_value
		_: 
			push_warning("Unknown operator in ant behavior condition: " + operator)
			return false

func get_property_value(ant_id: String, colony_name: String, property_path: String) -> float:
	var path_parts = property_path.split(".")
	var main_property = path_parts[0]
	var sub_property = path_parts[1] if path_parts.size() > 1 else ""
	
	match main_property:
		"food":
			match sub_property:
				"in_view": return get_food_in_view(ant_id)
				"in_reach": return get_food_in_reach(ant_id)
		"energy":
			match sub_property:
				"current": return get_ant_energy(ant_id)
				"max": return get_ant_max_energy(ant_id)
		"carry_mass":
			match sub_property:
				"current": return get_ant_carry_mass(ant_id)
				"max": return get_ant_max_carry_mass(ant_id)
		"home":
			match sub_property:
				"within_reach": return float(is_home_within_reach(ant_id))
		"sight_range": return get_ant_sight_range(ant_id)
		"pheromone_sense_range": return get_ant_pheromone_sense_range(ant_id)
	
	push_warning("Unknown property in ant behavior: " + property_path)
	return 0.0

# Implement these methods to interact with your simulation state
func get_food_in_view(ant_id: String) -> float:
	# Implementation depends on your simulation logic
	return 0.0

func get_food_in_reach(ant_id: String) -> float:
	# Implementation depends on your simulation logic
	return 0.0

func get_ant_energy(ant_id: String) -> float:
	# Implementation depends on your simulation logic
	return 0.0

func get_ant_max_energy(ant_id: String) -> float:
	# Implementation depends on your simulation logic
	return 0.0

func get_ant_carry_mass(ant_id: String) -> float:
	# Implementation depends on your simulation logic
	return 0.0

func get_ant_max_carry_mass(ant_id: String) -> float:
	# Implementation depends on your simulation logic
	return 0.0

func is_home_within_reach(ant_id: String) -> bool:
	# Implementation depends on your simulation logic
	return false

func get_ant_sight_range(ant_id: String) -> float:
	# Implementation depends on your simulation logic
	return 0.0

func get_ant_pheromone_sense_range(ant_id: String) -> float:
	# Implementation depends on your simulation logic
	return 0.0

func execute_action(ant_id: String, colony_name: String, action: String) -> void:
	match action:
		"move_to_nearest_food":
			move_to_nearest_food(ant_id)
		"harvest_nearest_food":
			harvest_nearest_food(ant_id)
		"return_home":
			return_home(ant_id)
		"store_food":
			store_food(ant_id)
		_:
			push_warning("Unknown action in ant behavior: " + action)

# Implement these methods to interact with your simulation state
func move_to_nearest_food(ant_id: String) -> void:
	# Implementation depends on your simulation logic
	pass

func harvest_nearest_food(ant_id: String) -> void:
	# Implementation depends on your simulation logic
	pass

func return_home(ant_id: String) -> void:
	# Implementation depends on your simulation logic
	pass

func store_food(ant_id: String) -> void:
	# Implementation depends on your simulation logic
	pass

func update_ant_behavior(ant_profile_id: String, updated_behavior: Array) -> void:
	rule_manager.save_rules(ant_profile_id, updated_behavior, false)

func get_ant_behavior(ant_profile_id: String) -> Array:
	return rule_manager.load_rules(ant_profile_id, false)
