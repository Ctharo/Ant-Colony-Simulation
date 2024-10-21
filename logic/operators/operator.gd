class_name Operator
extends Condition

## List of conditions or operators to be evaluated
var operands: Array[Condition] = []


## Add an operand to the operator
## @param operand The condition or operator to add
func add_operand(operand: Condition) -> void:
	operands.append(operand)

## Condition that performs a specific check
class LeafCondition extends Operator:
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


## Logical AND operator
class And extends Operator:
	## Check if all operands are met
	## @param ant The ant to check the conditions for
	## @param cache Dictionary to cache condition results
	## @param params Dictionary containing context parameters
	## @return True if all operands are met, false otherwise
	func is_met(ant: Ant, cache: Dictionary, params: Dictionary) -> bool:
		for operand in operands:
			if not operand.is_met(ant, cache, params):
				return false
		return true

## Logical OR operator
class Or extends Operator:
	## Check if any operand is met
	## @param ant The ant to check the conditions for
	## @param cache Dictionary to cache condition results
	## @param params Dictionary containing context parameters
	## @return True if any operand is met, false otherwise
	func is_met(ant: Ant, cache: Dictionary, params: Dictionary) -> bool:
		for operand in operands:
			if operand.is_met(ant, cache, params):
				return true
		return false

## Logical NOT operator
class Not extends Operator:
	## Initialize the NOT operator
	## @param operand The condition to negate
	func _init(operand: Condition):
		add_operand(operand)
	
	## Check if the negated condition is not met
	## @param ant The ant to check the condition for
	## @param cache Dictionary to cache condition results
	## @param params Dictionary containing context parameters
	## @return True if the negated condition is not met, false otherwise
	func is_met(ant: Ant, cache: Dictionary, params: Dictionary) -> bool:
		return not operands[0].is_met(ant, cache, params)

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

