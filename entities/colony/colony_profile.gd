class_name ColonyProfile
extends Resource

@export var name: String:
	set(value):
		name = value
		id = name.to_snake_case()
var id: String

## Ant profiles available for this colony
@export var ant_profiles: Array[AntProfile]

## Colony parameters
@export var radius: float = 60.0
@export var max_ants: int = 25
@export var spawn_rate: float = 10.0  # Seconds between spawns
@export var dirt_color: Color = Color(Color.SADDLE_BROWN, 0.8)
@export var darker_dirt: Color = Color(Color.BROWN, 0.9)

## Initial ant counts by profile
@export var initial_ants: Dictionary = {}  # {profile_id: count}






## Find an ant profile by ID
func get_ant_profile_by_id(profile_id: String) -> AntProfile:
	for profile in ant_profiles:
		if profile.id == profile_id:
			return profile
	return null
