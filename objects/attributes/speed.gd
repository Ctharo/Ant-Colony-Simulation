class_name Speed
extends Attribute

#region Properties
## Rate at which the ant can move (units/second)
var movement_rate: float = 1.0 : get = _get_movement_rate, set = _set_movement_rate

## Rate at which the ant can harvest resources (units/second)
var harvesting_rate: float = 1.0 : get = _get_harvesting_rate, set = _set_harvesting_rate

## Rate at which the ant can store resources (units/second)
var storing_rate: float = 1.0 : get = _get_storing_rate, set = _set_storing_rate
#endregion

#region Lifecycle Methods
func _init(_ant: Ant) -> void:
	super._init(_ant, "Speed")

func _init_properties() -> void:
	properties_container.expose_properties([
		PropertyResult.PropertyInfo.create("movement_rate")
			.of_type(PropertyType.FLOAT)
			.with_getter(Callable(self, "_get_movement_rate"))
			.with_setter(Callable(self, "_set_movement_rate"))
			.described_as("Rate at which the ant can move (units/second)")
			.build(),
			
		PropertyResult.PropertyInfo.create("harvesting_rate")
			.of_type(PropertyType.FLOAT)
			.with_getter(Callable(self, "_get_harvesting_rate"))
			.with_setter(Callable(self, "_set_harvesting_rate"))
			.described_as("Rate at which the ant can harvest resources (units/second)")
			.build(),
			
		PropertyResult.PropertyInfo.create("storing_rate")
			.of_type(PropertyType.FLOAT)
			.with_getter(Callable(self, "_get_storing_rate"))
			.with_setter(Callable(self, "_set_storing_rate"))
			.described_as("Rate at which the ant can store resources (units/second)")
			.build()
	])
#endregion

#region Public Methods
func time_to_move(distance: float) -> float:
	return distance / movement_rate if movement_rate > 0 else INF

func harvest_amount(time: float) -> float:
	return harvesting_rate * time
#endregion

#region Private Methods
func _get_movement_rate() -> float:
	return movement_rate

func _get_harvesting_rate() -> float:
	return harvesting_rate

func _get_storing_rate() -> float:
	return storing_rate

func _set_movement_rate(rate: float) -> void:
	if is_zero_approx(rate):
		DebugLogger.warn(DebugLogger.Category.PROPERTY, "Attempted to set speed.movement_rate to zero -> Action not allowed")
		return
	if movement_rate != rate:
		movement_rate = max(rate, 0.0)

func _set_harvesting_rate(rate: float) -> void:
	if is_zero_approx(rate):
		DebugLogger.warn(DebugLogger.Category.PROPERTY, "Attempted to set speed.harvesting_rate to zero -> Action not allowed")
		return
	if harvesting_rate != rate:
		harvesting_rate = max(rate, 0.0)

func _set_storing_rate(rate: float) -> void:
	if is_zero_approx(rate):
		DebugLogger.warn(DebugLogger.Category.PROPERTY, "Attempted to set speed.storing_rate to zero -> Action not allowed")
		return
	if storing_rate != rate:
		storing_rate = max(rate, 0.0)
#endregion
