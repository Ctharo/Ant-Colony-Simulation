class_name Condition
extends RefCounted

## Check if the condition is met for the given ant
## @param _ant The ant to check the condition for
## @param _cache Dictionary to cache condition results
## @param _params Dictionary containing context parameters
## @return True if the condition is met, false otherwise
func is_met(_ant: Ant, _cache: Dictionary, _params: Dictionary) -> bool:
	return false


## Condition for comparing numeric values
class Comparison extends Condition:
	enum ComparisonType { LESS, LESS_EQUAL, EQUAL, NOT_EQUAL, GREATER_EQUAL, GREATER }
	
	## The left-hand side of the comparison (can be a Callable or a static value)
	var lhs: Variant
	
	## The right-hand side of the comparison (can be a Callable or a static value)
	var rhs: Variant
	
	## The operator to use for comparison
	var comparison_type: ComparisonType
	
	## Initialize the Comparison condition
	## @param _lhs Left-hand side of the comparison
	## @param _comparison_type The comparison type
	## @param _rhs Right-hand side of the comparison
	func _init(_lhs: Variant, _comparison_type: ComparisonType, _rhs: Variant):
		lhs = _lhs
		comparison_type = _comparison_type
		rhs = _rhs
	
	## Check if the comparison condition is met
	## @param ant The ant to check the condition for
	## @param cache Dictionary to cache condition results
	## @param params Dictionary containing context parameters
	## @return True if the condition is met, false otherwise
	func is_met(ant: Ant, cache: Dictionary, params: Dictionary) -> bool:
		var lhs_value = lhs.call(ant, params) if lhs is Callable else lhs
		var rhs_value = rhs.call(ant, params) if rhs is Callable else rhs
		
		match comparison_type:
			ComparisonType.LESS:
				return lhs_value < rhs_value
			ComparisonType.LESS_EQUAL:
				return lhs_value <= rhs_value
			ComparisonType.EQUAL:
				return lhs_value == rhs_value
			ComparisonType.NOT_EQUAL:
				return lhs_value != rhs_value
			ComparisonType.GREATER_EQUAL:
				return lhs_value >= rhs_value
			ComparisonType.GREATER:
				return lhs_value > rhs_value
		
		return false

## Condition to check if food is in view
class FoodInView extends Condition:
	
	func is_met(ant: Ant, _cache: Dictionary, params: Dictionary) -> bool:
		var is_food_visible: bool = not params.get("food_in_view", []).is_empty()
		return is_food_visible

## Condition to check if the ant is carrying food
class CarryingFood extends Condition:
	func is_met(_ant: Ant, _cache: Dictionary, params: Dictionary) -> bool:
		var carried_food = params.get("carried_food", 0)
		return carried_food > 0

## Condition to check if the ant is at the colony
class AtHome extends Condition:
	func is_met(_ant: Ant, _cache: Dictionary, params: Dictionary) -> bool:
		var distance_to_home = params.get("distance_to_home", float('inf'))
		return distance_to_home <= params.get("home_threshold", 0.0)

## Condition to check if there are food pheromones nearby
class FoodPheromoneSensed extends Condition:
	func is_met(_ant: Ant, _cache: Dictionary, params: Dictionary) -> bool:
		var food_pheromones = params.get("food_pheromones", [])
		return not food_pheromones.is_empty()

## Condition to check if there are home pheromones nearby
class HomePheromoneSensed extends Condition:
	
	func is_met(ant: Ant, _cache: Dictionary, _params: Dictionary) -> bool:
		return ant.is_pheromone_sensed("home")

## Condition to check if there are home pheromones nearby
class LowEnergy extends Condition:
	var low_energy_threshold: float = 20.0
	func is_met(ant: Ant, _cache: Dictionary, _params: Dictionary) -> bool:
		return ant.energy.precentage < low_energy_threshold

class OverloadedWithFood extends Condition:
	func is_met(_ant: Ant, _cache: Dictionary, params: Dictionary) -> bool:
		var carried_food = params.get("carried_food", 0)
		var max_carry_capacity = params.get("max_carry_capacity", 0.0)
		var overload_threshold = params.get("overload_threshold", 0.9)
		return carried_food >= (max_carry_capacity * overload_threshold)
