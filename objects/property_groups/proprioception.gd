class_name Proprioception
extends PropertyNode
## The component responsible for sense of direction

func _init(_entity: Node) -> void:
	super._init("proprioception", PropertyNode.Type.CONTAINER, _entity)

## Initialize all properties for the Proprioception component
func _init_properties() -> void:
	# Create position property
	var position_prop = (Property.create("position")
		.as_property(Property.Type.VECTOR2)
		.with_getter(Callable(self, "_get_position"))
		.described_as("Current global position of the entity")
		.build())

	# Create colony awareness container with related properties
	var colony_prop = (Property.create("colony")
		.as_container()
		.described_as("Information about entity's position relative to colony")
		.with_children([
			Property.create("direction")
				.as_property(Property.Type.VECTOR2)
				.with_getter(Callable(self, "_get_direction_to_colony"))
				.with_dependencies([
					"proprioception.position",
					"colony.position"
				])
				.described_as("Normalized vector pointing towards colony")
				.build(),

			Property.create("distance")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_distance_to_colony"))
				.with_dependencies([
					"proprioception.position",
					"colony.position"
				])
				.described_as("Distance from entity to colony in units")
				.build()
		])
		.build())

	# Register properties with error handling
	var result = register_at_path(Path.parse("proprioception"), position_prop)
	if not result.success():
		_error("Failed to register proprioception.position property: %s" % result.get_error())
		return

	result = register_at_path(Path.parse("proprioception"), colony_prop)
	if not result.success():
		_error("Failed to register proprioception.colony properties: %s" % result.get_error())
		return


#region Property Getters
func _get_position() -> Vector2:
	if not entity:
		_error("Cannot get position: entity reference is null")
		return Vector2.ZERO

	return entity.global_position

func _get_distance_to_colony() -> float:
	if not entity:
		_error("Cannot get colony distance: entity reference is null")
		return 0.0

	var colony_pos = entity.get_property_value(Path.parse("colony.position"))
	if not colony_pos:
		_trace("Could not get colony position")
		return 0.0

	return _get_position().distance_to(colony_pos)

func _get_direction_to_colony() -> Vector2:
	if not entity:
		_error("Cannot get colony direction: entity reference is null")
		return Vector2.ZERO

	var colony_pos = entity.get_property_value(Path.parse("colony.position"))
	if not colony_pos:
		_trace("Could not get colony position")
		return Vector2.ZERO

	return _direction_to(colony_pos)
#endregion

#region Public Methods
## Get direction from entity's current position to a specific location
func get_direction_to(location: Vector2) -> Vector2:
	if not entity:
		_error("Cannot get direction: entity reference is null")
		return Vector2.ZERO

	return _direction_to(location)

## Get distance from entity's current position to a specific location
func get_distance_to(location: Vector2) -> float:
	if not entity:
		_error("Cannot get distance: entity reference is null")
		return 0.0

	return _get_position().distance_to(location)
#endregion

#region Private Methods
## Calculate direction vector to a given location
func _direction_to(location: Vector2) -> Vector2:
	return _get_position().direction_to(location)
#endregion
