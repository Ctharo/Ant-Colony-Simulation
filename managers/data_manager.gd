extends BaseNode

const SAVE_DIR = "user://saves/"
const COLONY_SAVE_FILE = "colony_profiles.json"
const ANT_SAVE_FILE = "ant_profiles.json"
const UUID = preload("res://addons/uuid/uuid.gd")

var current_colony_data: Dictionary = {}
var current_ant_data: Dictionary = {}


func _init() -> void:
	log_category = DebugLogger.Category.DATA
	log_from = "data_manager"
	
func _ready():
	load_data()

func save_data() -> void:
	var dir = DirAccess.open("user://")
	if not dir.dir_exists(SAVE_DIR):
		dir.make_dir(SAVE_DIR)

	save_file(COLONY_SAVE_FILE, current_colony_data)
	save_file(ANT_SAVE_FILE, current_ant_data)

func save_file(file_name: String, data: Dictionary) -> void:
	var file = FileAccess.open(SAVE_DIR + file_name, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "", false))
		file.close()
	else:
		_error("Error: Could not save data to " + file_name)

func load_data() -> void:
	current_colony_data = load_file(COLONY_SAVE_FILE, "res://default_colony_profiles.json")
	current_ant_data = load_file(ANT_SAVE_FILE, "res://default_ant_profiles.json")

func load_file(_save_file: String, default_file: String) -> Dictionary:
	if FileAccess.file_exists(SAVE_DIR + _save_file):
		var file = FileAccess.open(SAVE_DIR + _save_file, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			var json_result = JSON.parse_string(json_string)
			if json_result is Dictionary:
				return json_result
			else:
				_error("Error: Malformed save data in " + _save_file)

	push_warning("No save file found for " + _save_file + ". Loading default data.")
	var default_data = FileAccess.open(default_file, FileAccess.READ)
	if default_data:
		var json_string = default_data.get_as_text()
		default_data.close()
		var json_result = JSON.parse_string(json_string)
		if json_result is Dictionary:
			save_file(_save_file, json_result)  # Save the default data
			return json_result
		else:
			_error("Error: Malformed default data in " + default_file)
	else:
		_error("Error: Could not open default data file " + default_file)

	return {}

# Colony-related functions

func get_colony_names() -> Array:
	return current_colony_data.keys()

func get_colony_data(colony_name: String) -> Dictionary:
	if colony_name in current_colony_data:
		return current_colony_data[colony_name]
	_warn("Colony not found: " + colony_name)
	return {}

func save_colony(colony_name: String, colony_data: Dictionary) -> void:
	current_colony_data[colony_name] = colony_data
	save_data()

func delete_colony(colony_name: String) -> void:
	if colony_name in current_colony_data:
		current_colony_data.erase(colony_name)
		save_data()
	else:
		_warn("Attempted to delete non-existent colony: " + colony_name)

func create_new_colony(colony_name: String) -> void:
	if colony_name not in current_colony_data:
		current_colony_data[colony_name] = {
			"ant_profiles": [],
			"colony_behavior": []
		}
		save_data()
	else:
		_warn("Colony already exists: " + colony_name)

func colony_exists(colony_name: String) -> bool:
	return colony_name in current_colony_data

# Ant profile-related functions

func create_new_ant_profile(profile_name: String) -> String:
	var profile_id = UUID.v4()
	current_ant_data[profile_id] = {
		"name": profile_name,
		"stats": {
			"sight_range": 5,
			"pheromone_sense_range": 3,
			"speed": 1,
			"strength": 1,
			"intelligence": 1
		},
		"behavior_logic": []
	}
	save_data()
	return profile_id

func get_all_ant_profiles() -> Dictionary:
	return current_ant_data

func get_ant_profile(profile_id: String) -> Dictionary:
	return current_ant_data.get(profile_id, {})

func update_ant_profile(profile_id: String, updated_profile: Dictionary) -> void:
	if profile_id in current_ant_data:
		current_ant_data[profile_id] = updated_profile
		save_data()
	else:
		_warn("Attempted to update non-existent ant profile: " + profile_id)

func delete_ant_profile(profile_id: String) -> void:
	if profile_id in current_ant_data:
		current_ant_data.erase(profile_id)
		# Remove this profile from all colonies that use it
		for colony in current_colony_data.values():
			colony["ant_profiles"].erase(profile_id)
		save_data()
	else:
		_warn("Attempted to delete non-existent ant profile: " + profile_id)

func ant_profile_exists(profile_id: String) -> bool:
	return profile_id in current_ant_data

func update_ant_profile_stats(profile_id: String, updated_stats: Dictionary) -> void:
	if profile_id in current_ant_data:
		current_ant_data[profile_id]["stats"] = updated_stats
		save_data()
	else:
		_warn("Attempted to update stats for non-existent ant profile: " + profile_id)

func update_ant_profile_behavior(profile_id: String, updated_behavior: Array) -> void:
	if profile_id in current_ant_data:
		current_ant_data[profile_id]["behavior_logic"] = updated_behavior
		save_data()
	else:
		_warn("Attempted to update behavior for non-existent ant profile: " + profile_id)

# Colony-Ant profile relationship functions

func add_ant_profile_to_colony(colony_name: String, profile_id: String) -> void:
	if colony_name in current_colony_data and profile_id in current_ant_data:
		if "ant_profiles" not in current_colony_data[colony_name]:
			current_colony_data[colony_name]["ant_profiles"] = []
		if profile_id not in current_colony_data[colony_name]["ant_profiles"]:
			current_colony_data[colony_name]["ant_profiles"].append(profile_id)
			save_data()
	else:
		_warn("Invalid colony name or profile ID")

func remove_ant_profile_from_colony(colony_name: String, profile_id: String) -> void:
	if colony_name in current_colony_data:
		if "ant_profiles" in current_colony_data[colony_name]:
			current_colony_data[colony_name]["ant_profiles"].erase(profile_id)
			save_data()
	else:
		_warn("Attempted to remove ant profile from non-existent colony: " + colony_name)

func get_ant_profiles_for_colony(colony_name: String) -> Array:
	if colony_name in current_colony_data:
		return current_colony_data[colony_name].get("ant_profiles", [])
	else:
		_warn("Attempted to get ant profiles for non-existent colony: " + colony_name)
		return []

# Colony behavior functions

func get_colony_behavior(colony_name: String) -> Array:
	if colony_name in current_colony_data:
		return current_colony_data[colony_name].get("colony_behavior", [])
	_warn("Colony not found: " + colony_name)
	return []

func save_colony_behavior(colony_name: String, colony_behavior: Array) -> void:
	if colony_name not in current_colony_data:
		current_colony_data[colony_name] = {"ant_profiles": [], "colony_behavior": []}

	current_colony_data[colony_name]["colony_behavior"] = colony_behavior
	save_data()

# Property-related functions

func get_property_value(colony_name: String, property_path: String) -> Variant:
	var colony_data = get_colony_data(colony_name)
	var path_parts = property_path.split(".")
	var current_value = colony_data

	for part in path_parts:
		if current_value is Dictionary and part in current_value:
			current_value = current_value[part]
		elif current_value is Array and part.is_valid_int():
			var index = part.to_int()
			if index >= 0 and index < current_value.size():
				current_value = current_value[index]
			else:
				_warn("Invalid array index in property path: " + property_path)
				return null
		else:
			_warn("Invalid property path: " + property_path)
			return null

	return current_value

func set_property_value(colony_name: String, property_path: String, value: Variant) -> void:
	var colony_data = get_colony_data(colony_name)
	var path_parts = property_path.split(".")
	var current_dict = colony_data

	for i in range(path_parts.size() - 1):
		var part = path_parts[i]
		if part not in current_dict:
			current_dict[part] = {}
		current_dict = current_dict[part]

	current_dict[path_parts[-1]] = value
	save_colony(colony_name, colony_data)
