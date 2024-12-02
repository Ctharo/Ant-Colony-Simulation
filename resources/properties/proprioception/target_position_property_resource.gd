@tool
class_name TargetPositionPropertyResource
extends PropertyResource
## Resource for entity target position property

func _init() -> void:
	setup(
		"target_position",
		PropertyNode.Type.VALUE,
		"Current target position for movement",
		{},
		Property.Type.VECTOR2
	)

func create_getter(entity: Node) -> Callable:
	return func(): return entity.target_position

func create_setter(entity: Node) -> Callable:
	return func(value): entity.target_position = value
