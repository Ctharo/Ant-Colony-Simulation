class_name ProprioceptionResource
extends PropertyResource
## Resource for managing proprioception-related properties

#region Inner Classes
class BasePositionResource extends PropertyResource:
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

class TargetPositionResource extends PropertyResource:
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

class ColonyPositionResource extends PropertyResource:
	func _init() -> void:
		setup(
			"position",
			PropertyNode.Type.VALUE,
			"Global position of the colony",
			{},
			Property.Type.VECTOR2
		)

	func create_getter(entity: Node) -> Callable:
		return func(): return entity.get_property_value("colony.position") or Vector2.ZERO

class ColonyDirectionResource extends PropertyResource:
	func _init() -> void:
		setup(
			"direction",
			PropertyNode.Type.VALUE,
			"Normalized vector pointing towards colony",
			{},
			Property.Type.VECTOR2,
			["proprioception.base.position", "proprioception.colony.position"]
		)

	func create_getter(entity: Node) -> Callable:
		return func():
			var pos = entity.get_property_value("proprioception.base.position")
			var colony_pos = entity.get_property_value("proprioception.colony.position")
			return pos.direction_to(colony_pos) if colony_pos else Vector2.ZERO

class ColonyDistanceResource extends PropertyResource:
	func _init() -> void:
		setup(
			"distance",
			PropertyNode.Type.VALUE,
			"Distance from entity to colony in units",
			{},
			Property.Type.FLOAT,
			["proprioception.base.position", "proprioception.colony.position"]
		)

	func create_getter(entity: Node) -> Callable:
		return func():
			var pos = entity.get_property_value("proprioception.base.position")
			var colony_pos = entity.get_property_value("proprioception.colony.position")
			return pos.distance_to(colony_pos) if colony_pos else 0.0
#endregion

func _init() -> void:
	setup(
		"proprioception",
		PropertyNode.Type.CONTAINER,
		"Proprioception management",
		{
			"base": create_base_config(),
			"colony": create_colony_config()
		}
	)

func create_base_config() -> PropertyResource:
	return PropertyResource.create_container(
		"base",
		"Base position information",
		{
			"position": BasePositionResource.new(),
			"target_position": TargetPositionResource.new()
		}
	)

func create_colony_config() -> PropertyResource:
	return PropertyResource.create_container(
		"colony",
		"Information about position relative to colony",
		{
			"position": ColonyPositionResource.new(),
			"direction": ColonyDirectionResource.new(),
			"distance": ColonyDistanceResource.new()
		}
	)
