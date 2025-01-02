class_name Influence
extends Resource

#region Properties
## Name of the influence
@export var name: String:
	set(value):
		name = value
		id = name.to_snake_case() if name else ""

## Unique identifier for this influence
var id: String

## Direction logic expression (must return Vector2)
@export var direction_logic: Logic:
	set(value):
		direction_logic = value

## Debug visualization color
@export var color: Color
#endregion

func _init():
	# Ensure resource has a unique name
	resource_name = "Influence"

	# Set default color if none provided
	if not color:
		color = Color.WHITE
