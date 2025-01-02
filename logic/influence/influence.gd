class_name Influence
extends Logic

#region Properties
## Debug visualization color
@export var color: Color
#endregion

func _init():
	# Ensure resource has a unique name
	resource_name = "Influence"
	type = TYPE_VECTOR2
	# Set default color if none provided
	if not color:
		color = Color.WHITE
