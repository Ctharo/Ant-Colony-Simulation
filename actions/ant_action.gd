class_name AntAction
extends RefCounted

var ant: Ant

func start(_ant: Ant) -> void:
	ant = _ant

func update(_delta: float) -> void:
	pass

func is_completed() -> bool:
	return true

func cancel() -> void:
	pass

class MoveAction extends AntAction:
	var target_position: Vector2
	var speed: float
	
	func _init(_target_position: Vector2, _speed: float):
		target_position = _target_position
		speed = _speed
	
	func update(delta: float) -> void:
		var direction = (target_position - ant.global_position).normalized()
		ant.velocity = direction * speed
		ant.energy.deplete(delta * speed * 0.1)  # Energy cost based on speed
	
	func is_completed() -> bool:
		return ant.global_position.distance_to(target_position) < 1.0

class HarvestAction extends AntAction:
	var food_source: Food
	var harvest_rate: float
	
	func _init(_food_source: Food, _harvest_rate: float):
		food_source = _food_source
		harvest_rate = _harvest_rate
	
	func update(delta: float) -> void:
		var amount_to_harvest = min(harvest_rate * delta, ant.available_carry_mass())
		var harvested = food_source.remove_amount(amount_to_harvest)
		ant.foods.add(Food.new(harvested))
		ant.energy.deplete(delta * 0.5)  # Fixed energy cost for harvesting
	
	func is_completed() -> bool:
		return ant.foods.is_full() or food_source.is_depleted()
