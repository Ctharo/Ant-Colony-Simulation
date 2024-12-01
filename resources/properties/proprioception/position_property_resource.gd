@tool
class_name PositionPropertyResource
extends PropertyResource
## Resource for entity position property

func _init() -> void:
	setup(
		"position",
		PropertyNode.Type.VALUE,
		"Current global position of the entity",
		{},
		Property.Type.VECTOR2
	)

func create_getter(entity: Node) -> Callable:
	return func(): return entity.global_position
