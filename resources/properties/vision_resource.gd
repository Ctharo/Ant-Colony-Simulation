class_name VisionResource
extends PropertyResource
## Resource for managing vision-related properties

#region Inner Classes
class RangeResource extends PropertyResource:
	func _init() -> void:
		setup(
			"range",
			PropertyNode.Type.VALUE,
			"Maximum range at which the entity can see",
			{},
			Property.Type.FLOAT
		)
	
	func create_getter(entity: Node) -> Callable:
		return func(): return entity.get_property_value("vision.base.range")
	
	func create_setter(entity: Node) -> Callable:
		return func(value): entity.set_property_value("vision.base.range", value)

class AntsInRangeResource extends PropertyResource:
	func _init() -> void:
		setup(
			"list",
			PropertyNode.Type.VALUE,
			"Ants within vision range",
			{},
			Property.Type.ANTS,
			["vision.base.range"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func(): 
			var range = entity.get_property_value("vision.base.range")
			return Ants.in_range(entity, range)

class AntsCountResource extends PropertyResource:
	func _init() -> void:
		setup(
			"count",
			PropertyNode.Type.VALUE,
			"Number of ants within vision range",
			{},
			Property.Type.INT,
			["vision.ants.list"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func():
			var ants = entity.get_property_value("vision.ants.list")
			return ants.size() if ants else 0

class FoodsInRangeResource extends PropertyResource:
	func _init() -> void:
		setup(
			"list",
			PropertyNode.Type.VALUE,
			"Food items within vision range",
			{},
			Property.Type.FOODS,
			["vision.base.range"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func(): 
			var range = entity.get_property_value("vision.base.range")
			return Foods.in_range(entity.global_position, range, true)

class NearestFoodResource extends PropertyResource:
	func _init() -> void:
		setup(
			"object",
			PropertyNode.Type.VALUE,
			"Nearest visible food item",
			{},
			Property.Type.FOOD,
			["vision.base.range"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func():
			var range = entity.get_property_value("vision.base.range")
			return Foods.nearest_food(entity.global_position, range, true)

class NearestFoodPositionResource extends PropertyResource:
	func _init() -> void:
		setup(
			"position",
			PropertyNode.Type.VALUE,
			"Nearest visible food item position",
			{},
			Property.Type.VECTOR2,
			["vision.foods.nearest.object"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func():
			var food = entity.get_property_value("vision.foods.nearest.object")
			return food.global_position if food else Vector2.ZERO

class FoodsCountResource extends PropertyResource:
	func _init() -> void:
		setup(
			"count",
			PropertyNode.Type.VALUE,
			"Number of food items within vision range",
			{},
			Property.Type.INT,
			["vision.foods.list"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func():
			var foods = entity.get_property_value("vision.foods.list")
			return foods.size() if foods else 0

class FoodsMassResource extends PropertyResource:
	func _init() -> void:
		setup(
			"mass",
			PropertyNode.Type.VALUE,
			"Total mass of food within vision range",
			{},
			Property.Type.FLOAT,
			["vision.foods.list"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func():
			var foods = entity.get_property_value("vision.foods.list")
			return foods.get_mass() if foods else 0.0
#endregion

func _init() -> void:
	setup(
		"vision",
		PropertyNode.Type.CONTAINER,
		"Vision management",
		{
			"base": create_base_config(),
			"ants": create_ants_config(),
			"foods": create_foods_config()
		}
	)

func create_base_config() -> PropertyResource:
	return PropertyResource.create_container(
		"base",
		"Base vision attributes",
		{
			"range": RangeResource.new()
		}
	)

func create_ants_config() -> PropertyResource:
	return PropertyResource.create_container(
		"ants",
		"Properties related to ants in vision range",
		{
			"list": AntsInRangeResource.new(),
			"count": AntsCountResource.new()
		}
	)

func create_foods_config() -> PropertyResource:
	return PropertyResource.create_container(
		"foods",
		"Properties related to food in vision range",
		{
			"list": FoodsInRangeResource.new(),
			"nearest": PropertyResource.create_container(
				"nearest",
				"Nearest food item to entity",
				{
					"object": NearestFoodResource.new(),
					"position": NearestFoodPositionResource.new()
				}
			),
			"count": FoodsCountResource.new(),
			"mass": FoodsMassResource.new()
		}
	)
