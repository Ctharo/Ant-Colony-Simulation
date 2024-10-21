class_name Condition
extends RefCounted

## Check if the condition is met for the given ant
## @param _ant The ant to check the condition for
## @param _cache Dictionary to cache condition results
## @return True if the condition is met, false otherwise
func is_met(_ant: Ant, _cache: Dictionary) -> bool:
	return false

## Condition that performs a specific check
class LeafCondition extends Condition:
	## The actual check to be performed
	var check: Callable
	
	## Unique identifier for this condition
	var condition_id: String
	
	## Initialize the LeafCondition
	## @param _check The callable to use for the condition check
	## @param _condition_id Unique identifier for this condition
	func _init(_check: Callable, _condition_id: String):
		check = _check
		condition_id = _condition_id
	
	## Check if the condition is met, using cache if available
	## @param ant The ant to check the condition for
	## @param cache Dictionary to cache condition results
	## @return True if the condition is met, false otherwise
	func is_met(ant: Ant, cache: Dictionary) -> bool:
		if condition_id in cache:
			return cache[condition_id]
		var result = check.call(ant)
		cache[condition_id] = result
		return result

## Condition that combines multiple conditions with AND logic
class AndCondition extends Condition:
	## List of conditions to be AND-ed together
	var conditions: Array[Condition] = []
	
	## Add a condition to the AND condition
	## @param condition The condition to add
	func add_condition(condition: Condition) -> void:
		conditions.append(condition)
	
	## Check if all conditions are met
	## @param ant The ant to check the conditions for
	## @param cache Dictionary to cache condition results
	## @return True if all conditions are met, false otherwise
	func is_met(ant: Ant, cache: Dictionary) -> bool:
		for condition in conditions:
			if not condition.is_met(ant, cache):
				return false
		return true

## Condition that combines multiple conditions with OR logic
class OrCondition extends Condition:
	## List of conditions to be OR-ed together
	var conditions: Array[Condition] = []
	
	## Add a condition to the OR condition
	## @param condition The condition to add
	func add_condition(condition: Condition) -> void:
		conditions.append(condition)
	
	## Check if any condition is met
	## @param ant The ant to check the conditions for
	## @param cache Dictionary to cache condition results
	## @return True if any condition is met, false otherwise
	func is_met(ant: Ant, cache: Dictionary) -> bool:
		for condition in conditions:
			if condition.is_met(ant, cache):
				return true
		return false

## Condition that negates another condition
class NotCondition extends Condition:
	## The condition to be negated
	var condition: Condition
	
	## Initialize the NotCondition
	## @param _condition The condition to negate
	func _init(_condition: Condition):
		condition = _condition
	
	## Check if the negated condition is not met
	## @param ant The ant to check the condition for
	## @param cache Dictionary to cache condition results
	## @return True if the negated condition is not met, false otherwise
	func is_met(ant: Ant, cache: Dictionary) -> bool:
		return not condition.is_met(ant, cache)

## Condition to check if there are no food pheromones sensed
class NoFoodPheromoneSensedCondition extends Condition:
	## The range to check for food pheromones
	var check_range: float = 50.0

	func is_met(ant: Ant, _cache: Dictionary) -> bool:
		var nearby_pheromones = ant.get_nearby_pheromones("food", check_range)
		return nearby_pheromones.is_empty()

## Condition to check if there are food pheromones nearby
class FoodPheromoneNearbyCondition extends Condition:
	## The range to check for food pheromones
	var check_range: float = 50.0

	func is_met(ant: Ant, _cache: Dictionary) -> bool:
		var nearby_pheromones = ant.get_nearby_pheromones("food", check_range)
		return not nearby_pheromones.is_empty()

## Condition to check if food is in view
class FoodInViewCondition extends Condition:
	func is_met(ant: Ant, _cache: Dictionary) -> bool:
		return ant.can_see_food()

## Condition to check if the ant is carrying food
class CarryingFoodCondition extends Condition:
	func is_met(ant: Ant, _cache: Dictionary) -> bool:
		return not ant.foods.is_empty()

## Condition to check if the ant is at the colony
class AtHomeCondition extends Condition:
	## The distance threshold to consider the ant at home
	var home_threshold: float = 10.0

	func is_met(ant: Ant, _cache: Dictionary) -> bool:
		return ant.global_position.distance_to(ant.colony.global_position) <= home_threshold

## Condition to check if there are home pheromones nearby
class HomePheromoneNearbyCondition extends Condition:
	## The range to check for home pheromones
	var check_range: float = 50.0

	func is_met(ant: Ant, _cache: Dictionary) -> bool:
		var nearby_pheromones = ant.get_nearby_pheromones("home", check_range)
		return not nearby_pheromones.is_empty()

## Condition to check if there are no home pheromones nearby
class NoHomePheromoneNearbyCondition extends Condition:
	## The range to check for home pheromones
	var check_range: float = 50.0

	func is_met(ant: Ant, _cache: Dictionary) -> bool:
		var nearby_pheromones = ant.get_nearby_pheromones("home", check_range)
		return nearby_pheromones.is_empty()

## Condition to check if the ant's energy is low
class LowEnergyCondition extends Condition:
	## The energy threshold to consider as low
	var energy_threshold: float = 30.0

	func is_met(ant: Ant, _cache: Dictionary) -> bool:
		return ant.energy.current <= energy_threshold

## Condition to check if the ant is overloaded with food
class OverloadedWithFoodCondition extends Condition:
	## The percentage of max capacity to consider as overloaded
	var overload_threshold: float = 0.9

	func is_met(ant: Ant, _cache: Dictionary) -> bool:
		return ant.foods.total_amount() >= (ant.foods.capacity * overload_threshold)
