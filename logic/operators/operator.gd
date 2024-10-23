class_name Operator
extends Condition

## List of conditions or operators to be evaluated
var operands: Array[Condition] = []


## Add an operand to the operator
## @param operand The condition or operator to add
func add_operand(operand: Condition) -> void:
	operands.append(operand)

## Serialize the operator to a dictionary
func to_dict() -> Dictionary:
	var base_dict := {
		"type": get_script().resource_path,
		"operator_type": _get_operator_type(),
		"operands": []
	}
	for operand in operands:
		base_dict["operands"].append(operand.to_dict())
	return base_dict

## Create an operator from a dictionary
## @param data Dictionary containing serialized operator data
## @return New operator instance
static func from_dict(data: Dictionary) -> Operator:
	var operator_type: String = data["operator_type"]
	var operator: Operator
	
	match operator_type:
		"and":
			operator = And.new()
		"or":
			operator = Or.new()
		"not":
			operator = Not.new()
		_:
			push_error("Unknown operator type: %s" % operator_type)
			return null
	
	for operand_data in data["operands"]:
		var operand := Condition.from_dict(operand_data)
		if operand:
			operator.add_operand(operand)
	
	return operator


## Get the type of operator for serialization
func _get_operator_type() -> String:
	return "base"

## Logical AND operator
class And extends Operator:
	## Check if all operands are met
	## @param ant The ant to check the conditions for
	## @param cache Dictionary to cache condition results
	## @param _params Dictionary containing context parameters
	## @return True if all operands are met, false otherwise
	func is_met(ant: Ant, cache: Dictionary, _params: Dictionary) -> bool:
		for operand in operands:
			if not operand.is_met(ant, cache, _params):
				return false
		return true
	
	func _get_operator_type() -> String:
		return "and"

## Logical OR operator
class Or extends Operator:
	## Check if any operand is met
	## @param ant The ant to check the conditions for
	## @param cache Dictionary to cache condition results
	## @param _params Dictionary containing context parameters
	## @return True if any operand is met, false otherwise
	func is_met(ant: Ant, cache: Dictionary, _params: Dictionary) -> bool:
		for operand in operands:
			if operand.is_met(ant, cache, _params):
				return true
		return false
	
	func _get_operator_type() -> String:
		return "or"

## Logical NOT operator
class Not extends Operator:
	## Check if the negated condition is not met
	## @param ant The ant to check the condition for
	## @param cache Dictionary to cache condition results
	## @param _params Dictionary containing context parameters
	## @return True if the negated condition is not met, false otherwise
	func is_met(ant: Ant, cache: Dictionary, _params: Dictionary) -> bool:
		if operands.size() != 1:
			push_error("NOT operator must have exactly one operand")
			return false
		return not operands[0].is_met(ant, cache, _params)
	
	func _get_operator_type() -> String:
		return "not"

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
	func is_met(ant: Ant, _cache: Dictionary, _params: Dictionary) -> bool:
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


## Create a compound condition using AND operator
static func and_condition(conditions: Array[Condition]) -> Condition:
	var and_op = Operator.And.new()
	for condition in conditions:
		and_op.add_operand(condition)
	return and_op

## Create a compound condition using OR operator
static func or_condition(conditions: Array[Condition]) -> Condition:
	var or_op = Operator.Or.new()
	for condition in conditions:
		or_op.add_operand(condition)
	return or_op

## Create a NOT condition
static func not_condition(condition: Condition) -> Condition:
	var not_op = Operator.Not.new()
	not_op.add_operand(condition)
	return not_op
	
