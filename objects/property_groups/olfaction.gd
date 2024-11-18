class_name Olfaction
extends PropertyNode
## Component responsible for ant's sense of smell and pheromone detection

#region Constants
const DEFAULT_RANGE := 100.0
#endregion

#region Member Variables
## Maximum range at which the ant can detect scents
var _range: float = DEFAULT_RANGE
#endregion

func _init(_entity: Node) -> void:
	# First create self as container
	super._init("olfaction", Type.CONTAINER, _entity)

	# Then build and copy children
	var tree = PropertyNode.create_tree(_entity)\
		.container("range", "Olfactory range information")\
			.value("current", Property.Type.FLOAT,
				Callable(self, "_get_range"),
				Callable(self, "_set_range"),
				[],
				"Maximum range at which to smell things")\
		.up()\
		.container("pheromones", "Information about pheromones within detection range")\
			.value("list", Property.Type.PHEROMONES,
				Callable(self, "_get_pheromones_in_range"),
				Callable(),
				["olfaction.range.current"],
				"All pheromones within olfactory range")\
			.value("count", Property.Type.INT,
				Callable(self, "_get_pheromones_in_range_count"),
				Callable(),
				["olfaction.pheromones.list"],
				"Count of all pheromones within range")\
			.container("food", "Food-related pheromone information")\
				.value("list", Property.Type.PHEROMONES,
					Callable(self, "_get_food_pheromones_in_range"),
					Callable(),
					["olfaction.range.current"],
					"Food pheromones within range")\
				.value("count", Property.Type.INT,
					Callable(self, "_get_food_pheromones_in_range_count"),
					Callable(),
					["olfaction.pheromones.food.list"],
					"Count of food pheromones within range")\
			.up()\
			.container("home", "Home-related pheromone information")\
				.value("list", Property.Type.PHEROMONES,
					Callable(self, "_get_home_pheromones_in_range"),
					Callable(),
					["olfaction.range.current"],
					"Home pheromones within range")\
				.value("count", Property.Type.INT,
					Callable(self, "_get_home_pheromones_in_range_count"),
					Callable(),
					["olfaction.pheromones.home.list"],
					"Count of home pheromones within range")\
		.build()

	# Copy children from built tree
	for child in tree.children.values():
		add_child(child)

	_trace("Olfaction property tree initialized")

#region Property Getters and Setters
func _get_range() -> float:
	return _range

func _set_range(value: float) -> void:
	if value <= 0:
		_error("Attempted to set olfaction.range.current to non-positive value -> Action not allowed")
		return

	var old_value = _range
	_range = value

	if old_value != _range:
		_trace("Range updated: %.2f -> %.2f" % [old_value, _range])

func _get_pheromones_in_range() -> Pheromones:
	if not entity:
		_error("Cannot get pheromones: entity reference is null")
		return null

	return Pheromones.in_range(entity.global_position, _range)

func _get_pheromones_in_range_count() -> int:
	var pheromones = _get_pheromones_in_range()
	return pheromones.size() if pheromones else 0

func _get_food_pheromones_in_range() -> Pheromones:
	if not entity:
		_error("Cannot get food pheromones: entity reference is null")
		return null

	return Pheromones.in_range(entity.global_position, _range, "food")

func _get_food_pheromones_in_range_count() -> int:
	var pheromones = _get_food_pheromones_in_range()
	return pheromones.size() if pheromones else 0

func _get_home_pheromones_in_range() -> Pheromones:
	if not entity:
		_error("Cannot get home pheromones: entity reference is null")
		return null

	return Pheromones.in_range(entity.global_position, _range, "home")

func _get_home_pheromones_in_range_count() -> int:
	var pheromones = _get_home_pheromones_in_range()
	return pheromones.size() if pheromones else 0
#endregion

#region Public Methods
## Check if a point is within olfactory range
func is_within_range(point: Vector2) -> bool:
	if not entity:
		_error("Cannot check range: entity reference is null")
		return false

	return entity.global_position.distance_to(point) < _range

## Reset olfactory range to default value
func reset() -> void:
	_set_range(DEFAULT_RANGE)
	_trace("Range reset to default: %.2f" % DEFAULT_RANGE)
#endregion
