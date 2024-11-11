class_name Proprioception
extends PropertyGroup
## The component of the ant responsible for sense of direction

func _init(ant: Ant) -> void:
	super._init("proprioception", ant)
	_trace("Proprioception component initialized")

## Initialize all properties for the Proprioception component
func _init_properties() -> void:
	# Create position property
	var position_prop = (Property.create("position")
		.as_property(Property.Type.VECTOR2)
		.with_getter(Callable(self, "_get_position"))
		.described_as("Current global position of the ant")
		.build())

	# Create colony awareness container with related properties
	var colony_prop = (Property.create("colony")
		.as_container()
		.described_as("Information about ant's position relative to colony")
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
				.described_as("Distance from ant to colony in units")
				.build()
		])
		.build())

	# Register properties with error handling
	var result = register_property(position_prop)
	if not result.is_ok():
		push_error("Failed to register position property: %s" % result.get_error())
		return

	result = register_property(colony_prop)
	if not result.is_ok():
		push_error("Failed to register colony properties: %s" % result.get_error())
		return

	_trace("Properties initialized successfully")

#region Property Getters
func _get_position() -> Vector2:
	if not ant:
		push_error("Cannot get position: ant reference is null")
		return Vector2.ZERO

	return ant.global_position

func _get_distance_to_colony() -> float:
	if not ant:
		push_error("Cannot get colony distance: ant reference is null")
		return 0.0

	var colony_pos = ant.get_property_value(Path.parse("colony.position"))
	if not colony_pos:
		_trace("Could not get colony position")
		return 0.0

	return _get_position().distance_to(colony_pos)

func _get_direction_to_colony() -> Vector2:
	if not ant:
		push_error("Cannot get colony direction: ant reference is null")
		return Vector2.ZERO

	var colony_pos = ant.get_property_value("colony.position")
	if not colony_pos:
		_trace("Could not get colony position")
		return Vector2.ZERO

	return _direction_to(colony_pos)
#endregion

#region Public Methods
## Get direction from ant's current position to a specific location
func get_direction_to(location: Vector2) -> Vector2:
	if not ant:
		push_error("Cannot get direction: ant reference is null")
		return Vector2.ZERO

	return _direction_to(location)

## Get distance from ant's current position to a specific location
func get_distance_to(location: Vector2) -> float:
	if not ant:
		push_error("Cannot get distance: ant reference is null")
		return 0.0

	return _get_position().distance_to(location)
#endregion

#region Private Methods
## Calculate direction vector to a given location
func _direction_to(location: Vector2) -> Vector2:
	return _get_position().direction_to(location)
#endregion
