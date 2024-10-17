extends Node

const SAVE_DIR = "user://saves/"
const SAVE_FILE_NAME = "colony_data.json"

var current_data: Dictionary = {
	"colonies": {}
}

func _ready():
	load_data()

func save_data() -> void:
	var dir = DirAccess.open("user://")
	if not dir.dir_exists(SAVE_DIR):
		dir.make_dir(SAVE_DIR)
	
	var file = FileAccess.open(SAVE_DIR + SAVE_FILE_NAME, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(current_data, "", false))
		file.close()
	else:
		push_error("Error: Could not save data")

func load_data() -> void:
	if FileAccess.file_exists(SAVE_DIR + SAVE_FILE_NAME):
		var file = FileAccess.open(SAVE_DIR + SAVE_FILE_NAME, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json_result = JSON.parse_string(json_string)
			if json_result is Dictionary:
				current_data = json_result
			else:
				push_error("Error: Malformed save data")
	else:
		push_warning("No save file found. Starting with empty data.")
		# Initialize with default data
		var default_file = FileAccess.open("res://default_colony_data.json", FileAccess.READ)
		if default_file:
			var json_string = default_file.get_as_text()
			default_file.close()
			
			var json_result = JSON.parse_string(json_string)
			if json_result is Dictionary:
				current_data = json_result
				save_data()  # Save the default data
			else:
				push_error("Error: Malformed default data")

func get_colony_names() -> Array:
	return current_data["colonies"].keys()

func get_colony_data(colony_name: String) -> Dictionary:
	if colony_name in current_data["colonies"]:
		return current_data["colonies"][colony_name]
	push_warning("Colony not found: " + colony_name)
	return {}

func save_colony(colony_name: String, colony_data: Dictionary) -> void:
	current_data["colonies"][colony_name] = colony_data
	save_data()

func delete_colony(colony_name: String) -> void:
	if colony_name in current_data["colonies"]:
		current_data["colonies"].erase(colony_name)
		save_data()
	else:
		push_warning("Attempted to delete non-existent colony: " + colony_name)

func get_ant_profiles(colony_name: String) -> Array:
	if colony_name in current_data["colonies"]:
		return current_data["colonies"][colony_name].get("ant_profiles", [])
	push_warning("Colony not found: " + colony_name)
	return []

func save_ant_profile(colony_name: String, ant_profile: Dictionary) -> void:
	if colony_name not in current_data["colonies"]:
		current_data["colonies"][colony_name] = {"ant_profiles": []}
	
	var ant_profiles = current_data["colonies"][colony_name]["ant_profiles"]
	var existing_index = ant_profiles.find(func(profile): return profile["name"] == ant_profile["name"])
	
	if existing_index != -1:
		ant_profiles[existing_index] = ant_profile
	else:
		ant_profiles.append(ant_profile)
	
	save_data()

func update_ant_profile(colony_name: String, updated_profile: Dictionary) -> void:
	if colony_name in current_data["colonies"]:
		var ant_profiles = current_data["colonies"][colony_name]["ant_profiles"]
		var existing_index = ant_profiles.find(func(profile): return profile["name"] == updated_profile["name"])
		
		if existing_index != -1:
			ant_profiles[existing_index] = updated_profile
			save_data()
		else:
			push_warning("Ant profile not found for updating: " + updated_profile["name"])
	else:
		push_warning("Colony not found: " + colony_name)

func delete_ant_profile(colony_name: String, ant_name: String, index: int) -> void:
	if colony_name in current_data["colonies"]:
		var ant_profiles = current_data["colonies"][colony_name]["ant_profiles"]
		if index >= 0 and index < ant_profiles.size():
			ant_profiles.remove_at(index)
			save_data()
		else:
			push_warning("Invalid index for ant profile deletion: " + str(index))
	else:
		push_warning("Attempted to delete ant profile from non-existent colony: " + colony_name)

func create_new_ant_profile(profile_name: String) -> Dictionary:
	return {
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
