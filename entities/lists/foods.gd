class_name Foods
extends Iterator

var mass: float : get = get_mass

func _init(initial_foods: Array[Food] = []):
	super._init()
	for food in initial_foods:
		self.append(food)

## Add food by mass to foods, return total stored mass
func add_food(mass_to_add: float) -> float:
	var food: Food = Food.new(mass_to_add)
	append(food)
	print("Food added")
	return get_mass()

func mark_as_carried() -> void:
	for food in elements:
		food.carried = true

func get_mass() -> float:
	var _mass: float = 0.0
	for food in self:
		_mass += food.mass
	return _mass

func locations() -> Array[Vector2]:
	return [] as Array[Vector2]

func as_array() -> Array[Food]:
	var f: Array[Food]
	for food in elements:
		f.append(food)
	return f

static func are_available() -> Foods:
	var f: Foods = Foods.new()
	for food: Food in all():
		if food.is_available:
			f.append(food)
	return f

static func in_range(location: Vector2, _range: float, available_foods: bool = false) -> Foods:
	var f: Foods = Foods.new()
	for food: Food in Foods.all():
		if food.get_position().distance_to(location) <= _range:
			if available_foods == food.is_available:
				f.append(food)
			elif not available_foods:
				f.append(food)
			else:
				continue
	return f

static func nearest_food(location: Vector2, _range: float, available_foods: bool = false) -> Food:
	var nearest: Food
	var distance: float = INF
	for food: Food in Foods.in_range(location, _range, available_foods):
		var d: float = food.global_position.distance_to(location)
		if d < distance:
			nearest = food
			distance = d
	return nearest

static func all() -> Foods:
	return FoodManager.get_all()
