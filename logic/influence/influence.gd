class_name Influence
extends Logic
## Logic wrapper adding some additional properties and setting some defaults

#region Properties
## Debug visualization color
@export var color: Color
@export var condition: Logic
#endregion

func _init():
	# Ensure resource has a unique name
	resource_name = "Influence"
	type = TYPE_VECTOR2
	# Set default color if none provided
	if not color:
		color = Color(randf(),randf(),randf())

## Returns true if no condition or if condition evaluates to true
func is_valid(entity: Node2D) -> bool:
	if not condition:
		return true
	return EvaluationSystem.get_value(condition, entity)
