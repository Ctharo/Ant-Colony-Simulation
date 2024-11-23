class_name Strength
extends PropertyNode
## Component responsible for managing entity's base strength attributes

#region Constants
## Factor used to calculate maximum carry weight from strength level
const STRENGTH_FACTOR: float = 20.0
## Default starting strength level
const DEFAULT_LEVEL := 10
## Threshold percentage for overloaded status
const OVERLOAD_THRESHOLD := 90.0
#endregion

#region Member Variables
## Base strength level of the entity
var _level: int = DEFAULT_LEVEL
#endregion

func _init(_entity: Node) -> void:
	# First create self as container
	super._init("strength", Type.CONTAINER, _entity)

	# Create the tree with the container name matching self
	var tree = PropertyNode.create_tree(_entity)\
		.container("strength", "Strength management")\
			.container("base", "Base strength attributes")\
				.value("level", Property.Type.INT,
					Callable(self, "_get_level"),
					Callable(self, "_set_level"),
					[],
					"Base strength level of the entity")\
			.up()\
			.container("derived", "Values derived from strength")\
				.value("carry_factor", Property.Type.FLOAT,
					Callable(self, "_get_carry_factor"),
					Callable(),
					["strength.base.level"],
					"Base carrying capacity factor")\
			.up()\
			.container("status", "Status of strength")\
				.value("overloaded", Property.Type.BOOL,
					Callable(self, "_get_is_overloaded"),
					Callable(),
					["storage.capacity.percentage"],
					"Whether entity is carrying too much weight")\
			.up()\
		.build()

	# Copy the container children from the built tree's root strength node
	var built_strength = tree
	for child in built_strength.children.values():
		add_child(child)

	_trace("Strength property tree initialized")

#region Property Getters and Setters
func _get_level() -> int:
	return _level

func _set_level(value: int) -> void:
	if value <= 0:
		_error("Attempted to set strength.base.level to non-positive value -> Action not allowed")
		return

	var old_value = _level
	_level = value

	if old_value != _level:
		_trace("Level updated: %d -> %d" % [old_value, _level])

func _get_carry_factor() -> float:
	return float(_level) * STRENGTH_FACTOR

func _get_is_overloaded() -> bool:
	if not entity:
		return false
	var load_percentage = entity.get_property_value(Path.parse("storage.capacity.percentage"))
	return load_percentage > OVERLOAD_THRESHOLD
#endregion

#region Public Methods
## Reset strength level to default value
func reset() -> void:
	_set_level(DEFAULT_LEVEL)
	_trace("Strength reset to default: %d" % DEFAULT_LEVEL)
#endregion
