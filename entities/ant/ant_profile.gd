class_name AntProfile
extends Resource

@export var name: String :
	set(value):
		name = value
		id = name.to_snake_case()
var id: String
@export var pheromones: Array[Pheromone]
@export var movement_influences: Array[InfluenceProfile]
@export var movement_rate: float
@export var vision_range: float 
@export var olfaction_range: float 
@export var reach_range: float
@export var size: float
