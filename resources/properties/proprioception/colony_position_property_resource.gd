@tool
class_name ColonyPositionPropertyResource
extends PropertyResource
## Resource for colony position property

func _init() -> void:
	setup(
		"position",
		PropertyNode.Type.VALUE,
		"Global position of the colony",
		{},
		Property.Type.VECTOR2,
		["proprioception.colony.position"]
	)

func create_getter(entity: Node) -> Callable:
	return func(): return entity.get_property_value("colony.position") or Vector2.ZERO
