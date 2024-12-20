class_name Influence
extends Resource
@export var name: String :
	set(value):
		name = value
		id = name.to_snake_case()
var id: String
@export var direction: Logic :
	set(value):
		assert(value.type == 4) ## Should return Vector2
		direction = value
@export var weight: Logic :
	set(value):
		assert(value.type == 2) ## Should return float
		weight = value
@export var color: Color
