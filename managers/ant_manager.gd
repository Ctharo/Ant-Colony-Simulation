extends Node
var logger: Logger
var ants: Array = []
var current_ant_count: int :
	get:
		return ants.size()
var ants_created: int = 0

func _init():
	logger = Logger.new("ant_manager", DebugLogger.Category.PROGRAM)

func start_ants(enable: bool = true) -> Result:
	var i: int = 0
	for ant in ants:
		ant.set_physics_process(enable)
		ant.set_process(enable)
		i += 1
	logger.info("Ant task tree and processes started for %s %s" % [i, "ant" if i == 1 else "ants"])
	return Result.new()

func spawn_ants(num: int = 1, physics_at_spawn: bool = false) -> Array[Ant]:
	var array: Array[Ant] = []
	for i in range(num):
		array.append(spawn_ant())
	for ant in array:
		ant.set_physics_process(physics_at_spawn)
		ant.set_process(physics_at_spawn)
	return array

func spawn_ant() -> Ant:
	var ant: Ant = preload("res://entities/ant/ant.tscn").instantiate() as Ant
	ants_created += 1
	ant.id = ants_created
	ant.name = "Ant" + str(ant.id) 
	add_child(ant)
	ant.set_physics_process(false)
	ant.set_process(false)
	ants.append(ant)
	ant.add_to_group("ant")
	ant.died.connect(_on_ant_died)
	return ant

func get_all() -> Ants:
	var ants: Ants = Ants.new()
	for ant in ants:
		if ant != null:
			ants.append(ant)
	return ants

func _on_ant_died(ant: Ant) -> void:
	if ant in ants:
		ants.erase(ant)
