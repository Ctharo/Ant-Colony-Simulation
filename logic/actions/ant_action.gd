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
	var movement_rate: float
	
	func _init(_target_position: Vector2):
		target_position = _target_position
		movement_rate = ant.speed.movement_rate
	
	func update(delta: float) -> void:
		var direction = ant.global_position.direction_to(target_position)
		ant.velocity = direction * movement_rate
		ant.energy.deplete(delta * movement_rate * 0.1)  # Energy cost based on movement_rate
	
	func is_completed() -> bool:
		return ant.global_position.distance_to(target_position) < 1.0

class HarvestAction extends AntAction:
	var food_source: Food
	var harvest_rate: float
	
	func _init(_food_source: Food):
		food_source = _food_source
		harvest_rate = ant.speed.harvesting_rate
	
	func update(delta: float) -> void:
		var amount_to_harvest = min(harvest_rate * delta, ant.available_carry_mass())
		var harvested = food_source.remove_amount(amount_to_harvest)
		ant.foods.add(Food.new(harvested))
		ant.energy.deplete(delta * 0.5)  # Fixed energy cost for harvesting
	
	func is_completed() -> bool:
		return ant.foods.is_full() or food_source.is_depleted()

class StoreAction extends AntAction:
	var storage_location: Vector2
	
	func _init(_storage_location: Vector2):
		storage_location = _storage_location

class AttackAction extends AntAction:
	var target_location: Vector2
	
	func _init(_target_location: Vector2):
		target_location = _target_location
