class_name Proprioception
extends PropertyNode
## The component responsible for sense of direction and position

func _init(_entity: Node) -> void:
	# First create self as container
	super._init("proprioception", Type.CONTAINER, _entity)

	# Create the tree with the container name matching self
	var tree = PropertyNode.create_tree(_entity)\
		.container("proprioception", "Proprioception management")\
			.container("base", "Base position information")\
				.value("position", Property.Type.VECTOR2,
					Callable(self, "_get_position"),
					Callable(),
					[],
					"Current global position of the entity")\
			.up()\
			.container("colony", "Information about position relative to colony")\
				.value("position", Property.Type.VECTOR2,
					Callable(self, "_get_colony_position"),
					Callable(),
					["colony.position"],
					"Global position of the colony")\
				.value("direction", Property.Type.VECTOR2,
					Callable(self, "_get_direction_to_colony"),
					Callable(),
					["proprioception.base.position", "proprioception.colony.position"],
					"Normalized vector pointing towards colony")\
				.value("distance", Property.Type.FLOAT,
					Callable(self, "_get_distance_to_colony"),
					Callable(),
					["proprioception.base.position", "proprioception.colony.position"],
					"Distance from entity to colony in units")\
			.up()\
			.container("status", "Position status information")\
				.value("at_colony", Property.Type.BOOL,
					Callable(self, "_is_at_colony"),
					Callable(),
					["proprioception.colony.distance"],
					"Whether the entity is at the colony")\
				.value("has_moved", Property.Type.BOOL,
					Callable(self, "_has_moved"),
					Callable(),
					["proprioception.base.position"],
					"Whether the entity has moved from its starting position")\
			.up()\
		.build()

	# Copy the container children from the built tree
	var built_proprioception = tree
	for child in built_proprioception.children.values():
		add_child(child)

	_trace("Proprioception property tree initialized")

#region Property Getters
func _get_position() -> Vector2:
	if not entity:
		_error("Cannot get position: entity reference is null")
		return Vector2.ZERO
	return entity.global_position

func _get_colony_position() -> Vector2:
	if not entity:
		_error("Cannot get colony position: entity reference is null")
		return Vector2.ZERO
	var colony_pos = entity.get_property_value(Path.parse("colony.position"))
	if not colony_pos:
		_trace("Could not get colony position")
		return Vector2.ZERO
	return colony_pos

func _get_distance_to_colony() -> float:
	if not entity:
		_error("Cannot get colony distance: entity reference is null")
		return 0.0
	var colony_pos = _get_colony_position()
	if colony_pos == Vector2.ZERO:
		return 0.0
	return _get_position().distance_to(colony_pos)

func _get_direction_to_colony() -> Vector2:
	if not entity:
		_error("Cannot get colony direction: entity reference is null")
		return Vector2.ZERO
	var colony_pos = _get_colony_position()
	if colony_pos == Vector2.ZERO:
		return Vector2.ZERO
	return _direction_to(colony_pos)

func _is_at_colony() -> bool:
	return is_zero_approx(_get_distance_to_colony())

func _has_moved() -> bool:
	return not is_zero_approx(_get_position().length())
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
