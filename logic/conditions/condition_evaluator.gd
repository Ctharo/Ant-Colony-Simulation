class_name ConditionEvaluator
extends RefCounted

## Evaluate a condition based on configuration and context
static func evaluate(condition: Dictionary, context: Dictionary, show_detailed_debug: bool = false) -> bool:
	# Handle operator type conditions (AND, OR, NOT)
	if condition.get("type") == "Operator":
		return _evaluate_operator_condition(condition, context, show_detailed_debug)
	
	# Handle named conditions that reference condition configs
	var condition_type = condition.get("type")
	if condition_type:
		var condition_configs = context.get("condition_configs", {})
		if condition_type in condition_configs:
			var full_condition = condition_configs[condition_type]
			# Check for raw evaluation object
			if full_condition.has("evaluation"):
				return _evaluate_property_check(full_condition.evaluation, context, show_detailed_debug)
			# If it's a direct dictionary of evaluation parameters
			elif full_condition.has("property"):
				return _evaluate_property_check(full_condition, context, show_detailed_debug)
		else:
			DebugLogger.error(DebugLogger.Category.CONDITION, 
				"Unknown condition type: %s (Available types: %s)" % [
					condition_type, 
					condition_configs.keys()
				]
			)
		return false
	
	# Handle direct property check evaluation
	if condition.has("evaluation"):
		return _evaluate_property_check(condition.evaluation, context, show_detailed_debug)
	elif condition.has("property"):
		return _evaluate_property_check(condition, context, show_detailed_debug)
	
	DebugLogger.error(DebugLogger.Category.CONDITION, "Invalid condition format: %s" % condition)
	return false

## Evaluate a compound operator condition (AND, OR, NOT)
static func _evaluate_operator_condition(condition: Dictionary, context: Dictionary, show_detailed_debug: bool) -> bool:
	var operator_type = condition.operator_type.to_lower()
	var operands = condition.get("operands", [])
	
	if show_detailed_debug:
		DebugLogger.debug(DebugLogger.Category.CONDITION, "\nEvaluating %s operator" % operator_type.to_upper())
	
	match operator_type:
		"and":
			for operand in operands:
				var result = evaluate(operand, context, show_detailed_debug)
				if show_detailed_debug:
					DebugLogger.trace(DebugLogger.Category.CONDITION, "  AND operand result: %s" % result)
				if not result:
					return false
			return true
			
		"or":
			for operand in operands:
				var result = evaluate(operand, context, show_detailed_debug)
				if show_detailed_debug:
					DebugLogger.trace(DebugLogger.Category.CONDITION, "  OR operand result: %s" % result)
				if result:
					return true
			return false
			
		"not":
			if operands.size() != 1:
				DebugLogger.error(DebugLogger.Category.CONDITION, "NOT operator requires exactly one operand")
				return false
			if show_detailed_debug:
				DebugLogger.debug(DebugLogger.Category.CONDITION, "├─ Evaluating NOT operand:")
			var operand_result = evaluate(operands[0], context, show_detailed_debug)
			var result = not operand_result
			if show_detailed_debug:
				DebugLogger.trace(DebugLogger.Category.CONDITION, 
					"└─ Final NOT result: %s (inverted from %s)" % [result, operand_result]
				)
			return result
			
		_:
			DebugLogger.error(DebugLogger.Category.CONDITION, "Unknown operator type: %s" % operator_type)
			return false

## Evaluate a property check condition
static func _evaluate_property_check(evaluation: Dictionary, context: Dictionary, show_detailed_debug: bool) -> bool:
	if not evaluation.has("property"):
		DebugLogger.error(DebugLogger.Category.CONDITION, 
			"Property check missing 'property' field: %s" % evaluation
		)
		return false
		
	var property_name = evaluation.property
	var property_value = context.get(property_name)
	var operator = evaluation.get("operator", "EQUALS")
	
	if show_detailed_debug:
		var debug_info = "  ├─ Checking property '%s'\n" % property_name
		debug_info += "  │  ├─ Current value: %s" % _format_value(property_value)
		DebugLogger.trace(DebugLogger.Category.CONDITION, debug_info)
	
	# Handle different value sources
	if "value" in evaluation:
		var compare_value = evaluation.value
		if show_detailed_debug:
			DebugLogger.trace(DebugLogger.Category.CONDITION,
				"  │  ├─ Comparing with fixed value: %s" % _format_value(compare_value)
			)
		var result = _compare_values(property_value, compare_value, operator)
		if show_detailed_debug:
			DebugLogger.trace(DebugLogger.Category.CONDITION, "  │  └─ Result: %s" % result)
		return result
		
	elif "value_from" in evaluation:
		var compare_prop = evaluation.value_from
		var compare_value = context.get(compare_prop)
		if show_detailed_debug:
			DebugLogger.trace(DebugLogger.Category.CONDITION,
				"  │  ├─ Comparing with '%s' value: %s" % [
					compare_prop, _format_value(compare_value)
				]
			)
		var result = _compare_values(property_value, compare_value, operator)
		if show_detailed_debug:
			DebugLogger.trace(DebugLogger.Category.CONDITION, "  │  └─ Result: %s" % result)
		return result
		
	elif operator in ["NOT_EMPTY", "IS_EMPTY"]:
		if show_detailed_debug:
			DebugLogger.trace(DebugLogger.Category.CONDITION,
				"  │  ├─ Checking if %s" % ("not empty" if operator == "NOT_EMPTY" else "empty")
			)
		var result = _compare_values(property_value, null, operator)
		if show_detailed_debug:
			DebugLogger.trace(DebugLogger.Category.CONDITION, "  │  └─ Result: %s" % result)
		return result
	
	DebugLogger.error(DebugLogger.Category.CONDITION, 
		"Invalid property check configuration: %s" % evaluation
	)
	return false

## Print debug information about condition evaluation
static func debug_print_condition(condition: Dictionary, context: Dictionary) -> void:
	var debug_info = "\nCondition Evaluation Debug:"
	debug_info += "\nCondition: %s" % JSON.stringify(condition, "\t")
	debug_info += "\nContext keys available: %s" % context.keys()
	
	if "condition_configs" in context:
		debug_info += "\nAvailable condition types: %s" % context.condition_configs.keys()
	
	DebugLogger.debug(DebugLogger.Category.CONDITION, debug_info)

## Helper methods remain unchanged as they don't produce output
static func _format_value(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "<null>"
		TYPE_ARRAY:
			if (value as Array).is_empty():
				return "[]"
			return str(value)
		TYPE_DICTIONARY:
			if (value as Dictionary).is_empty():
				return "{}"
			return str(value)
		TYPE_STRING:
			if (value as String).is_empty():
				return '""'
			return str(value)
		_:
			return str(value)

static func _compare_values(value_a: Variant, value_b: Variant, operator: String) -> bool:
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
			DebugLogger.error(DebugLogger.Category.CONDITION, "Unknown operator: %s" % operator)
			return false

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
