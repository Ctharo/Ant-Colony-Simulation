class_name Foods
extends Iterator

func _init(initial_foods: Array[Food] = []):
	super._init()
	for food in initial_foods:
		self.append(food)

## Add food by mass to foods, return total stored mass
func add_food(mass_to_add: float) -> float:
	var food: Food = Food.new(mass_to_add)
	append(food)
	return mass()

func mass() -> float:
	var _mass: float = 0.0
	for food in self:
		_mass += food.mass()
	return _mass
	
func locations() -> Array[Vector2]:
	return [] as Array[Vector2]

static func are_available() -> Foods:
	var f: Foods = Foods.new()
	for food: Food in all():
		if food.is_available():
			f.append(food)
	return f

static func in_reach(location: Vector2, reach_distance: float) -> Foods:
	var f: Foods = Foods.new()
	for food: Food in all():
		if food.get_position().distance_to(location) <= reach_distance:
			f.append(food)
	return f

static func in_view(location: Vector2, view_distance: float) -> Foods:
	var f: Foods = Foods.new()
	for food: Food in all():
		if food.get_position().distance_to(location) <= view_distance:
			f.append(food)
	return f

static func all() -> Foods:
	return FoodManager.get_all()
