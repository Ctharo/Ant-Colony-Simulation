class_name Condition
extends RefCounted

## Check if the condition is met for the given ant
## @param _ant The ant to check the condition for
## @param _cache Dictionary to cache condition results
## @param _params Dictionary containing context parameters
## @return True if the condition is met, false otherwise
func is_met(_ant: Ant, _cache: Dictionary, _params: Dictionary) -> bool:
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
	## @param params Dictionary containing context parameters
	## @return True if the condition is met, false otherwise
	func is_met(ant: Ant, cache: Dictionary, params: Dictionary) -> bool:
		if condition_id in cache:
			return cache[condition_id]
		var result = check.call(ant, params)
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
	## @param params Dictionary containing context parameters
	## @return True if all conditions are met, false otherwise
	func is_met(ant: Ant, cache: Dictionary, params: Dictionary) -> bool:
		for condition in conditions:
			if not condition.is_met(ant, cache, params):
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
	## @param params Dictionary containing context parameters
	## @return True if any condition is met, false otherwise
	func is_met(ant: Ant, cache: Dictionary, params: Dictionary) -> bool:
		for condition in conditions:
			if condition.is_met(ant, cache, params):
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
	## @param params Dictionary containing context parameters
	## @return True if the negated condition is not met, false otherwise
	func is_met(ant: Ant, cache: Dictionary, params: Dictionary) -> bool:
		return not condition.is_met(ant, cache, params)

## Condition for comparing numeric values
class ComparisonCondition extends Condition:
	enum Operator { LESS, LESS_EQUAL, EQUAL, NOT_EQUAL, GREATER_EQUAL, GREATER }
	
	## The left-hand side of the comparison (can be a Callable or a static value)
	var lhs: Variant
	
	## The right-hand side of the comparison (can be a Callable or a static value)
	var rhs: Variant
	
	## The operator to use for comparison
	var operator: Operator
	
	## Initialize the ComparisonCondition
	## @param _lhs Left-hand side of the comparison
	## @param _operator The comparison operator
	## @param _rhs Right-hand side of the comparison
	func _init(_lhs: Variant, _operator: Operator, _rhs: Variant):
		lhs = _lhs
		operator = _operator
		rhs = _rhs
	
	## Check if the comparison condition is met
	## @param ant The ant to check the condition for
	## @param cache Dictionary to cache condition results
	## @param params Dictionary containing context parameters
	## @return True if the condition is met, false otherwise
	func is_met(ant: Ant, cache: Dictionary, params: Dictionary) -> bool:
		var lhs_value = lhs.call(ant, params) if lhs is Callable else lhs
		var rhs_value = rhs.call(ant, params) if rhs is Callable else rhs
		
		match operator:
			Operator.LESS:
				return lhs_value < rhs_value
			Operator.LESS_EQUAL:
				return lhs_value <= rhs_value
			Operator.EQUAL:
				return lhs_value == rhs_value
			Operator.NOT_EQUAL:
				return lhs_value != rhs_value
			Operator.GREATER_EQUAL:
				return lhs_value >= rhs_value
			Operator.GREATER:
				return lhs_value > rhs_value
		
		return false

## Condition to check if food is in view
class FoodInViewCondition extends Condition:
	
	func is_met(ant: Ant, _cache: Dictionary, _params: Dictionary) -> bool:
		return ant.is_food_in_view()

## Condition to check if the ant is carrying food
class CarryingFoodCondition extends Condition:
	
	func is_met(ant: Ant, _cache: Dictionary, _params: Dictionary) -> bool:
		return ant.is_carrying_food()

## Condition to check if the ant is at the colony
class AtHomeCondition extends Condition:

	func is_met(ant: Ant, _cache: Dictionary, _params: Dictionary) -> bool:
		return ant.is_at_home()

## Condition to check if there are food pheromones nearby
class FoodPheromoneSensedCondition extends Condition:
	
	func is_met(ant: Ant, _cache: Dictionary, _params: Dictionary) -> bool:
		return ant.is_pheromone_sensed("food")

## Condition to check if there are home pheromones nearby
class HomePheromoneSensedCondition extends Condition:
	
	func is_met(ant: Ant, _cache: Dictionary, _params: Dictionary) -> bool:
		return ant.is_pheromone_sensed("home")


