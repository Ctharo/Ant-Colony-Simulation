class_name Proprioception
extends Attribute
## The component of the ant responsible for sense of direction

#region Signals
#endregion

#region Properties
var position: Vector2 : get = _get_position
var direction_to_colony: Vector2 : get = _get_direction_to_colony
#endregion

#region Lifecycle Methods
func _init(_ant: Ant) -> void:
	super._init("Proprioception", _ant)

func _init_properties() -> void:
	_properties_container.expose_properties([
		Property.create("position")
			.of_type(Property.Type.VECTOR2)
			.with_attribute(name)
			.with_getter(Callable(self, "_get_position"))
			.described_as("The vector location of the ant")
			.build(),
		Property.create("direction_to_colony")
			.of_type(Property.Type.VECTOR2)
			.with_attribute(name)
			.with_getter(Callable(self, "_get_direction_to_colony"))
			.with_dependencies(["proprioception.position", "colony.position"])
			.described_as("The normalized vector pointing towards colony")
			.build()
	])
#endregion

#region Public Methods

#endregion

#region Private Methods
func _get_position() -> Vector2:
	return ant.global_position

func _get_direction_to_colony() -> Vector2:
	if not ant._property_access:
		return Vector2.ZERO
	var value = ant.get_property_value(Path.parse("colony.position"))
	if not value:
		return Vector2.ZERO
	var colony_position: Vector2 = value
	return _direction_to(colony_position)

func _direction_to(location: Vector2) -> Vector2:
	return ant.global_position.direction_to(location)
#endregion
