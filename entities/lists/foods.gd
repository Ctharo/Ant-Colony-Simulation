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
	return get_mass()

## Removes food by mass from foods collection, returns remaining mass to remove
## If mass_to_remove is greater than available mass, removes all food and returns remaining mass
## If mass_to_remove is less than or equal to available mass, removes exact amount and returns 0
func remove_food(mass_to_remove: float) -> float:
	# Handle invalid input
	if mass_to_remove <= 0:
		return 0.0
	
	var remaining_mass: float = mass_to_remove
	var foods_to_remove: Array[Food] = []
	
	# First pass: identify foods to remove completely
	for food in elements:
		if food.mass <= remaining_mass:
			foods_to_remove.append(food)
			remaining_mass -= food.mass
		elif remaining_mass > 0:
			# Split this food item
			var new_mass: float = food.mass - remaining_mass
			food.mass = new_mass
			remaining_mass = 0
			break
	
	# Remove the identified foods
	for food in foods_to_remove:
		elements.erase(food)
	
	return remaining_mass
	

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
