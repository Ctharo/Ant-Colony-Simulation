class_name Condition
extends RefCounted

## Signal emitted when condition evaluation changes
signal evaluation_changed(is_met: bool)

## Previous evaluation result for change detection
var _previous_result: bool = false

## Check if the condition is met for the given ant
## @param ant The ant to check the condition for
## @param cache Dictionary to cache condition results
## @param params Dictionary containing context parameters
## @return True if the condition is met, false otherwise
func is_met(ant: Ant, cache: Dictionary, params: Dictionary) -> bool:
	var result := _evaluate(ant, cache, params)
	if result != _previous_result:
		_previous_result = result
		evaluation_changed.emit(result)
	return result

## Internal evaluation logic (to be overridden by specific conditions)
## @param ant The ant to evaluate the condition for
## @param cache Dictionary to cache condition results
## @param params Dictionary containing context parameters
## @return True if the condition is met, false otherwise
func _evaluate(_ant: Ant, _cache: Dictionary, _params: Dictionary) -> bool:
	return false

## Serialize the condition to a dictionary
func to_dict() -> Dictionary:
	return {
		"type": get_script().resource_path
	}

## Create a condition from a dictionary
static func from_dict(data: Dictionary) -> Condition:
	return load(data["type"]).new()

## Condition to check if food is in view
class FoodInView extends Condition:
	func _evaluate(_ant: Ant, _cache: Dictionary, params: Dictionary) -> bool:
		var is_food_visible: bool = not params.get("food_in_view", []).is_empty()
		return is_food_visible

## Condition to check if the ant is carrying food
class CarryingFood extends Condition:
	func _evaluate(_ant: Ant, _cache: Dictionary, params: Dictionary) -> bool:
		var carried_food = params.get("carried_food", 0)
		return carried_food > 0

## Condition to check if the ant is at the colony
class AtHome extends Condition:
	func _evaluate(_ant: Ant, _cache: Dictionary, params: Dictionary) -> bool:
		var distance_to_home = params.get("distance_to_home", float('inf'))
		return distance_to_home <= params.get("home_threshold", 0.0)

## Condition to check if there are food pheromones nearby
class FoodPheromoneSensed extends Condition:
	func _evaluate(_ant: Ant, _cache: Dictionary, params: Dictionary) -> bool:
		var food_pheromones = params.get("food_pheromones", [])
		return not food_pheromones.is_empty()

## Condition to check if there are home pheromones nearby
class HomePheromoneSensed extends Condition:
	func _evaluate(ant: Ant, _cache: Dictionary, _params: Dictionary) -> bool:
		return ant.is_pheromone_sensed("home")

## Condition to check if ant's energy is low
class LowEnergy extends Condition:
	## Energy threshold percentage below which condition is met
	var low_energy_threshold: float = 20.0
	
	func _evaluate(ant: Ant, _cache: Dictionary, _params: Dictionary) -> bool:
		return ant.energy.percentage < low_energy_threshold

## Condition to check if ant is carrying maximum food
class OverloadedWithFood extends Condition:
	func _evaluate(_ant: Ant, _cache: Dictionary, params: Dictionary) -> bool:
		var carried_food = params.get("carried_food", 0)
		var max_carry_capacity = params.get("max_carry_capacity", 0.0)
		var overload_threshold = params.get("overload_threshold", 0.9)
		return carried_food >= (max_carry_capacity * overload_threshold)
