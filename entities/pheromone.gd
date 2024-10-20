extends Node
class_name Pheromone

signal spawned
signal died

var position: Vector2
var type: String
var concentration: float
var emitted_by: Ant

func _init(p_position: Vector2, p_type: String, p_concentration: float, p_emitted_by: Ant):
	position = p_position
	type = p_type
	concentration = p_concentration
	emitted_by = p_emitted_by

func _ready():
	spawned.emit()
