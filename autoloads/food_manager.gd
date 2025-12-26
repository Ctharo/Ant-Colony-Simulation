extends Node
## FoodManager - Manages food spawning, tracking, and lifecycle

signal food_spawned(food: Food)
signal food_removed(food: Food)

#region Constants
const CLUSTER_SPREAD := 50.0
const MIN_FOOD_SPACING := 8.0
#endregion

#region Member Variables
var logger: iLogger
var _food_container: Node2D
#endregion

#region Lifecycle
func _init() -> void:
	logger = iLogger.new("food_manager", DebugLogger.Category.ENTITY)


func _ready() -> void:
	add_to_group("food_manager")
#endregion

#region Container Management
## Sets the container node where food will be added
func set_food_container(container: Node2D) -> void:
	_food_container = container
	logger.debug("Food container set: %s" % (container.name if container else "null"))


## Gets the food container, finding it if not already set
func get_food_container() -> Node2D:
	if is_instance_valid(_food_container):
		return _food_container
	
	var sandbox := get_tree().get_first_node_in_group("sandbox")
	if sandbox and sandbox.has_node("FoodContainer"):
		_food_container = sandbox.get_node("FoodContainer")
		return _food_container
	
	var root := get_tree().current_scene
	if root and root.has_node("FoodContainer"):
		_food_container = root.get_node("FoodContainer")
		return _food_container
	
	logger.warn("No FoodContainer found in scene tree")
	return null
#endregion

#region Spawning
## Spawns a cluster of food around a center position
func spawn_food_cluster(center: Vector2, count: int, spread: float = CLUSTER_SPREAD) -> Array[Food]:
	var foods: Array[Food] = []
	var container := get_food_container()
	
	if not container:
		logger.error("Cannot spawn food cluster - no container available")
		return foods
	
	for i in range(count):
		var food := _create_food()
		if not food:
			continue
		
		var offset := _get_cluster_offset(spread)
		food.global_position = center + offset
		
		container.add_child(food)
		foods.append(food)
		food_spawned.emit(food)
	
	logger.debug("Spawned food cluster of %d at %s" % [foods.size(), center])
	return foods


## Spawns food at specific positions
func spawn_foods_at(positions: Array[Vector2]) -> Array[Food]:
	var foods: Array[Food] = []
	var container := get_food_container()
	
	if not container:
		logger.error("Cannot spawn foods - no container available")
		return foods
	
	for pos in positions:
		var food := _create_food()
		if not food:
			continue
		
		food.global_position = pos
		container.add_child(food)
		foods.append(food)
		food_spawned.emit(food)
	
	return foods


## Spawns multiple food items (legacy method - adds to container)
func spawn_foods(num: int) -> Array[Food]:
	var foods: Array[Food] = []
	var container := get_food_container()
	
	for i in range(num):
		var food := _create_food()
		if food:
			if container:
				container.add_child(food)
			foods.append(food)
			food_spawned.emit(food)
	
	return foods


## Spawns a single food item (legacy method - does NOT add to tree for backwards compatibility)
func spawn_food() -> Food:
	var food := _create_food()
	if food:
		food_spawned.emit(food)
	return food


## Creates a food instance without adding to scene tree
func _create_food() -> Food:
	var food: Food = preload("res://entities/food/food.tscn").instantiate() as Food
	if not food:
		logger.error("Failed to instantiate food scene")
		return null
	
	food.add_to_group("food")
	return food


## Gets a random offset for cluster spawning
func _get_cluster_offset(spread: float) -> Vector2:
	var angle := randf() * TAU
	var distance := randf() * spread
	return Vector2(cos(angle), sin(angle)) * distance
#endregion

#region Food Management
## Removes a food item
func remove_food(food: Food) -> void:
	if not is_instance_valid(food):
		return
	
	food_removed.emit(food)
	food.queue_free()


## Removes all food
func clear_all() -> void:
	for food in get_all().elements:
		remove_food(food)


## Gets all food in the scene
func get_all() -> Foods:
	var foods := Foods.new([] as Array[Food])
	for food in get_tree().get_nodes_in_group("food"):
		if food is Food:
			foods.append(food)
	return foods


## Gets all available (not carried/targeted) food
func get_available() -> Foods:
	var foods := Foods.new([] as Array[Food])
	for food in get_tree().get_nodes_in_group("food"):
		if food is Food and food.is_available:
			foods.append(food)
	return foods


## Gets food within range of a position
func get_in_range(position: Vector2, range_distance: float, available_only: bool = false) -> Foods:
	var foods := Foods.new([] as Array[Food])
	var source := get_available() if available_only else get_all()
	
	for food in source.elements:
		if food.global_position.distance_to(position) <= range_distance:
			foods.append(food)
	
	return foods


## Gets the nearest food to a position
func get_nearest(position: Vector2, range_distance: float, available_only: bool = false) -> Food:
	var nearest: Food = null
	var nearest_distance := INF
	
	var source := get_available() if available_only else get_all()
	
	for food in source.elements:
		var distance: float = food.global_position.distance_to(position)
		if distance <= range_distance and distance < nearest_distance:
			nearest = food
			nearest_distance = distance
	
	return nearest
#endregion
