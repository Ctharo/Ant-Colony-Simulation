@icon("res://assets/entities/apple-4967157_640.png")
class_name Food
extends Node2D

## Whether this food unit is stored in a colony
var stored: bool = false
## Whether this food unit is being carried by an ant
var carried: bool = false
## Whether this food unit is targeted for pickup
var targeted: bool = false

## Whether this food unit is available for pickup
var is_available: bool :
	get:
		return not carried and not stored and not targeted

func _init() -> void:
	add_to_group("food")

func _physics_process(delta: float) -> void:
	if carried:
		global_position = get_parent().global_position

## Hide this food unit but keep it in the scene tree
func hide_visual() -> void:
	visible = false

## Show this food unit's visual
func show_visual() -> void:
	visible = true
