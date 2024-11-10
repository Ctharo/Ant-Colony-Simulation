class_name Pheromone
extends Node2D

signal spawned
signal died

var type: String
var concentration: float
var emitted_by: Ant

func _init(p_position: Vector2, p_type: String, p_concentration: float, p_emitted_by: Ant):
	global_position = p_position
	type = p_type
	concentration = p_concentration
	emitted_by = p_emitted_by
	add_to_group("pheromone")

func _ready():
	spawned.emit()
