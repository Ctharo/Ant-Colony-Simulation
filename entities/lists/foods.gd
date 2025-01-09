class_name Foods
extends Iterator

## Signal emitted when foods are added or removed
signal foods_changed

## Current count of food units
var count: int :
	get:
		return len(elements)

var mass :
	get:
		return float(count)

func _init(initial_foods: Array[Food] = []) -> void:
	super._init()
	for food in initial_foods:
		append(food)

## Add a single food unit
func add_food(food: Food) -> void:
	# Only the first food should be visible when carried
	if count > 0:
		food.hide_visual()
	append(food)
	foods_changed.emit()

## Remove a single food unit
func remove_food() -> Food:
	if count == 0:
		return null
		
	var food = elements.pop_back()
	foods_changed.emit()
	return food

## Mark all food units as carried
func mark_as_carried() -> void:
	for food in elements:
		food.carried = true
		# Only first food should be visible
		food.visible = (food == elements[0]) if not elements.is_empty() else false

## Get array of food unit locations
func locations() -> Array[Vector2]:
	var locs: Array[Vector2] = []
	for food in elements:
		locs.append(food.global_position)
	return locs

## Convert to array of Food objects
func as_array() -> Array[Food]:
	var foods: Array[Food] = []
	for food in elements:
		foods.append(food)
	return foods

## Get all available food units
static func are_available() -> Foods:
	var foods := Foods.new()
	for food in all():
		if food.is_available:
			foods.append(food)
	return foods

## Get food units within range of a location
static func in_range(location: Vector2, p_range: float, available_only: bool = false) -> Foods:
	var foods := Foods.new()
	for food in Foods.all():
		if food.global_position.distance_to(location) <= p_range:
			if available_only:
				if food.is_available:
					foods.append(food)
			else:
				foods.append(food)
	return foods

## Get nearest food unit to a location
static func nearest_food(location: Vector2, p_range: float, available_only: bool = false) -> Food:
	var nearest: Food
	var distance := INF
	for food in Foods.in_range(location, p_range, available_only):
		var d : float = food.global_position.distance_to(location)
		if d < distance:
			nearest = food
			distance = d
	return nearest

## Get all food units in scene
static func all() -> Foods:
	return FoodManager.get_all()
