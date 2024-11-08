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
	super._init(_ant, "Olfaction")

func _init_properties() -> void:
	properties_container.expose_properties([
		PropertyResult.PropertyInfo.create("range")
			.of_type(PropertyType.FLOAT)
			.with_getter(Callable(self, "_get_range"))
			.with_setter(Callable(self, "_set_range"))
			.described_as("Maximum range at which the ant can smell things")
			.build(),
		PropertyResult.PropertyInfo.create("pheromones_in_range")
			.of_type(PropertyType.PHEROMONES)
			.with_getter(Callable(self, "_get_pheromones_in_range"))
			.with_dependencies(["olfaction.range"])  # Depends on range property
			.described_as("List of pheromones within olfactory range")
			.build(),
		PropertyResult.PropertyInfo.create("food_pheromones_in_range")
			.of_type(PropertyType.PHEROMONES)
			.with_getter(Callable(self, "_get_food_pheromones_in_range"))
			.with_dependencies(["olfaction.pheromones_in_range"])  # Use full path for cross-property dependencies
			.described_as("List of food pheromones within olfactory range")
			.build(),
	])
#endregion

#region Public Methods
## Determines if the point is within the maximum range of smell
func is_within_range(point: Vector2) -> bool:
	return point.distance_to(ant.global_position) <= range
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
	var result: PropertyResult = get_property("pheromones_in_range")
	if not result.success():
		DebugLogger.warn(DebugLogger.Category.PROPERTY, "Problem getting property dependency")
		return Pheromones.new([])
		
	var pheromones: Pheromones = result.value
	var p_in_range: Pheromones = Pheromones.new([])
	
	for pheromone in pheromones:
		if pheromone.type == "food":
			p_in_range.append(pheromone as Pheromone)
			
	return p_in_range

func _set_range(value: float) -> void:
	if range != value:
		range = value
#endregion
