class_name ConditionEvaluator
extends RefCounted

## Evaluate a condition based on configuration and context
## @param config The condition configuration from JSON
## @param context The context dictionary with property values
## @return Whether the condition is met
static func evaluate(condition: Dictionary, context: Dictionary) -> bool:
	var evaluation = condition
	
	# Handle property check evaluation
	if evaluation.type == "PropertyCheck":
		var property_value = context.get(evaluation.property)
		
		# Handle different types of comparisons
		if "value" in evaluation:
			# Direct value comparison
			return _evaluate_with_operator(
				property_value, 
				evaluation.value,
				evaluation.operator
			)
		elif "value_from" in evaluation:
			# Compare with another property value
			var compare_value = context.get(evaluation.value_from)
			return _evaluate_with_operator(
				property_value,
				compare_value,
				evaluation.operator
			)
		elif evaluation.operator in ["NOT_EMPTY", "IS_EMPTY"]:
			# Special cases for checking empty/non-empty
			return _evaluate_with_operator(
				property_value,
				null,
				evaluation.operator
			)
			
	# Handle compound conditions (AND, OR, NOT)
	elif evaluation.type == "Operator":
		match evaluation.operator_type:
			"and":
				for operand in evaluation.operands:
					if not evaluate(operand, context):
						return false
				return true
			"or":
				for operand in evaluation.operands:
					if evaluate(operand, context):
						return true
				return false
			"not":
				return not evaluate(evaluation.operands[0], context)
	
	push_error("Invalid condition evaluation type: %s" % evaluation.type)
	return false

## Evaluate using a specific operator
## @param value_a First value to compare
## @param value_b Second value to compare
## @param operator_type The type of comparison to perform
## @return Result of the comparison
static func _evaluate_with_operator(value_a: Variant, value_b: Variant, operator_type: String) -> bool:
	match operator_type:
		"EQUALS":
			return value_a == value_b
		"NOT_EQUALS":
			return value_a != value_b
		"GREATER_THAN":
			return value_a > value_b
		"LESS_THAN":
			return value_a < value_b
		"GREATER_THAN_EQUAL":
			return value_a >= value_b
		"LESS_THAN_EQUAL":
			return value_a <= value_b
		"NOT_EMPTY":
			return not _is_empty(value_a)
		"IS_EMPTY":
			return _is_empty(value_a)
		_:
			push_error("Unknown operator type: %s" % operator_type)
			return false

## Helper function to check if a value is empty
## @param value The value to check
## @return Whether the value is considered empty
static func _is_empty(value: Variant) -> bool:
	return value == null or \
		   (value is Array and value.is_empty()) or \
		   (value is Dictionary and value.is_empty()) or \
		   (value is String and value.is_empty())
