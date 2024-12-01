@tool
class_name ProprioceptionResource
extends PropertyResource
## Resource for managing proprioception-related properties

func _init() -> void:
	setup(
		"proprioception",
		PropertyNode.Type.CONTAINER,
		"Proprioception management",
		{
			"base": create_base_config(),
			"colony": create_colony_config(),
			"status": create_status_config()
		}
	)

func create_base_config() -> PropertyResource:
	return PropertyResource.create_container(
		"base",
		"Base position information",
		{
			"position": PositionPropertyResource.new(),
			"target_position": TargetPositionPropertyResource.new()
		}
	)

func create_colony_config() -> PropertyResource:
	return PropertyResource.create_container(
		"colony",
		"Information about position relative to colony",
		{
			"position": ColonyPositionPropertyResource.new(),
			"direction": ColonyDirectionPropertyResource.new(),
			"distance": ColonyDistancePropertyResource.new()
		}
	)

func create_status_config() -> PropertyResource:
	return PropertyResource.create_container(
		"status",
		"Position status information",
		{
			"at_target": _create_at_target_config(),
			"at_colony": _create_at_colony_config(),
			"has_moved": _create_has_moved_config()
		}
	)

#region Value Configurations
func _create_position_config() -> PropertyResource:
	var config := PropertyResource.create_value(
		"position",
		"Current global position of the entity",
		Property.Type.VECTOR2
	)
	config._create_getter = func(entity): return func(): return entity.global_position
	return config

func _create_target_position_config() -> PropertyResource:
	var config := PropertyResource.create_value(
		"target_position",
		"Current target position for movement",
		Property.Type.VECTOR2
	)
	config._create_getter = func(entity): return func(): return entity.target_position
	config._create_setter = func(entity): return func(value): entity.target_position = value
	return config

func _create_colony_position_config() -> PropertyResource:
	var config := PropertyResource.create_value(
		"position",
		"Global position of the colony",
		Property.Type.VECTOR2,
		["colony.position"]
	)
	config._create_getter = func(entity): return func(): return entity.get_property_value("colony.position") or Vector2.ZERO
	return config

func _create_colony_direction_config() -> PropertyResource:
	var config := PropertyResource.create_value(
		"direction",
		"Normalized vector pointing towards colony",
		Property.Type.VECTOR2,
		["proprioception.base.position", "proprioception.colony.position"]
	)
	config._create_getter = func(entity):
		return func():
			var pos = entity.global_position
			var colony_pos = entity.get_property_value("colony.position")
			return pos.direction_to(colony_pos) if colony_pos else Vector2.ZERO
	return config

func _create_colony_distance_config() -> PropertyResource:
	var config := PropertyResource.create_value(
		"distance",
		"Distance from entity to colony in units",
		Property.Type.FLOAT,
		["proprioception.base.position", "proprioception.colony.position"]
	)
	config._create_getter = func(entity):
		return func():
			var pos = entity.global_position
			var colony_pos = entity.get_property_value("colony.position")
			return pos.distance_to(colony_pos) if colony_pos else 0.0
	return config

func _create_at_target_config() -> PropertyResource:
	var config := PropertyResource.create_value(
		"at_target",
		"Whether the entity is at the target location",
		Property.Type.BOOL,
		["proprioception.base.position", "proprioception.base.target_position"]
	)
	config._create_getter = func(entity):
		return func():
			var pos = entity.get_property_value("proprioception.base.position")
			var target = entity.get_property_value("proprioception.base.target_position")
			return pos.distance_to(target) < 10 if pos and target else false
	return config

func _create_at_colony_config() -> PropertyResource:
	var config := PropertyResource.create_value(
		"at_colony",
		"Whether the entity is at the colony",
		Property.Type.BOOL,
		["proprioception.colony.distance"]
	)
	config._create_getter = func(entity):
		return func():
			var distance = entity.get_property_value("proprioception.colony.distance")
			return is_zero_approx(distance) if distance != null else false
	return config

func _create_has_moved_config() -> PropertyResource:
	var config := PropertyResource.create_value(
		"has_moved",
		"Whether the entity has moved from its starting position",
		Property.Type.BOOL,
		["proprioception.base.position"]
	)
	config._create_getter = func(entity):
		return func():
			var pos = entity.get_property_value("proprioception.base.position")
			return not is_zero_approx(pos.length()) if pos else false
	return config
#endregion
