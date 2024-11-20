class_name Strength
extends PropertyNode
## Component responsible for managing entity's base strength attributes

#region Constants
## Factor used to calculate maximum carry weight from strength level
const STRENGTH_FACTOR: float = 20.0

## Default starting strength level
const DEFAULT_LEVEL := 10
#endregion

#region Member Variables
## Base strength level of the entity
var _level: int = DEFAULT_LEVEL
#endregion

func _init(p_entity: Node) -> void:
	# First create self as container
	super._init("strength", Type.CONTAINER, p_entity)

	# Then build and copy children
	var tree = PropertyNode.create_tree(p_entity)\
		.value("level", Property.Type.INT,
			Callable(self, "_get_level"),
			Callable(self, "_set_level"),
			[],
			"Base strength level of the entity")\
		.container("derived", "Values derived from strength level")\
			.value("carry_capacity", Property.Type.FLOAT,
				Callable(self, "_get_carry_capacity"),
				Callable(),
				["strength.level"],
				"Maximum weight that can be carried based on strength")\
		.build()

	# Copy children from built tree
	for child in tree.children.values():
		add_child(child)

	_trace("Strength property tree initialized")

#region Property Getters and Setters
func _get_level() -> int:
	return _level

func _set_level(value: int) -> void:
	if value <= 0:
		_error("Attempted to set strength.level to non-positive value -> Action not allowed")
		return

	var old_value = _level
	_level = value

	if old_value != _level:
		_trace("Level updated: %d -> %d" % [old_value, _level])

func _get_carry_capacity() -> float:
	return float(_level) * STRENGTH_FACTOR
#endregion

#region Public Methods
## Reset strength level to default value
func reset() -> void:
	_set_level(DEFAULT_LEVEL)
	_trace("Strength reset to default: %d" % DEFAULT_LEVEL)
#endregion
