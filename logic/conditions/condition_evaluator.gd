class_name ConditionEvaluator
extends RefCounted

## Evaluate a condition based on configuration and context
## @param config The condition configuration from JSON
## @param context The context dictionary with property values
## @return Whether the condition is met
static func evaluate(condition: Dictionary, context: Dictionary) -> bool:
	# Handle operator type conditions (AND, OR, NOT)
	if condition.get("type") == "Operator":
		return _evaluate_operator_condition(condition, context)
	
	# Handle named conditions that reference condition configs
	var condition_type = condition.get("type")
	if condition_type:
		var condition_configs = context.get("condition_configs", {})
		if condition_type in condition_configs:
			var full_condition = condition_configs[condition_type]
			# Check for raw evaluation object
			if full_condition.has("evaluation"):
				return _evaluate_property_check(full_condition.evaluation, context)
			# If it's a direct dictionary of evaluation parameters
			elif full_condition.has("property"):
				return _evaluate_property_check(full_condition, context)
		else:
			push_error("Unknown condition type: %s (Available types: %s)" % [
				condition_type, 
				condition_configs.keys()
			])
		return false
	
	# Handle direct property check evaluation
	if condition.has("evaluation"):
		return _evaluate_property_check(condition.evaluation, context)
	elif condition.has("property"):
		return _evaluate_property_check(condition, context)
	
	push_error("Invalid condition format: %s" % condition)
	return false

## Evaluate a compound operator condition (AND, OR, NOT)
## @param condition The operator condition configuration
## @param context The context dictionary
## @return Result of the operator evaluation
static func _evaluate_operator_condition(condition: Dictionary, context: Dictionary) -> bool:
	var operator_type = condition.operator_type.to_lower()
	var operands = condition.get("operands", [])
	
	match operator_type:
		"and":
			for operand in operands:
				if not evaluate(operand, context):
					return false
			return true
			
		"or":
			for operand in operands:
				if evaluate(operand, context):
					return true
			return false
			
		"not":
			if operands.size() != 1:
				push_error("NOT operator requires exactly one operand")
				return false
			return not evaluate(operands[0], context)
			
		_:
			push_error("Unknown operator type: %s" % operator_type)
			return false

## Evaluate a property check condition
## @param evaluation The property check configuration
## @param context The context dictionary
## @return Result of the property check
static func _evaluate_property_check(evaluation: Dictionary, context: Dictionary) -> bool:
	if not evaluation.has("property"):
		push_error("Property check missing 'property' field: %s" % evaluation)
		return false
		
	var property_value = context.get(evaluation.property)
	var operator = evaluation.get("operator", "EQUALS")
	
	# Add debugging for property check
	if OS.is_debug_build():
		print("Checking property '%s' with operator '%s'" % [evaluation.property, operator])
		print("Property value: ", property_value)
		if "value" in evaluation:
			print("Compare value: ", evaluation.value)
		elif "value_from" in evaluation:
			print("Compare value from: ", evaluation.value_from, " = ", context.get(evaluation.value_from))
	
	# Handle different value sources
	if "value" in evaluation:
		return _compare_values(property_value, evaluation.value, operator)
	elif "value_from" in evaluation:
		var compare_value = context.get(evaluation.value_from)
		return _compare_values(property_value, compare_value, operator)
	elif operator in ["NOT_EMPTY", "IS_EMPTY"]:
		return _compare_values(property_value, null, operator)
	
	push_error("Invalid property check configuration: %s" % evaluation)
	return false

## Compare two values using the specified operator
## @param value_a First value to compare
## @param value_b Second value to compare
## @param operator The comparison operator to use
## @return Result of the comparison
static func _compare_values(value_a: Variant, value_b: Variant, operator: String) -> bool:
	# Add debug output for comparison
	if OS.is_debug_build():
		print("Comparing values: %s %s %s" % [value_a, operator, value_b])
		
	match operator:
		"EQUALS":
			return value_a == value_b
		"NOT_EQUALS":
			return value_a != value_b
		"GREATER_THAN":
			return value_a > value_b if value_a != null and value_b != null else false
		"LESS_THAN":
			return value_a < value_b if value_a != null and value_b != null else false
		"GREATER_THAN_EQUAL":
			return value_a >= value_b if value_a != null and value_b != null else false
		"LESS_THAN_EQUAL":
			return value_a <= value_b if value_a != null and value_b != null else false
		"NOT_EMPTY":
			return not _is_empty(value_a)
		"IS_EMPTY":
			return _is_empty(value_a)
		_:
			push_error("Unknown operator: %s" % operator)
			return false

## Check if a value is considered empty
## @param value The value to check
## @return Whether the value is empty
static func _is_empty(value: Variant) -> bool:
	if value == null:
		return true
	
	match typeof(value):
		TYPE_ARRAY:
			return (value as Array).is_empty()
		TYPE_DICTIONARY:
			return (value as Dictionary).is_empty()
		TYPE_STRING:
			return (value as String).is_empty()
		_:
			return false

## Print debug information about condition evaluation
## @param condition The condition being evaluated
## @param context The context dictionary
static func debug_print_condition(condition: Dictionary, context: Dictionary) -> void:
	print("\nEvaluating condition:")
	print("Condition: ", JSON.stringify(condition, "\t"))
	print("Available context keys: ", context.keys())
	if "condition_configs" in context:
		print("Available condition types: ", context.condition_configs.keys())
