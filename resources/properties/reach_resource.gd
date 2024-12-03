class_name ReachResource
extends PropertyResource
## Resource for managing reach-related properties

#region Inner Classes
class RangeResource extends PropertyResource:
	func _init() -> void:
		setup(
			"range",
			PropertyNode.Type.VALUE,
			"Maximum distance the entity can reach to interact with objects",
			{},
			Property.Type.FLOAT
		)
	
	func create_getter(entity: Node) -> Callable:
		return func(): return entity.get_property_value("reach.base.range")
	
	func create_setter(entity: Node) -> Callable:
		return func(value): 
			if value <= 0:
				logger.error("Attempted to set reach.range to non-positive value -> Action not allowed")
				return
			entity.range = value

class FoodsInRangeResource extends PropertyResource:
	func _init() -> void:
		setup(
			"list",
			PropertyNode.Type.VALUE,
			"Food items within reach range",
			{},
			Property.Type.FOODS,
			["reach.base.range"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func(): 
			return Foods.in_range(entity.global_position, entity.get_property_value("reach.range"))

class FoodsCountResource extends PropertyResource:
	func _init() -> void:
		setup(
			"count",
			PropertyNode.Type.VALUE,
			"Number of food items within reach range",
			{},
			Property.Type.INT,
			["reach.foods.list"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func():
			var foods = entity.get_property_value("reach.foods.list")
			return foods.size() if foods else 0

class FoodsMassResource extends PropertyResource:
	func _init() -> void:
		setup(
			"mass",
			PropertyNode.Type.VALUE,
			"Total mass of food within reach range",
			{},
			Property.Type.FLOAT,
			["reach.foods.list"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func():
			var foods = entity.get_property_value("reach.foods.list")
			if not foods:
				return 0.0
			var total_mass: float = 0.0
			for food in foods:
				total_mass += food.mass
			return total_mass
#endregion

func _init() -> void:
	setup(
		"reach",
		PropertyNode.Type.CONTAINER,
		"Reach management",
		{
			"range": RangeResource.new(),
			"foods": create_foods_config()
		}
	)

func create_foods_config() -> PropertyResource:
	return PropertyResource.create_container(
		"foods",
		"Properties related to food in reach range",
		{
			"list": FoodsInRangeResource.new(),
			"count": FoodsCountResource.new(),
			"mass": FoodsMassResource.new()
		}
	)
