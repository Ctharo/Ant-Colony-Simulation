extends Node

func get_all() -> Ants:
	var ants: Ants = Ants.new([])
	for ant in get_tree().get_nodes_in_group("ant"):
		if ant is Ant:
			ants.append(ant)
	return ants
