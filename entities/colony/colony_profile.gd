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

## Create a standard colony profile
static func create_standard() -> ColonyProfile:
	var profile = ColonyProfile.new()
	profile.name = "Standard Colony"
	profile.radius = 60.0
	profile.max_ants = 25
	profile.spawn_rate = 10.0

	# Add ant profiles
	profile.ant_profiles = [
		AntProfile.create_basic_worker()
	] as Array[AntProfile]



	# Set initial ant counts
	profile.initial_ants = {
		"basic_worker": 1
	}

	return profile

## Create a starting colony profile with minimal ants
static func create_starter() -> ColonyProfile:
	var profile = ColonyProfile.new()
	profile.name = "Starter Colony"
	profile.radius = 40.0
	profile.max_ants = 15
	profile.spawn_rate = 15.0

	# Add ant profiles
	profile.ant_profiles = [
		AntProfile.create_basic_worker()
	]

	# Set initial ant counts
	profile.initial_ants = {
		"basic_worker": 3
	}

	return profile

## Create an advanced colony with specialized ant types
static func create_advanced() -> ColonyProfile:
	var profile = ColonyProfile.new()
	profile.name = "Advanced Colony"
	profile.radius = 80.0
	profile.max_ants = 40
	profile.spawn_rate = 7.5

	# Add various ant profiles
	var worker = AntProfile.create_basic_worker()

	profile.ant_profiles = [
		worker
	]

	# Set initial ant counts
	profile.initial_ants = {
		"basic_worker": 8
	}

	return profile

## Find an ant profile by ID
func get_ant_profile_by_id(profile_id: String) -> AntProfile:
	for profile in ant_profiles:
		if profile.id == profile_id:
			return profile
	return null
