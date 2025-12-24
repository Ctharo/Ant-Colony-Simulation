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
func spawn_colonies(count: int = 1, profile_type: String = "standard") -> Colonies:
	var new_colonies := Colonies.new()

	# Check if we would exceed max colonies
	if colonies.size() + count > MAX_COLONIES:
		logger.warn("Cannot spawn %d colonies - would exceed maximum of %d" % [count, MAX_COLONIES])
		count = MAX_COLONIES - colonies.size()

	for i in range(count):
		var colony = spawn_colony(profile_type)
		if colony:
			new_colonies.append(colony)

	return new_colonies

## Spawn a single colony with the specified profile type
func spawn_colony(profile_type: String = "standard") -> Colony:
	if colonies.size() >= MAX_COLONIES:
		logger.warn("Cannot spawn colony - maximum of %d reached" % MAX_COLONIES)
		return null

	# Create new colony instance
	var colony: Colony = load("res://entities/colony/colony.tscn").instantiate() as Colony
	if not colony:
		logger.error("Failed to instantiate colony scene")
		return null

	# Create appropriate profile based on type
	var profile: ColonyProfile

	match profile_type.to_lower():
		"starter":
			profile = ColonyProfile.create_starter()
		"advanced":
			profile = ColonyProfile.create_advanced()
		_: # Default to standard
			profile = ColonyProfile.create_standard()

	# Apply profile to colony
	colony.init_colony_profile(profile)

	# Add to tracking
	colonies.append(colony)
	colony.name = "Colony_%d" % colonies.size()
	colony_spawned.emit(colony)
	colony.add_to_group("colony")

	logger.info("Spawned new colony: %s with profile %s" % [colony.name, profile.name])
	return colony

## Spawn colony at a specific position
func spawn_colony_at(position: Vector2, profile_type: String = "standard") -> Colony:
	var colony = spawn_colony(profile_type)
	if colony:
		colony.global_position = position
	return colony

## Remove a colony and clean up its resources
func remove_colony(colony: Colony) -> Result:
	if not colony:
		return Result.new(Result.ErrorType.INVALID_ARGUMENT, "Colony is null")

	if not colonies.has(colony):
		return Result.new(Result.ErrorType.INVALID_ARGUMENT, "Colony not managed by this manager")

	# Stop colony processing
	start_colony(colony, false)

	# Remove from tracking
	colonies.erase(colony)
	colony_removed.emit(colony)

	# Clean up node
	colony.delete_all()
	colony.queue_free()

	logger.debug("Removed colony: %s" % colony.name)
	return Result.new()

## Get all valid colonies
func get_all() -> Colonies:
	var valid_colonies: = Colonies.new([])

	for colony in colonies:
		if is_instance_valid(colony) and not colony.is_queued_for_deletion():
			valid_colonies.append(colony)
		else:
			# Clean up invalid reference
			colonies.erase(colony)

	return valid_colonies

## Get colony by name
func get_colony_by_name(colony_name: String) -> Colony:
	for colony in colonies:
		if colony.name == colony_name:
			return colony
	return null
#endregion

func delete_all() -> void:
	for colony in colonies.duplicate():  # Duplicate array to avoid modification during iteration
		remove_colony(colony)

#region Cleanup
func _exit_tree() -> void:
	# Clean up all colonies when manager is removed
	delete_all()
#endregion
