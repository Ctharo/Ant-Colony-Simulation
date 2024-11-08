class_name ConditionEvaluator
extends RefCounted
## Evaluates complex conditions using structured configurations
##
## Handles high-level condition logic (AND, OR, NOT) and structured condition
## configurations while delegating property comparisons to PropertyEvaluator.

#region Member Variables
var _property_access: PropertyAccess
var _property_evaluator: PropertyEvaluator
# Map condition operators to PropertyEvaluator operators
const OPERATOR_MAP = {
	"EQUALS": "==",
	"NOT_EQUALS": "!=",
	"GREATER_THAN": ">",
	"LESS_THAN": "<",
	"GREATER_THAN_EQUAL": ">=",
	"LESS_THAN_EQUAL": "<=",
	"CONTAINS": "contains",
	"STARTS_WITH": "starts_with",
	"ENDS_WITH": "ends_with"
}
#endregion

func _init(context: Dictionary = {}) -> void:
	_property_access = PropertyAccess.new(context.ant)

#region Public Interface
## Evaluate a condition based on configuration and context
func evaluate(condition: Dictionary, context: Dictionary) -> bool:
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
			_log_error("Unknown condition type: %s (Available types: %s)" % [
				condition_type, 
				condition_configs.keys()
			])
		return false
	
	# Handle direct property check evaluation
	if condition.has("evaluation"):
		return _evaluate_property_check(condition.evaluation, context)
	elif condition.has("property"):
		return _evaluate_property_check(condition, context)
	
	_log_error("Invalid condition format: %s" % condition)
	return false
#endregion

#region Condition Evaluation
## Evaluate a compound operator condition (AND, OR, NOT)
func _evaluate_operator_condition(condition: Dictionary, context: Dictionary) -> bool:
	var operator_type = condition.operator_type.to_lower()
	var operands = condition.get("operands", [])
	
	_log_debug("\nEvaluating %s operator" % operator_type.to_upper())
	
	match operator_type:
		"and":
			for operand in operands:
				var result = evaluate(operand, context)
				_log_trace("  AND operand result: %s" % result)
				if not result:
					return false
			return true
			
		"or":
			for operand in operands:
				var result = evaluate(operand, context)
				_log_trace("  OR operand result: %s" % result)
				if result:
					return true
			return false
			
		"not":
			if operands.size() != 1:
				_log_error("NOT operator requires exactly one operand")
				return false
			var result = not evaluate(operands[0], context)
			_log_trace("  NOT result: %s" % result)
			return result
			
		_:
			_log_error("Unknown operator type: %s" % operator_type)
			return false

## Evaluate a property check condition
func _evaluate_property_check(evaluation: Dictionary, context: Dictionary) -> bool:
	if not evaluation.has("property"):
		_log_error("Property check missing 'property' field: %s" % evaluation)
		return false
	
	var property_name = evaluation.property
	var operator = evaluation.get("operator", "EQUALS")
	
	# Get the property value using PropertyAccess
	var property_result = _property_access.get_property(property_name)
	if property_result.is_error():
		_log_error(property_result.error_message)
		return false
	
	var property_value = property_result.value
	
	var debug_info = "  ├─ Checking property '%s'\n" % property_name
	debug_info += "  │  ├─ Current value: %s" % PropertyEvaluator.format_value(property_value)
	_log_trace(debug_info)
	
	# Special handling for empty checks
	if operator in ["NOT_EMPTY", "IS_EMPTY"]:
		var is_empty = _is_empty(property_value)
		_log_trace("  │  ├─ Checking if %s (result: %s)" % [
			"not empty" if operator == "NOT_EMPTY" else "empty",
			not is_empty if operator == "NOT_EMPTY" else is_empty
		])
		return not is_empty if operator == "NOT_EMPTY" else is_empty
	
	# Handle different value sources using PropertyEvaluator for comparison
	if "value" in evaluation:
		var compare_value = evaluation.value
		_log_trace("  │  ├─ Comparing with fixed value: %s" % \
			PropertyEvaluator.format_value(compare_value))
		return _compare_values(property_value, compare_value, operator)
		
	elif "value_from" in evaluation:
		var compare_prop_result = _property_access.get_property(evaluation.value_from)
		if compare_prop_result.is_error():
			_log_error(compare_prop_result.error_message)
			return false
			
		var compare_value = compare_prop_result.value
		_log_trace("  │  ├─ Comparing with '%s' value: %s" % [
			evaluation.value_from, 
			PropertyEvaluator.format_value(compare_value)
		])
		return _compare_values(property_value, compare_value, operator)
	
	_log_error("Invalid property check configuration: %s" % evaluation)
	return false

## Compare values using PropertyEvaluator
func _compare_values(value_a: Variant, value_b: Variant, operator: String) -> bool:
	# Map condition operator to PropertyEvaluator operator
	var eval_operator = OPERATOR_MAP.get(operator)
	if not eval_operator:
		push_warning("Unknown operator: %s" % operator)
		return false
	
	var result = _property_evaluator.evaluate_comparison(
		value_a,
		eval_operator,
		value_b
	)
	
	return result.value if result.success() else false
#endregion

#region Helper Methods
## Check if a value is empty
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

## Logging helpers
func _log_error(message: String) -> void:
	DebugLogger.error(DebugLogger.Category.CONDITION, message)

func _log_debug(message: String) -> void:
	DebugLogger.debug(DebugLogger.Category.CONDITION, message)

func _log_trace(message: String) -> void:
	DebugLogger.trace(DebugLogger.Category.CONDITION, message)
#endregion
