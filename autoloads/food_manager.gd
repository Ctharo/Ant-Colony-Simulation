extends Node

func spawn_foods(num: int) -> Array[Food]:
	var foods: Array[Food]
	for i in range(num):
		foods.append(spawn_food())
	return foods

func spawn_food() -> Food:
	var food := preload("res://entities/food/food.tscn").instantiate()
	food.add_to_group("food")
	return food

func get_all() -> Foods:
	var f: Foods = Foods.new([] as Array[Food])
	for food in get_tree().get_nodes_in_group("food"):
		if food is Food:
			f.append(food)
	return f
