class_name Speed
extends Attribute

var movement_rate: float
var harvesting_rate: float
var storing_rate: float

func _init(movement_rate: float = 1.0, harvesting_rate: float = 0.5, storing_rate: float = 10.0):
	self.movement_rate = movement_rate
	self.harvesting_rate = harvesting_rate
	self.storing_rate = storing_rate

	expose_property("movement_rate", 
		func(): return movement_rate,
		PropertyType.FLOAT,
		func(v): set_movement_rate(v)
	)
	expose_property("harvesting_rate", 
		func(): return harvesting_rate,
		PropertyType.FLOAT,
		func(v): set_harvesting_rate(v)
	)
	expose_property("storing_rate", 
		func(): return storing_rate,
		PropertyType.FLOAT,
		func(v): storing_rate = v
	)
	expose_property("time_to_move", 
		func(distance: float): return time_to_move(distance),
		PropertyType.FLOAT
	)
	expose_property("harvest_amount", 
		func(time: float): return harvest_amount(time),
		PropertyType.FLOAT
	)

func set_movement_rate(rate: float) -> void:
	movement_rate = max(rate, 0.0)

func set_harvesting_rate(rate: float) -> void:
	harvesting_rate = max(rate, 0.0)

func time_to_move(distance: float) -> float:
	return distance / movement_rate if movement_rate > 0 else INF

func harvest_amount(time: float) -> float:
	return harvesting_rate * time
