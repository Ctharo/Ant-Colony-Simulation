class_name Health
extends Attribute

signal depleted

var _max_level: float = 100.0
var _current_level: float = _max_level :
	set(value):
		_current_level = max(value, 0.0)
		if is_zero_approx(_current_level):
			depleted.emit()

func _init() -> void:
	properties_container.expose_properties([
		PropertyResult.PropertyInfo.create("max_level")
			.of_type(PropertyType.FLOAT)
			.with_getter(Callable(self, "max_level"))
			.with_setter(Callable(self, "set_max_level"))
			.described_as("Maximum health level the ant can have")
			.build(),
			
		PropertyResult.PropertyInfo.create("current_level")
			.of_type(PropertyType.FLOAT)
			.with_getter(Callable(self, "current_level"))
			.with_setter(Callable(self, "set_current_level"))
			.described_as("Current health level of the ant")
			.build(),
			
		PropertyResult.PropertyInfo.create("percentage")
			.of_type(PropertyType.FLOAT)
			.with_getter(Callable(self, "health_percentage"))
			.described_as("Current health level as a percentage of max health")
			.build(),
			
		PropertyResult.PropertyInfo.create("is_critically_low")
			.of_type(PropertyType.BOOL)
			.with_getter(Callable(self, "is_critically_low"))
			.described_as("Whether health is below critical threshold (20%)")
			.build(),
			
		PropertyResult.PropertyInfo.create("is_full")
			.of_type(PropertyType.BOOL)
			.with_getter(Callable(self, "is_full"))
			.described_as("Whether health is at maximum level")
			.build(),
			
		PropertyResult.PropertyInfo.create("restorable_amount")
			.of_type(PropertyType.FLOAT)
			.with_getter(Callable(self, "restorable_amount"))
			.described_as("Amount of health that can be restored before reaching max")
			.build()
	])

func max_level() -> float:
	return _max_level

func set_max_level(value: float) -> void:
	_max_level = value

func current_level() -> float:
	return _current_level

func set_current_level(value: float) -> void:
	_current_level = value

func health_percentage() -> float:
	return (_current_level / _max_level) * 100.0

func is_critically_low() -> bool:
	return health_percentage() < 20.0

func is_full() -> bool:
	return is_equal_approx(_current_level, _max_level)

func restorable_amount() -> float:
	return _max_level - _current_level
