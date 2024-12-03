class_name HealthResource
extends PropertyResource
## Resource for managing health-related properties

#region Inner Classes
class MaxLevelResource extends PropertyResource:
	func _init() -> void:
		setup(
			"max",
			PropertyNode.Type.VALUE,
			"Maximum health level",
			{},
			Property.Type.FLOAT
		)
	
	func create_getter(entity: Node) -> Callable:
		return func(): return entity.max_level
	
	func create_setter(entity: Node) -> Callable:
		return func(value): entity.max_level = value

class CurrentLevelResource extends PropertyResource:
	func _init() -> void:
		setup(
			"current",
			PropertyNode.Type.VALUE,
			"Current health level",
			{},
			Property.Type.FLOAT
		)
	
	func create_getter(entity: Node) -> Callable:
		return func(): return entity.current_level
	
	func create_setter(entity: Node) -> Callable:
		return func(value): entity.current_level = value

class PercentageResource extends PropertyResource:
	func _init() -> void:
		setup(
			"percentage",
			PropertyNode.Type.VALUE,
			"Current health level as a percentage of max health",
			{},
			Property.Type.FLOAT,
			["health.capacity.current", "health.capacity.max"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func(): 
			var current = entity.get_property_value("health.capacity.current")
			var max_level = entity.get_property_value("health.capacity.max")
			return (current / max_level) * 100.0 if max_level > 0 else 0.0

class ReplenishableResource extends PropertyResource:
	func _init() -> void:
		setup(
			"replenishable",
			PropertyNode.Type.VALUE,
			"Amount of health that can be restored",
			{},
			Property.Type.FLOAT,
			["health.capacity.current", "health.capacity.max"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func():
			var current = entity.get_property_value("health.capacity.current")
			var max_level = entity.get_property_value("health.capacity.max")
			return max_level - current

#endregion

func _init() -> void:
	setup(
		"health",
		PropertyNode.Type.CONTAINER,
		"Health management",
		{
			"capacity": create_capacity_config(),
			"status": create_status_config()
		}
	)

func create_capacity_config() -> PropertyResource:
	return PropertyResource.create_container(
		"capacity",
		"Health capacity information",
		{
			"max": MaxLevelResource.new(),
			"current": CurrentLevelResource.new(),
			"percentage": PercentageResource.new()
		}
	)

func create_status_config() -> PropertyResource:
	return PropertyResource.create_container(
		"status",
		"Health status information",
		{
			"replenishable": ReplenishableResource.new(),
		}
	)
