extends Node

func get_all() -> Foods:
	var f: Foods = Foods.new()
	for food in get_tree().get_nodes_in_group("food"):
		if food is Food:
			f.append(food)
	return f
