class_name Strength
extends PropertyNode

#region Constants
## Factor used to calculate maximum carry weight from strength level
const STRENGTH_FACTOR: float = 20.0
#endregion

#region Member Variables
## Base strength level of the entity
var _level: int = 10
#endregion

func _init(p_entity: Node) -> void:
	super._init("strength", PropertyNode.Type.CONTAINER, p_entity)

func _init_properties() -> void:
	# Create base level property
	var level_prop = (Property.create("level")
		.as_property(Property.Type.INT)
		.with_getter(Callable(self, "_get_level"))
		.with_setter(Callable(self, "_set_level"))
		.described_as("Base strength level of the entity")
		.build())

	# Register properties
	register_at_path(Path.parse("strength"), level_prop)

#region Property Getters and Setters
func _get_level() -> int:
	return _level

func _set_level(value: int) -> void:
	if value <= 0:
		_error("Strength level must be positive")
		return
	var old_value = _level
	_level = value
	_trace("Level updated: %d -> %d" % [old_value, _level])

#endregion
