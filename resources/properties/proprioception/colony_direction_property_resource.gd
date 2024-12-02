@tool
class_name ColonyDirectionPropertyResource
extends PropertyResource
## Resource for colony position property

func _init() -> void:
	setup(
		"direction",
		PropertyNode.Type.VALUE,
		"Direction to the colony",
		{},
		Property.Type.VECTOR2,
		["proprioception.colony.position"]
	)

func create_getter(entity: Node) -> Callable:
	return func(): return entity.get_property_value("proprioception.colony.position") or Vector2.ZERO
