class_name StorageResource
extends PropertyResource
## Resource for managing storage-related properties

#region Inner Classes
class MaxCapacityResource extends PropertyResource:
	func _init() -> void:
		setup(
			"max",
			PropertyNode.Type.VALUE,
			"Maximum weight the entity can store",
			{},
			Property.Type.FLOAT,
			["strength.derived.carry_factor"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func():
			return entity.get_property_value("strength.derived.carry_factor")

class CurrentCapacityResource extends PropertyResource:
	func _init() -> void:
		setup(
			"current",
			PropertyNode.Type.VALUE,
			"Current total mass of stored items",
			{},
			Property.Type.FLOAT
		)
	
	func create_getter(entity: Node) -> Callable:
		return func(): return entity.foods.get_mass()

class PercentageResource extends PropertyResource:
	func _init() -> void:
		setup(
			"percentage",
			PropertyNode.Type.VALUE,
			"Current storage used as percentage of maximum",
			{},
			Property.Type.FLOAT,
			["storage.capacity.current", "storage.capacity.max"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func():
			var maximum = entity.get_property_value("storage.capacity.max")
			if maximum <= 0:
				return 0.0
			var current = entity.get_property_value("storage.capacity.current")
			return (current / maximum) * 100.0

class AvailableResource extends PropertyResource:
	func _init() -> void:
		setup(
			"available",
			PropertyNode.Type.VALUE,
			"Remaining storage capacity available",
			{},
			Property.Type.FLOAT,
			["storage.capacity.max", "storage.capacity.current"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func():
			var maximum = entity.get_property_value("storage.capacity.max")
			var current = entity.get_property_value("storage.capacity.current")
			return maximum - current

#endregion

func _init() -> void:
	setup(
		"storage",
		PropertyNode.Type.CONTAINER,
		"Storage management",
		{
			"capacity": create_capacity_config()
		}
	)

func create_capacity_config() -> PropertyResource:
	return PropertyResource.create_container(
		"capacity",
		"Information about entity's storage capacity",
		{
			"max": MaxCapacityResource.new(),
			"current": CurrentCapacityResource.new(),
			"percentage": PercentageResource.new(),
			"available": AvailableResource.new()
		}
	)
