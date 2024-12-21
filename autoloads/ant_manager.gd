extends Node

signal ant_removed(ant: Ant)

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

func spawn_ants(colony: Colony, num: int = 1, physics_at_spawn: bool = false) -> Array[Ant]:
	var array: Array[Ant] = []
	for i in range(num):
		array.append(spawn_ant(colony))
	for ant in array:
		ant.set_physics_process(physics_at_spawn)
		ant.set_process(physics_at_spawn)
	return array

func spawn_ant(colony: Colony) -> Ant:
	var ant: Ant = preload("res://entities/ant/ant.tscn").instantiate() as Ant
	ant.set_colony(colony)
	AntManager.ants_created += 1
	ant.id = AntManager.ants_created
	ant.name = "Ant" + str(ant.id)
	add_child(ant)
	ant.set_physics_process(false)
	ant.set_process(false)
	AntManager.ants.append(ant)
	ant.add_to_group("ant")
	ant.died.connect(AntManager._on_ant_died)
	return ant

func by_colony(colony: Colony) -> Ants:
	var all = AntManager.get_all()
	var by_col: Ants = Ants.new()
	for ant: Ant in all:
		if ant.colony == colony:
			by_col.append(ant)
	return by_col

func get_all() -> Ants:
	var _ants: Ants = Ants.new()
	for ant in AntManager.ants:
		if ant != null:
			_ants.append(ant)
	return _ants

func _on_ant_died(ant: Ant) -> void:
	AntManager.remove_ant(ant)

func start_ant(ant: Ant, enable: bool = true) -> void:
	if not ant:
		return Result.new(Result.ErrorType.INVALID_ARGUMENT, "Ant is null")

	if not AntManager.ants.has(ant):
		return Result.new(Result.ErrorType.INVALID_ARGUMENT, "Ant not managed by this manager")

	ant.set_physics_process(enable)
	ant.set_process(enable)

	logger.debug("Ant %s %s" % [ant.name, "started" if enable else "stopped"])
	return Result.new()

func remove_ant(ant: Ant) -> void:
	if not ant:
		return Result.new(Result.ErrorType.INVALID_ARGUMENT, "Ant is null")

	if not ants.has(ant):
		return Result.new(Result.ErrorType.INVALID_ARGUMENT, "Ant not managed by this manager")

	# Stop ant processing
	AntManager.start_ant(ant, false)

	# Remove from tracking
	AntManager.ants.erase(ant)
	AntManager.ant_removed.emit(ant)

	# Clean up node
	ant.queue_free()

	logger.debug("Removed ant: %s" % ant.name)
	return Result.new()

func delete_all() -> void:
	for ant in AntManager.ants.duplicate():  # Duplicate array to avoid modification during iteration
		remove_ant(ant)
