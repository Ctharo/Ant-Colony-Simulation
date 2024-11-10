class_name Olfaction
extends Attribute

#region Properties
## Max range at which the ant can sense scents
var range: float = 100.0 : get = _get_range, set = _set_range
var pheromones_in_range: Pheromones : get = _get_pheromones_in_range
var food_pheromones_in_range: Pheromones : get = _get_food_pheromones_in_range
#endregion

#region Lifecycle Methods
func _init(_ant: Ant) -> void:
	super._init("Olfaction", _ant)

func _init_properties() -> void:
	_properties_container.expose_properties([
		Property.create("range")
			.of_type(Property.Type.FLOAT)
			.with_getter(Callable(self, "_get_range"))
			.with_setter(Callable(self, "_set_range"))
			.described_as("Maximum range at which the ant can smell things")
			.build(),
		Property.create("pheromones_in_range")
			.of_type(Property.Type.PHEROMONES)
			.with_getter(Callable(self, "_get_pheromones_in_range"))
			.with_dependencies(["olfaction.range"])  # Depends on range property
			.described_as("List of pheromones within olfactory range")
			.build(),
		Property.create("food_pheromones_in_range")
			.of_type(Property.Type.PHEROMONES)
			.with_getter(Callable(self, "_get_food_pheromones_in_range"))
			.with_dependencies(["olfaction.pheromones_in_range"])  # Use full path for cross-property dependencies
			.described_as("List of food pheromones within olfactory range")
			.build(),
	])
#endregion

#region Public Methods
func is_within_range(point: Vector2) -> bool:
	return ant.global_position.distance_to(point) < range
#endregion

#region Private Methods
func _get_range() -> float:
	return range

func _get_pheromones_in_range() -> Pheromones:
	var pheromones: Pheromones = Pheromones.all()
	var p_in_range: Pheromones = Pheromones.new([])
	for pheromone in pheromones:
		if is_within_range(pheromone.global_position):
			p_in_range.append(pheromone as Pheromone)
	return p_in_range

func _get_food_pheromones_in_range() -> Pheromones:
	# Get the cached pheromones directly from the property container
	# to avoid recursive property access calls
	var property: Property = get_property("pheromones_in_range")
	var pheromones: Pheromones = property.value
	var p_in_range: Pheromones = Pheromones.new([])

	for pheromone in pheromones:
		if pheromone.type == "food":
			p_in_range.append(pheromone as Pheromone)

	return p_in_range

func _set_range(value: float) -> void:
	if range != value:
		range = value
#endregion
