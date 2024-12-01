@tool
class_name ColonyDistancePropertyResource
extends PropertyResource
## Resource for colony position property

func _init() -> void:
	setup(
		"distance",
		PropertyNode.Type.VALUE,
		"Distance to the colony",
		{},
		Property.Type.VECTOR2,
		["proprioception.colony.position", "proprioception.position"]
	)

func create_getter(entity: Node) -> Callable:
	return func(): return entity.get_property_value("proprioception.position").distance_to(entity.get_property_value("colony.position")) or 0.0
