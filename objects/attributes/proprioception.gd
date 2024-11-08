class_name Proprioception
extends Attribute
## The component of the ant responsible for sense of direction

#region Signals
#endregion

#region Properties
var direction_to_colony: Vector2 : get = _get_direction_to_colony
#endregion

#region Lifecycle Methods
func _init(_ant: Ant) -> void:
	super._init(_ant, "Proprioception")
	
func _init_properties() -> void:
	properties_container.expose_properties([
		PropertyResult.PropertyInfo.create("direction_to_colony")
			.of_type(PropertyType.FLOAT)
			.with_getter(Callable(self, "_get_direction_to_colony"))
			.described_as("The normalized vector pointing towards colony")
			.build()
	])
#endregion

#region Public Methods

#endregion

#region Private Methods
func _get_direction_to_colony() -> Vector2:
	return _direction_to(ant.colony.global_position)
	
func _direction_to(location: Vector2) -> Vector2:
	return ant.global_position.direction_to(location)
#endregion
