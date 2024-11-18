class_name Reach
extends PropertyNode
## Component responsible for managing entity reach distance and food detection

#region Signals
## Could add signals here if needed, following Energy pattern
#endregion

#region Constants
const DEFAULT_RANGE := 15.0
#endregion

#region Member Variables
## The maximum reach distance of the entity
var _range: float = DEFAULT_RANGE
#endregion

func _init(_entity: Node) -> void:
	# First create self as container
	super._init("reach", Type.CONTAINER, _entity)
	
	# Then build and copy children
	var tree = PropertyNode.create_tree(_entity)\
		.container("range", "Reach distance information")\
			.value("current", Property.Type.FLOAT,
				Callable(self, "_get_range"),
				Callable(self, "_set_range"),
				[],
				"Maximum distance the entity can reach to interact with objects")\
		.up()\
		.container("foods", "Properties related to food in reach range")\
			.value("in_range", Property.Type.FOODS,
				Callable(self, "_get_foods_in_range"),
				Callable(),
				["reach.range.current"],
				"Food items within reach range")\
			.value("count", Property.Type.INT,
				Callable(self, "_get_foods_in_range_count"),
				Callable(),
				["reach.foods.in_range"],
				"Number of food items within reach range")\
			.value("mass", Property.Type.FLOAT,
				Callable(self, "_get_foods_in_range_mass"),
				Callable(),
				["reach.foods.in_range"],
				"Total mass of food within reach range")\
		.build()

	# Copy children from built tree
	for child in tree.children.values():
		add_child(child)

	_trace("Reach property tree initialized")

#region Property Getters and Setters
func _get_range() -> float:
	return _range

func _set_range(value: float) -> void:
	if value <= 0:
		_error("Attempted to set reach.range.current to non-positive value -> Action not allowed")
		return

	var old_value = _range
	_range = value

	if old_value != _range:
		_trace("Range updated: %.2f -> %.2f" % [old_value, _range])

func _get_foods_in_range() -> Foods:
	if not entity:
		_error("Cannot get foods in range: entity reference is null")
		return null
	return Foods.in_range(entity.global_position, _range)

func _get_foods_in_range_count() -> int:
	var foods = _get_foods_in_range()
	if not foods:
		return 0
	return foods.size()

func _get_foods_in_range_mass() -> float:
	var foods = _get_foods_in_range()
	if not foods:
		return 0.0
		
	var mass: float = 0.0
	for food in foods:
		mass += food.mass
	return mass
#endregion

#region Public Methods
## Reset reach distance to default value
func reset() -> void:
	_set_range(DEFAULT_RANGE)
	_trace("Range reset to default: %.2f" % DEFAULT_RANGE)

## Check if a specific position is within reach
func is_position_in_range(position: Vector2) -> bool:
	if not entity:
		_error("Cannot check position: entity reference is null")
		return false
	return entity.global_position.distance_to(position) <= _range
#endregion
