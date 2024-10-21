class_name Condition
extends RefCounted

## Check if the condition is met for the given ant
## Uses a cache to avoid redundant checks within a single update cycle
func is_met(_ant: Ant, _cache: Dictionary) -> bool:
	return false

class LeafCondition extends Condition:
	## The actual check to be performed
	var check: Callable
	
	## Unique identifier for this condition
	var condition_id: String
	
	func _init(_check: Callable, _condition_id: String):
		check = _check
		condition_id = _condition_id
	
	func is_met(ant: Ant, cache: Dictionary) -> bool:
		if condition_id in cache:
			return cache[condition_id]
		var result = check.call(ant)
		cache[condition_id] = result
		return result

class AndCondition extends Condition:
	## List of conditions to be AND-ed together
	var conditions: Array[Condition] = []
	
	func add_condition(condition: Condition) -> void:
		conditions.append(condition)
	
	func is_met(ant: Ant, cache: Dictionary) -> bool:
		for condition in conditions:
			if not condition.is_met(ant, cache):
				return false
		return true

class OrCondition extends Condition:
	## List of conditions to be OR-ed together
	var conditions: Array[Condition] = []
	
	func add_condition(condition: Condition) -> void:
		conditions.append(condition)
	
	func is_met(ant: Ant, cache: Dictionary) -> bool:
		for condition in conditions:
			if condition.is_met(ant, cache):
				return true
		return false

class NotCondition extends Condition:
	## The condition to be negated
	var condition: Condition
	
	func _init(_condition: Condition):
		condition = _condition
	
	func is_met(ant: Ant, cache: Dictionary) -> bool:
		return not condition.is_met(ant, cache)
