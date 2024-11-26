extends Node


func start_colonies(enable: bool = true) -> Result:
	var colonies: Colonies = get_all()
	for colony: Colony in colonies:
		colony.set_physics_process(enable)
		colony.set_process(enable)
	return Result.new()
	
func spawn_colony() -> Colony:
	var colony: Colony = Colony.new()
	add_child(colony)
	colony.set_physics_process(false)
	colony.set_process(false)
	add_to_group("colony")
	return colony

func get_all() -> Colonies:
	var colonies: Colonies = Colonies.new()
	for colony in get_tree().get_nodes_in_group("colony"):
		if colony is Colony:
			colonies.append(colony)
	return colonies
