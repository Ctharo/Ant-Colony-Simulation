extends BaseNode

func _init() -> void:
	log_category = DebugLogger.Category.PROGRAM
	log_from = "pheromone_manager"
	
func get_all() -> Pheromones:
	var pheromones: Pheromones = Pheromones.new()
	for pheromone in get_tree().get_nodes_in_group("pheromone"):
		if pheromone is Pheromone:
			pheromones.append(pheromone)
	return pheromones
