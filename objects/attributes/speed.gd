class_name Speed
extends Attribute

var _movement_rate: float
var _harvesting_rate: float
var _storing_rate: float

func _init(
	movement_rate: float = 1.0,
	harvesting_rate: float = 0.5,
	storing_rate: float = 10.0
) -> void:
	_movement_rate = movement_rate
	_harvesting_rate = harvesting_rate
	_storing_rate = storing_rate
	
	expose_property(
		"movement_rate",
		Callable(self, "movement_rate"),
		PropertyType.FLOAT,
		Callable(self, "set_movement_rate"),
		"Rate at which the ant can move (units/second)"
	)
	
	expose_property(
		"harvesting_rate",
		Callable(self, "harvesting_rate"),
		PropertyType.FLOAT,
		Callable(self, "set_harvesting_rate"),
		"Rate at which the ant can harvest resources (units/second)"
	)
	
	expose_property(
		"storing_rate",
		Callable(self, "storing_rate"),
		PropertyType.FLOAT,
		Callable(self, "set_storing_rate"),
		"Rate at which the ant can store resources (units/second)"
	)

func movement_rate() -> float:
	return _movement_rate

func harvesting_rate() -> float:
	return _harvesting_rate

func storing_rate() -> float:
	return _storing_rate

func set_movement_rate(rate: float) -> void:
	_movement_rate = max(rate, 0.0)

func set_harvesting_rate(rate: float) -> void:
	_harvesting_rate = max(rate, 0.0)

func set_storing_rate(rate: float) -> void:
	_storing_rate = max(rate, 0.0)

func time_to_move(distance: float) -> float:
	return distance / _movement_rate if _movement_rate > 0 else INF

func harvest_amount(time: float) -> float:
	return _harvesting_rate * time
