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
@export var movement_rate: float
@export var vision_range: float = 100.0
@export var olfaction_range: float = 200.0
@export var reach_range: float = 50.0
@export var size: float
