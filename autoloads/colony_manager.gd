extends Node
## ColonyManager - Manages colony spawning, tracking, and lifecycle

signal colony_spawned(colony: Colony)
signal colony_removed(colony: Colony)

#region Constants
const MAX_COLONIES := 10
#endregion

#region Member Variables
var colonies: Array[Colony] = []
var logger: iLogger
var _colony_container: Node2D
#endregion

#region Initialization
func _init() -> void:
	logger = iLogger.new("colony_manager", DebugLogger.Category.ENTITY)


func _ready() -> void:
	add_to_group("colony_manager")
#endregion

#region Colony Container Management
## Sets the container node where colonies will be added
func set_colony_container(container: Node2D) -> void:
	_colony_container = container
	logger.debug("Colony container set: %s" % container.name if container else "null")


## Gets the colony container, finding it if not already set
func get_colony_container() -> Node2D:
	if is_instance_valid(_colony_container):
		return _colony_container

	var sandbox := get_tree().get_first_node_in_group("sandbox")
	if sandbox and sandbox.has_node("ColonyContainer"):
		_colony_container = sandbox.get_node("ColonyContainer")
		return _colony_container

	var root := get_tree().current_scene
	if root and root.has_node("ColonyContainer"):
		_colony_container = root.get_node("ColonyContainer")
		return _colony_container

	logger.warn("No ColonyContainer found in scene tree")
	return null
#endregion

#region Colony Management
## Start or stop all colonies
func start_colonies(enable: bool = true) -> Result:
	logger.debug("Starting all colonies: %s" % enable)
	var result := Result.new()

	for colony in colonies:
		var colony_result := start_colony(colony, enable)
		if colony_result.is_error():
			result = colony_result
			logger.error("Failed to start colony: %s" % colony_result.error_message)
			break

	return result


## Start or stop a specific colony
func start_colony(colony: Colony, enable: bool = true) -> Result:
	if not colony:
		return Result.new(Result.ErrorType.INVALID_ARGUMENT, "Colony is null")

	if not colonies.has(colony):
		return Result.new(Result.ErrorType.INVALID_ARGUMENT, "Colony not managed by this manager")

	colony.set_physics_process(enable)
	colony.set_process(enable)

	logger.debug("Colony %s %s" % [colony.name, "started" if enable else "stopped"])
	return Result.new()


## Spawn multiple colonies
func spawn_colonies(count: int = 1, profile: ColonyProfile = null) -> Colonies:
	var new_colonies := Colonies.new()

	if colonies.size() + count > MAX_COLONIES:
		logger.warn("Cannot spawn %d colonies - would exceed maximum of %d" % [count, MAX_COLONIES])
		count = MAX_COLONIES - colonies.size()

	for i in range(count):
		var colony := spawn_colony(profile)
		if colony:
			new_colonies.append(colony)

	return new_colonies


## Spawn a single colony with the specified profile
func spawn_colony(profile: ColonyProfile = null) -> Colony:
	if colonies.size() >= MAX_COLONIES:
		logger.warn("Cannot spawn colony - maximum of %d reached" % MAX_COLONIES)
		return null

	var colony: Colony = load("res://entities/colony/colony.tscn").instantiate() as Colony
	if not colony:
		logger.error("Failed to instantiate colony scene")
		return null

	var colony_profile: ColonyProfile = profile
	if not colony_profile:
		colony_profile = SettingsManager.get_colony_profile()

	if not colony_profile:
		logger.warn("No colony profile available, using standard")
		colony_profile = ColonyProfile.create_standard()

	colony.init_colony_profile(colony_profile)

	colonies.append(colony)
	colony.name = "Colony_%d" % colonies.size()
	colony.add_to_group("colony")

	var container := get_colony_container()
	if container:
		container.add_child(colony)
		_setup_colony_sandbox_reference(colony, container)
		logger.info("Spawned colony: %s with profile %s" % [colony.name, colony_profile.name])
	else:
		logger.error("No colony container - colony created but not added to scene tree")

	colony_spawned.emit(colony)
	return colony


## Spawn colony at a specific world position
func spawn_colony_at(world_position: Vector2, profile: ColonyProfile = null) -> Colony:
	var colony := spawn_colony(profile)
	if colony:
		colony.global_position = world_position
	return colony


## Sets up the sandbox reference for a colony
func _setup_colony_sandbox_reference(colony: Colony, container: Node2D) -> void:
	var sandbox := container.get_parent()
	if sandbox and sandbox.has_node("AntContainer"):
		colony.sandbox = sandbox


## Remove a colony from management
func remove_colony(colony: Colony) -> Result:
	if not colony:
		return Result.new(Result.ErrorType.INVALID_ARGUMENT, "Colony is null")

	if not colonies.has(colony):
		return Result.new(Result.ErrorType.NOT_FOUND, "Colony not managed by this manager")

	colonies.erase(colony)
	colony_removed.emit(colony)
	colony.queue_free()

	logger.info("Removed colony: %s" % colony.name)
	return Result.new()


## Remove all colonies
func delete_all() -> void:
	for colony in colonies.duplicate():
		remove_colony(colony)


## Get all managed colonies
func get_all() -> Array[Colony]:
	return colonies.duplicate()


## Get colony by name
func get_by_name(colony_name: String) -> Colony:
	for colony in colonies:
		if colony.name == colony_name:
			return colony
	return null
#endregion
