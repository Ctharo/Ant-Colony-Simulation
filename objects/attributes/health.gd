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
	expose_property(
		"max_level",
		Callable(self, "max_level"),
		PropertyType.FLOAT,
		Callable(self, "set_max_level"),
		"Maximum health level the ant can have"
	)
	
	expose_property(
		"current_level",
		Callable(self, "current_level"),
		PropertyType.FLOAT,
		Callable(self, "set_current_level"),
		"Current health level of the ant"
	)
	
	expose_property(
		"percentage",
		Callable(self, "health_percentage"),
		PropertyType.FLOAT,
		Callable(),
		"Current health level as a percentage of max health"
	)
	
	expose_property(
		"is_critically_low",
		Callable(self, "is_critically_low"),
		PropertyType.BOOL,
		Callable(),
		"Whether health is below critical threshold (20%)"
	)
	
	expose_property(
		"is_full",
		Callable(self, "is_full"),
		PropertyType.BOOL,
		Callable(),
		"Whether health is at maximum level"
	)
	
	expose_property(
		"restorable_amount",
		Callable(self, "restorable_amount"),
		PropertyType.FLOAT,
		Callable(),
		"Amount of health that can be restored before reaching max"
	)

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
