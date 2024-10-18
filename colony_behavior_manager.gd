extends Node

var data_manager: DataManager

func _ready():
	data_manager = DataManager

func evaluate_colony_behavior(colony_name: String) -> void:
	var colony_behavior = data_manager.get_colony_behavior(colony_name)
	
	for rule in colony_behavior:
		if evaluate_condition(colony_name, rule["condition"]):
			execute_action(colony_name, rule["action"])

func evaluate_condition(colony_name: String, condition: Dictionary) -> bool:
	var left_value = get_property_value(colony_name, condition["left"])
	var right_value = get_property_value(colony_name, condition["right"])
	var operator = condition["operator"]
	
	match operator:
		"==": return left_value == right_value
		"!=": return left_value != right_value
		">": return left_value > right_value
		"<": return left_value < right_value
		">=": return left_value >= right_value
		"<=": return left_value <= right_value
		_: 
			push_warning("Unknown operator in colony behavior condition: " + operator)
			return false

func execute_action(colony_name: String, action: Dictionary) -> void:
	match action["type"]:
		"spawn_ant":
			spawn_ant(colony_name, action["profile"])
		"set_property":
			set_property(colony_name, action["property"], action["value"])
		_:
			push_warning("Unknown action type in colony behavior: " + action["type"])

func spawn_ant(colony_name: String, profile_name: String) -> void:
	# This function would interact with the simulation to spawn a new ant
	print("Spawning ant of profile '" + profile_name + "' in colony '" + colony_name + "'")

func set_property(colony_name: String, property_path: String, value: Variant) -> void:
	data_manager.set_property_value(colony_name, property_path, value)

func get_property_value(colony_name: String, property_path: String) -> Variant:
	return data_manager.get_property_value(colony_name, property_path)

func time_since_last_spawn(colony_name: String, ant_profile: String = "") -> float:
	var last_spawn_time = get_property_value(colony_name, "last_spawn_time." + ant_profile)
	if last_spawn_time == null:
		return INF
	return Time.get_ticks_msec() / 1000.0 - last_spawn_time

func update_last_spawn_time(colony_name: String, ant_profile: String) -> void:
	set_property(colony_name, "last_spawn_time." + ant_profile, Time.get_ticks_msec() / 1000.0)
