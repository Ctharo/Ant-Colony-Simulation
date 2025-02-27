class_name AntProfile
extends Resource

@export var name: String :
	set(value):
		name = value
		id = name.to_snake_case()
var id: String
@export var spawn_condition: Logic
@export var pheromones: Array[Pheromone]
@export var movement_influences: Array[InfluenceProfile]
# Add action profiles to support the new action system
@export var action_profiles: Array[AntActionProfile]
@export var movement_rate: float
@export var vision_range: float = 100.0
@export var size: float

## Create a basic worker ant profile
static func create_basic_worker() -> AntProfile:
	var profile = AntProfile.new()
	profile.name = "Basic Worker"
	profile.movement_rate = 25.0
	profile.vision_range = 100.0
	profile.size = 1.0
	profile.spawn_condition = Logic.new()
	profile.spawn_condition.expression_string = 'ant_count_by_role("basic_worker") < 5 and ticks_since_spawn() > 1000'

	# Add pheromones
	profile.pheromones = [
		load("res://entities/pheromone/resources/food_pheromone.tres"),
		load("res://entities/pheromone/resources/home_pheromone.tres")
	] as Array[Pheromone]

	# Add movement influences
	profile.movement_influences = [
		load("res://resources/influences/profiles/look_for_food.tres"),
		load("res://resources/influences/profiles/go_home.tres")
	] as Array[InfluenceProfile]

	# Add action profiles
	profile.action_profiles = [
		ForagerActionProfile.create_standard()
	] as Array[AntActionProfile]

	return profile
