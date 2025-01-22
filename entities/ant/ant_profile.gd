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
@export var size: float
