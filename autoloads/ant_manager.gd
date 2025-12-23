# AntManager.gd
extends Node

#region Signals
signal ant_spawned(ant: Ant, colony: Colony)
signal ant_removed(ant: Ant)
#endregion

#region Member Variables
var logger: iLogger
var ants: Array[Ant] = []
var ants_created: int = 0

## Current number of ants being managed
var current_ant_count: int:
	get:
		return ants.size()
#endregion

func _init() -> void:
	logger = iLogger.new("ant_manager", DebugLogger.Category.PROGRAM)

## Spawns multiple ants at a colony
## Returns an array of spawned ants
func spawn_ants(colony: Colony, num: int = 1, profile: AntProfile = null) -> Array[Ant]:
	if not colony:
		logger.error("Cannot spawn ants - invalid colony provided")
		return []

	var spawned_ants: Array[Ant] = []

	# Use default profile if none specified
	var spawn_profile := profile
	if not spawn_profile and colony.ant_profiles.size() > 0:
		spawn_profile = colony.ant_profiles[0]

	if not spawn_profile:
		logger.error("No ant profile available for spawning")
		return spawned_ants

	for i in range(num):
		var ant = _create_ant(spawn_profile)
		if ant:
			_initialize_ant_position(ant, colony)
			_register_ant(ant, colony)
			spawned_ants.append(ant)

	if spawned_ants.size() > 0:
		logger.info("Spawned %s %s at colony %s" % [
			spawned_ants.size(),
			"ant" if spawned_ants.size() == 1 else "ants",
			colony.name
		])

	return spawned_ants

## Creates a new ant instance with the given profile
func _create_ant(profile: AntProfile) -> Ant:
	var ant: Ant = preload("res://entities/ant/ant.tscn").instantiate()
	if not ant:
		logger.error("Failed to instantiate ant scene")
		return null

	# Set basic properties
	ants_created += 1
	ant.id = ants_created
	ant.name = "Ant%s" % ant.id

	# Store profile reference for _ready() to use
	# Note: We set these properties here, but init_profile() will be called
	# again in _ready() after the ant enters the scene tree, which is when
	# influence_manager becomes available via @onready
	ant.profile = profile
	ant.movement_rate = profile.movement_rate
	ant.vision_range = profile.vision_range
	ant.pheromones = profile.pheromones
	ant.role = profile.name.to_snake_case()

	return ant

## Initializes ant position relative to colony
func _initialize_ant_position(ant: Ant, colony: Colony) -> void:
	randomize()
	var spawn_offset := Vector2(
		randf_range(-15, 15),
		randf_range(-15, 15)
	)
	ant.global_position = colony.global_position + spawn_offset
	ant.global_rotation = randf_range(-PI, PI)

## Registers ant with necessary systems
func _register_ant(ant: Ant, colony: Colony) -> void:
	# Add to tracking
	ants.append(ant)
	ant.add_to_group("ant")

	# Add to colony - this adds to scene tree AND sets colony reference
	# colony.add_ant() calls add_child() which triggers _ready(),
	# allowing influence_manager to initialize properly
	colony.add_ant(ant)

	# Connect signals
	ant.died.connect(_on_ant_died)

	# Emit spawn signal
	ant_spawned.emit(ant, colony)

## Removes an ant from the simulation
func remove_ant(ant: Ant) -> void:
	if not ant or not ants.has(ant):
		return

	# Stop processing
	ant.set_physics_process(false)
	ant.set_process(false)

	# Remove from tracking
	ants.erase(ant)
	ant_removed.emit(ant)

	# Cleanup systems
	HeatmapManager.unregister_entity(ant)
	EvaluationSystem.cleanup_entity(ant)

	# Delete node
	ant.queue_free()
	logger.debug("Removed ant: %s" % ant.name)

## Signal handler for ant death
func _on_ant_died(ant: Ant) -> void:
	remove_ant(ant)

## Enables/disables ant processing
func start_ant(ant: Ant, enable: bool = true) -> Result:
	if not ant:
		return Result.new(Result.ErrorType.INVALID_ARGUMENT, "Ant is null")
	if not ants.has(ant):
		return Result.new(Result.ErrorType.INVALID_ARGUMENT, "Ant not managed by AntManager")

	ant.set_physics_process(enable)
	ant.set_process(enable)
	logger.debug("Ant %s %s" % [ant.name, "started" if enable else "stopped"])

	return Result.new()

## Enables/disables all ant processing
func start_ants(enable: bool = true) -> Result:
	var count := 0
	for ant in ants:
		ant.set_physics_process(enable)
		ant.set_process(enable)
		count += 1

	logger.info("Ant processing %s for %s %s" % [
		"enabled" if enable else "disabled",
		count,
		"ant" if count == 1 else "ants"
	])

	return Result.new()

## Returns all ants for a specific colony
func by_colony(colony: Colony) -> Array[Ant]:
	var colony_ants: Array[Ant] = []
	for ant in ants:
		if ant.colony == colony:
			colony_ants.append(ant)
	return colony_ants

## Returns all managed ants
func get_all() -> Array[Ant]:
	return ants.duplicate()

## Removes all ants
func delete_all() -> void:
	for ant in ants.duplicate():
		remove_ant(ant)
