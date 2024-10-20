extends Node

func get_all() -> Pheromones:
	var pheromones: Pheromones = Pheromones.new([])
	for pheromone in get_tree().get_nodes_in_group("pheromone"):
		if pheromone is Pheromone:
			pheromones.append(pheromone)
	return pheromones
