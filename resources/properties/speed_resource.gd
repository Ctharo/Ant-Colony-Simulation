class_name SpeedResource
extends PropertyResource
## Resource for managing speed-related properties

#region Inner Classes
class MovementRateResource extends PropertyResource:
	func _init() -> void:
		setup(
			"rate",
			PropertyNode.Type.VALUE,
			"Rate at which the entity can move (units/second)",
			{},
			Property.Type.FLOAT
		)
	
	func create_getter(entity: Node) -> Callable:
		return func(): return entity.movement_rate
	
	func create_setter(entity: Node) -> Callable:
		return func(value): entity.movement_rate = value

class HarvestingRateResource extends PropertyResource:
	func _init() -> void:
		setup(
			"harvesting",
			PropertyNode.Type.VALUE,
			"Rate at which the entity can harvest resources (units/second)",
			{},
			Property.Type.FLOAT
		)
	
	func create_getter(entity: Node) -> Callable:
		return func(): return entity.harvesting_rate
	
	func create_setter(entity: Node) -> Callable:
		return func(value): entity.harvesting_rate = value

class StoringRateResource extends PropertyResource:
	func _init() -> void:
		setup(
			"storing",
			PropertyNode.Type.VALUE,
			"Rate at which the entity can store resources (units/second)",
			{},
			Property.Type.FLOAT
		)
	
	func create_getter(entity: Node) -> Callable:
		return func(): return entity.storing_rate
	
	func create_setter(entity: Node) -> Callable:
		return func(value): entity.storing_rate = value

class TimePerUnitResource extends PropertyResource:
	func _init() -> void:
		setup(
			"time_per_unit",
			PropertyNode.Type.VALUE,
			"Time required to move one unit of distance",
			{},
			Property.Type.FLOAT,
			["speed.base.rate"]  # Updated dependency path
		)
	
	func create_getter(entity: Node) -> Callable:
		return func():
			var movement_rate = entity.get_property_value("speed.base.rate")  # Updated path
			return 1.0 / movement_rate if movement_rate > 0 else INF

class HarvestPerSecondResource extends PropertyResource:
	func _init() -> void:
		setup(
			"per_second",
			PropertyNode.Type.VALUE,
			"Amount that can be harvested in one second",
			{},
			Property.Type.FLOAT,
			["speed.base.harvesting"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func():
			return entity.get_property_value("speed.base.harvesting")
#endregion

func _init() -> void:
	setup(
		"speed",
		PropertyNode.Type.CONTAINER,
		"Speed management",
		{
			"base": create_base_config(),
			"derived": create_derived_config()
		}
	)

func create_base_config() -> PropertyResource:
	return PropertyResource.create_container(
		"base",
		"Base speed rates",
		{
			"rate": MovementRateResource.new(),  # Changed from 'movement' to 'rate'
			"harvesting": HarvestingRateResource.new(),
			"storing": StoringRateResource.new()
		}
	)

func create_derived_config() -> PropertyResource:
	return PropertyResource.create_container(
		"derived",
		"Values derived from base speeds",
		{
			"movement": PropertyResource.create_container(
				"movement",
				"Movement-related calculations",
				{
					"time_per_unit": TimePerUnitResource.new()
				}
			),
			"harvesting": PropertyResource.create_container(
				"harvesting",
				"Harvesting-related calculations",
				{
					"per_second": HarvestPerSecondResource.new()
				}
			)
		}
	)
