class_name Vision
extends PropertyNode
## Component responsible for managing entity's visual perception

#region Constants
const DEFAULT_RANGE := 50.0
#endregion

#region Member Variables
## Maximum range at which the entity can see
var _range: float = DEFAULT_RANGE
#endregion

func _init(_entity: Node) -> void:
	# First create self as container
	super._init("vision", Type.CONTAINER, _entity)

	# Then build and copy children
	var tree = PropertyNode.create_tree(_entity)\
		.container("range", "Vision range information")\
			.value("current", Property.Type.FLOAT,
				Callable(self, "_get_range"),
				Callable(self, "_set_range"),
				[],
				"Maximum range at which the entity can see")\
		.up()\
		.container("ants", "Properties related to ants in vision range")\
			.value("list", Property.Type.ANTS,
				Callable(self, "_get_ants_in_range"),
				Callable(),
				["vision.range.current"],
				"Ants within vision range")\
			.value("count", Property.Type.INT,
				Callable(self, "_get_ants_in_range_count"),
				Callable(),
				["vision.ants.list"],
				"Number of ants within vision range")\
		.up()\
		.container("foods", "Properties related to food in vision range")\
			.value("list", Property.Type.FOODS,
				Callable(self, "_get_foods_in_range"),
				Callable(),
				["vision.range.current"],
				"Food items within vision range")\
			.value("count", Property.Type.INT,
				Callable(self, "_get_foods_in_range_count"),
				Callable(),
				["vision.foods.list"],
				"Number of food items within vision range")\
			.value("mass", Property.Type.FLOAT,
				Callable(self, "_get_foods_in_range_mass"),
				Callable(),
				["vision.foods.list"],
				"Total mass of food within vision range")\
		.build()

	# Copy children from built tree
	for child in tree.children.values():
		add_child(child)

	_trace("Vision property tree initialized")

#region Property Getters and Setters
func _get_range() -> float:
	return _range

func _set_range(value: float) -> void:
	if value <= 0:
		_error("Attempted to set vision.range.current to non-positive value -> Action not allowed")
		return

	var old_value = _range
	_range = value

	if old_value != _range:
		_trace("Range updated: %.2f -> %.2f" % [old_value, _range])

func _get_ants_in_range() -> Ants:
	if not entity:
		_error("Cannot get ants in range: entity reference is null")
		return null
	return Ants.in_range(entity, _range)

func _get_ants_in_range_count() -> int:
	var ants = _get_ants_in_range()
	return ants.size() if ants else 0

func _get_foods_in_range() -> Foods:
	if not entity:
		_error("Cannot get foods in range: entity reference is null")
		return null
	return Foods.in_range(entity.global_position, _range, true)

func _get_foods_in_range_count() -> int:
	var foods = _get_foods_in_range()
	return foods.size() if foods else 0

func _get_foods_in_range_mass() -> float:
	var foods = _get_foods_in_range()
	return foods.mass() if foods else 0.0
#endregion

#region Public Methods
## Check if a point is within visual range
func is_within_range(point: Vector2) -> bool:
	if not entity:
		_error("Cannot check range: entity reference is null")
		return false
	return point.distance_to(entity.global_position) <= _range

## Reset vision range to default value
func reset() -> void:
	_set_range(DEFAULT_RANGE)
	_trace("Range reset to default: %.2f" % DEFAULT_RANGE)
#endregion
