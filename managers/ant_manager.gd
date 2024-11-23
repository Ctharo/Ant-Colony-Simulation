extends BaseNode


func start_ants(enable: bool = true) -> Result:
	var ants: Ants = get_all()
	for ant: Ant in ants:
		ant.set_physics_process(enable)
		ant.set_process(enable)
	_debug("Ant processes started")
	return Result.new()

func spawn_ants(num: int = 1) -> Array[Ant]:
	var array: Array[Ant] = []
	for i in range(num):
		array.append(spawn_ant())
	return array

func spawn_ant() -> Ant:
	var ant: Ant = Ant.new()
	add_child(ant)
	ant.set_physics_process(false)
	ant.set_process(false)
	ant.add_to_group("ant")
	return ant

func get_all() -> Ants:
	var ants: Ants = Ants.new()
	for ant in get_tree().get_nodes_in_group("ant"):
		if ant is Ant:
			ants.append(ant)
	return ants
