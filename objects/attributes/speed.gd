class_name Speed
extends PropertyGroup

#region Constants
const DEFAULT_RATE := 1.0
#endregion

#region Member Variables
## Rate at which the ant can move (units/second)
var _movement_rate: float = DEFAULT_RATE

## Rate at which the ant can harvest resources (units/second)
var _harvesting_rate: float = DEFAULT_RATE

## Rate at which the ant can store resources (units/second)
var _storing_rate: float = DEFAULT_RATE
#endregion

func _init(ant: Ant) -> void:
	super._init("speed", ant)
	_trace("Speed component initialized with default rates")

## Initialize all properties for the Speed component
func _init_properties() -> void:
	# Create rates container with nested properties
	var rates_prop = (Property.create("rates")
		.as_container()
		.described_as("Various speed rates for ant activities")
		.with_children([
			Property.create("movement")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_movement_rate"))
				.with_setter(Callable(self, "_set_movement_rate"))
				.described_as("Rate at which the ant can move (units/second)")
				.build(),

			Property.create("harvesting")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_harvesting_rate"))
				.with_setter(Callable(self, "_set_harvesting_rate"))
				.described_as("Rate at which the ant can harvest resources (units/second)")
				.build(),

			Property.create("storing")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_storing_rate"))
				.with_setter(Callable(self, "_set_storing_rate"))
				.described_as("Rate at which the ant can store resources (units/second)")
				.build()
		])
		.build())

	# Create calculators container with computed properties
	var calculators_prop = (Property.create("calculators")
		.as_container()
		.described_as("Helper properties for speed-based calculations")
		.with_children([
			Property.create("time_to_move")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_time_to_move"))
				.with_dependency("speed.rates.movement")
				.described_as("Time required to move one unit of distance")
				.build(),

			Property.create("harvest_per_second")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_harvest_per_second"))
				.with_dependency("speed.rates.harvesting")
				.described_as("Amount that can be harvested in one second")
				.build()
		])
		.build())

	# Register properties with error handling
	var result = register_at_path(Path.parse("speed"), rates_prop)
	if not result.success():
		push_error("Failed to register rates property: %s" % result.get_error())
		return

	result = register_at_path(Path.parse("speed") ,calculators_prop)
	if not result.success():
		push_error("Failed to register calculators property: %s" % result.get_error())
		return

	_trace("Properties initialized successfully")

#region Property Getters and Setters
func _get_movement_rate() -> float:
	return _movement_rate

func _set_movement_rate(rate: float) -> void:
	if is_zero_approx(rate):
		DebugLogger.warn(
			DebugLogger.Category.PROPERTY,
			"Attempted to set speed.rates.movement to zero -> Action not allowed"
		)
		return

	var old_rate = _movement_rate
	_movement_rate = max(rate, 0.0)

	if old_rate != _movement_rate:
		_trace("Movement rate updated: %.2f -> %.2f" % [old_rate, _movement_rate])

func _get_harvesting_rate() -> float:
	return _harvesting_rate

func _set_harvesting_rate(rate: float) -> void:
	if is_zero_approx(rate):
		DebugLogger.warn(
			DebugLogger.Category.PROPERTY,
			"Attempted to set speed.rates.harvesting to zero -> Action not allowed"
		)
		return

	var old_rate = _harvesting_rate
	_harvesting_rate = max(rate, 0.0)

	if old_rate != _harvesting_rate:
		_trace("Harvesting rate updated: %.2f -> %.2f" % [old_rate, _harvesting_rate])

func _get_storing_rate() -> float:
	return _storing_rate

func _set_storing_rate(rate: float) -> void:
	if is_zero_approx(rate):
		DebugLogger.warn(
			DebugLogger.Category.PROPERTY,
			"Attempted to set speed.rates.storing to zero -> Action not allowed"
		)
		return

	var old_rate = _storing_rate
	_storing_rate = max(rate, 0.0)

	if old_rate != _storing_rate:
		_trace("Storing rate updated: %.2f -> %.2f" % [old_rate, _storing_rate])

func _get_time_to_move() -> float:
	return 1.0 / _movement_rate if _movement_rate > 0 else INF

func _get_harvest_per_second() -> float:
	return _harvesting_rate
#endregion

#region Public Methods
## Calculate time required to move a given distance
func time_to_move(distance: float) -> float:
	if distance < 0:
		push_error("Cannot calculate time for negative distance")
		return INF

	return distance / _movement_rate if _movement_rate > 0 else INF

## Calculate amount that can be harvested in a given time period
func harvest_amount(time: float) -> float:
	if time < 0:
		push_error("Cannot calculate harvest amount for negative time")
		return 0.0

	return _harvesting_rate * time

## Reset all rates to their default values
func reset_rates() -> void:
	_set_movement_rate(DEFAULT_RATE)
	_set_harvesting_rate(DEFAULT_RATE)
	_set_storing_rate(DEFAULT_RATE)
	_trace("All rates reset to default: %.2f" % DEFAULT_RATE)
#endregion
