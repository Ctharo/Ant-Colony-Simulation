class_name Strength
extends PropertyGroup

#region Constants
## Factor used to calculate maximum carry weight from strength level
const STRENGTH_FACTOR: float = 20.0
#endregion

#region Member Variables
## Base strength level of the ant
var _level: int = 10
#endregion

func _init(_ant: Ant) -> void:
	super._init("strength", _ant)
	_trace("Strength component initialized with level: %d" % _level)

## Initialize all properties for the Strength component
func _init_properties() -> void:
	# Create base level property
	var level_prop = (Property.create("level")
		.as_property(Property.Type.INT)
		.with_getter(Callable(self, "_get_level"))
		.with_setter(Callable(self, "_set_level"))
		.described_as("Base strength level of the ant")
		.build())

	# Create carrying capacity container with nested properties
	var capacity_prop = (Property.create("capacity")
		.as_container()
		.described_as("Information about ant's carrying capacity")
		.with_children([
			Property.create("maximum")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_carry_max"))
				.with_dependency("strength.level")
				.described_as("Maximum weight the ant can carry based on strength level")
				.build(),

			Property.create("current_load")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_carried_food_mass"))
				.described_as("Current total mass of carried food")
				.build(),

			Property.create("available")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_mass_available"))
				.with_dependencies([
					"strength.capacity.maximum",
					"strength.capacity.current_load"
				])
				.described_as("Remaining carrying capacity available")
				.build(),

			Property.create("is_carrying")
				.as_property(Property.Type.BOOL)
				.with_getter(Callable(self, "_is_carrying_food"))
				.with_dependency("strength.capacity.current_load")
				.described_as("Whether the ant is currently carrying any food")
				.build()
		])
		.build())

	# Register properties with error handling
	var result = register_at_path(Path.parse("strength"), level_prop)
	if not result.success():
		push_error("Failed to register level property: %s" % result.get_error())
		return

	result = register_at_path(Path.parse("strength"), capacity_prop)
	if not result.success():
		push_error("Failed to register capacity property: %s" % result.get_error())
		return

	_trace("Properties initialized successfully")

#region Property Getters and Setters
func _get_level() -> int:
	return _level

func _set_level(value: int) -> void:
	if value <= 0:
		push_error("Strength level must be positive")
		return

	var old_value = _level
	_level = value
	_trace("Level updated: %d -> %d" % [old_value, _level])

func _get_carry_max() -> float:
	return STRENGTH_FACTOR * _level

func _get_carried_food_mass() -> float:
	if not ant:
		push_error("Cannot get carried food mass: ant reference is null")
		return 0.0

	return ant.carried_food.mass()

func _get_mass_available() -> float:
	return _get_carry_max() - _get_carried_food_mass()

func _is_carrying_food() -> bool:
	return _get_carried_food_mass() > 0
#endregion

#region Public Methods
## Check if the ant can carry additional weight
func can_carry(weight: float) -> bool:
	if weight < 0:
		push_error("Cannot check negative weight")
		return false

	return weight <= _get_mass_available()

## Reset strength level to default value
func reset_level() -> void:
	_set_level(10)
	_trace("Level reset to default: 10")
#endregion
