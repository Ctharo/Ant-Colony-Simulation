extends Node


func spawn_foods(num: int) -> void:
	for i in range(num):
		spawn_food()

func spawn_food() -> void:

	var food := Food.new()
	food.add_to_group("food")
	add_child(food)

func get_all() -> Foods:
	var f: Foods = Foods.new([] as Array[Food])
	for food in get_tree().get_nodes_in_group("food"):
		if food is Food:
			f.append(food)
	return f
