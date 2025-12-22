@icon("res://assets/entities/apple-4967157_640.png")
class_name Food
extends Node2D

enum State { STORED = 0, CARRIED = 1, TARGETED = 2, AVAILABLE = 3 }
var _state = State.AVAILABLE : set = set_state
var size: float
## Whether this food unit is available for pickup
@export var is_available: bool

func _init() -> void:
	add_to_group("food")
	set_state(State.AVAILABLE)

func set_state(value: State):
	_state = value
	is_available = (_state == State.AVAILABLE)

func get_size() -> float:
	return %CollisionShape2D.shape.radius

## Hide this food unit but keep it in the scene tree
func hide_visual() -> void:
	visible = false

## Show this food unit's visual
func show_visual() -> void:
	visible = true
