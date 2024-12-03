class_name OlfactionResource
extends PropertyResource
## Resource for managing olfaction-related properties

#region Inner Classes
class RangeResource extends PropertyResource:
	func _init() -> void:
		setup(
			"range",
			PropertyNode.Type.VALUE,
			"Maximum range at which to smell things",
			{},
			Property.Type.FLOAT
		)
	
	func create_getter(entity: Node) -> Callable:
		return func(): return entity.get_property_value("olfaction.base.range")
	
	func create_setter(entity: Node) -> Callable:
		return func(value): entity.range = value

class PheromoneListResource extends PropertyResource:
	func _init() -> void:
		setup(
			"list",
			PropertyNode.Type.VALUE,
			"All pheromones within olfactory range",
			{},
			Property.Type.PHEROMONES,
			["olfaction.base.range"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func(): return entity._get_pheromones_in_range()

class PheromoneCountResource extends PropertyResource:
	func _init() -> void:
		setup(
			"count",
			PropertyNode.Type.VALUE,
			"Count of all pheromones within range",
			{},
			Property.Type.INT,
			["olfaction.pheromones.list"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func(): 
			var pheromones = entity.get_property_value("olfaction.pheromones.list")
			return pheromones.size() if pheromones else 0

class FoodPheromoneListResource extends PropertyResource:
	func _init() -> void:
		setup(
			"list",
			PropertyNode.Type.VALUE,
			"Food pheromones within range",
			{},
			Property.Type.PHEROMONES,
			["olfaction.base.range"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func(): return entity._get_food_pheromones_in_range()

class FoodPheromoneCountResource extends PropertyResource:
	func _init() -> void:
		setup(
			"count",
			PropertyNode.Type.VALUE,
			"Count of food pheromones within range",
			{},
			Property.Type.INT,
			["olfaction.pheromones.food.list"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func():
			var pheromones = entity.get_property_value("olfaction.pheromones.food.list")
			return pheromones.size() if pheromones else 0

class HomePheromoneListResource extends PropertyResource:
	func _init() -> void:
		setup(
			"list",
			PropertyNode.Type.VALUE,
			"Home pheromones within range",
			{},
			Property.Type.PHEROMONES,
			["olfaction.base.range"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func(): return entity._get_home_pheromones_in_range()

class HomePheromoneCountResource extends PropertyResource:
	func _init() -> void:
		setup(
			"count",
			PropertyNode.Type.VALUE,
			"Count of home pheromones within range",
			{},
			Property.Type.INT,
			["olfaction.pheromones.home.list"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func():
			var pheromones = entity.get_property_value("olfaction.pheromones.home.list")
			return pheromones.size() if pheromones else 0


#endregion

func _init() -> void:
	setup(
		"olfaction",
		PropertyNode.Type.CONTAINER,
		"Olfaction management",
		{
			"base": create_base_config(),
			"pheromones": create_pheromones_config()
		}
	)

func create_base_config() -> PropertyResource:
	return PropertyResource.create_container(
		"base",
		"Base olfaction attributes",
		{
			"range": RangeResource.new()
		}
	)

func create_pheromones_config() -> PropertyResource:
	return PropertyResource.create_container(
		"pheromones",
		"Information about pheromones within range",
		{
			"list": PheromoneListResource.new(),
			"count": PheromoneCountResource.new(),
			"food": create_food_config(),
			"home": create_home_config()
		}
	)



func create_food_config() -> PropertyResource:
	return PropertyResource.create_container(
		"food",
		"Food-related pheromone information",
		{
			"list": FoodPheromoneListResource.new(),
			"count": FoodPheromoneCountResource.new(),
		}
	)

func create_home_config() -> PropertyResource:
	return PropertyResource.create_container(
		"home",
		"Home-related pheromone information",
		{
			"list": HomePheromoneListResource.new(),
			"count": HomePheromoneCountResource.new(),
		}
	)
