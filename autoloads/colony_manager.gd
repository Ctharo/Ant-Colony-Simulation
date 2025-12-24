extends Node

signal colony_spawned(colony: Colony)
signal colony_removed(colony: Colony)

# Configuration constants
const MAX_COLONIES := 10

# Maintain list of active colonies
var colonies: Array[Colony] = []
var logger: iLogger

#region Initialization
func _init() -> void:
	logger = iLogger.new("colony_manager", DebugLogger.Category.ENTITY)

func _ready() -> void:
	# Ensure we're in colony group for easy access
	add_to_group("colony_manager")
#endregion

#region Colony Management
## Start or stop all colonies
func start_colonies(enable: bool = true) -> Result:
	logger.debug("Starting all colonies: %s" % enable)
	var result := Result.new()

	for colony in colonies:
		var colony_result = start_colony(colony, enable)
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

	# Check if we would exceed max colonies
	if colonies.size() + count > MAX_COLONIES:
		logger.warn("Cannot spawn %d colonies - would exceed maximum of %d" % [count, MAX_COLONIES])
		count = MAX_COLONIES - colonies.size()

	for i in range(count):
		var colony = spawn_colony(profile)
		if colony:
			new_colonies.append(colony)

	return new_colonies

## Spawn a single colony with the specified profile
## If no profile provided, uses the one from SettingsManager (source of truth)
func spawn_colony(profile: ColonyProfile = null) -> Colony:
	if colonies.size() >= MAX_COLONIES:
		logger.warn("Cannot spawn colony - maximum of %d reached" % MAX_COLONIES)
		return null

	# Create new colony instance
	var colony: Colony = load("res://entities/colony/colony.tscn").instantiate() as Colony
	if not colony:
		logger.error("Failed to instantiate colony scene")
		return null

	# Use provided profile or get from SettingsManager (source of truth)
	var colony_profile: ColonyProfile = profile
	if not colony_profile:
		colony_profile = SettingsManager.get_colony_profile()
	
	# Fallback to standard if still null
	if not colony_profile:
		logger.warn("No colony profile available, using standard")
		colony_profile = ColonyProfile.create_standard()

	# Apply profile to colony
	colony.init_colony_profile(colony_profile)

	# Add to tracking
	colonies.append(colony)
	colony.name = "Colony_%d" % colonies.size()
	colony_spawned.emit(colony)
	colony.add_to_group("colony")

	logger.info("Spawned new colony: %s with profile %s" % [colony.name, colony_profile.name])
	return colony

## Spawn colony at a specific position
func spawn_colony_at(position: Vector2, profile: ColonyProfile = null) -> Colony:
	var colony = spawn_colony(profile)
	if colony:
		colony.global_position = position
	return colony

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
