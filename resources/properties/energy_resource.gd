class_name EnergyResource
extends PropertyResource
## Resource for managing energy-related properties

#region Inner Classes
class MaxLevelResource extends PropertyResource:
	func _init() -> void:
		setup(
			"max",
			PropertyNode.Type.VALUE,
			"Maximum energy level",
			{},
			Property.Type.FLOAT
		)
	
	func create_getter(entity: Node) -> Callable:
		return func(): return entity.max_level
	
	func create_setter(entity: Node) -> Callable:
		return func(value): 
			if is_zero_approx(value):
				return
			entity.set_property_value("energy.capacity.current", value)
			

class CurrentLevelResource extends PropertyResource:
	func _init() -> void:
		setup(
			"current",
			PropertyNode.Type.VALUE,
			"Current energy level",
			{},
			Property.Type.FLOAT
		)
	
	func create_getter(entity: Node) -> Callable:
		return func(): return entity.current_level
	
	func create_setter(entity: Node) -> Callable:
		return func(value): 
			var max_level = entity.get_property_value("energy.capacity.max")
			entity.set_property_value("energy.capacity.max", clamp(value, 0.0, max_level))

class PercentageResource extends PropertyResource:
	func _init() -> void:
		setup(
			"percentage",
			PropertyNode.Type.VALUE,
			"Current energy level as a percentage of max energy",
			{},
			Property.Type.FLOAT,
			["energy.capacity.current", "energy.capacity.max"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func(): 
			var current = entity.get_property_value("energy.capacity.current")
			var max_level = entity.get_property_value("energy.capacity.max")
			return (current / max_level) * 100.0 if max_level > 0 else 0.0

class ReplenishableResource extends PropertyResource:
	func _init() -> void:
		setup(
			"replenishable",
			PropertyNode.Type.VALUE,
			"Amount of energy that can be replenished",
			{},
			Property.Type.FLOAT,
			["energy.capacity.current", "energy.capacity.max"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func():
			var current = entity.get_property_value("energy.capacity.current")
			var max_level = entity.get_property_value("energy.capacity.max")
			return max_level - current

#endregion

func _init() -> void:
	setup(
		"energy",
		PropertyNode.Type.CONTAINER,
		"Energy management",
		{
			"capacity": create_capacity_config(),
			"status": create_status_config()
		}
	)

func create_capacity_config() -> PropertyResource:
	return PropertyResource.create_container(
		"capacity",
		"Energy capacity information",
		{
			"max": MaxLevelResource.new(),
			"current": CurrentLevelResource.new(),
			"percentage": PercentageResource.new()
		}
	)

func create_status_config() -> PropertyResource:
	return PropertyResource.create_container(
		"status",
		"Energy status information",
		{
			"replenishable": ReplenishableResource.new(),
		}
	)
