extends Node

func get_all() -> Colonies:
	var colonies: Colonies = Colonies.new()
	for colony in get_tree().get_nodes_in_group("colony"):
		if colony is Colony:
			colonies.append(colony)
	return colonies
