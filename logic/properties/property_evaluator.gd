class_name PropertyEvaluator
extends RefCounted
## Evaluates property expressions and handles value comparisons
##
## Focuses on property expression evaluation, value comparison,
## and type conversion without handling higher-level condition logic.

#region Constants
var COMPARISON_OPERATORS = {
	"==": func(a, b): return a == b,
	"!=": func(a, b): return a != b,
	">": func(a, b): return a > b if _are_comparable(a, b) else false,
	"<": func(a, b): return a < b if _are_comparable(a, b) else false,
	">=": func(a, b): return a >= b if _are_comparable(a, b) else false,
	"<=": func(a, b): return a <= b if _are_comparable(a, b) else false,
	"contains": func(a, b): return _contains_value(a, b),
	"starts_with": func(a, b): return str(a).begins_with(str(b)) if a != null and b != null else false,
	"ends_with": func(a, b): return str(a).ends_with(str(b)) if a != null and b != null else false
}

const TYPE_CONVERSIONS = {
	TYPE_STRING: "_to_string",
	TYPE_INT: "_to_int",
	TYPE_FLOAT: "_to_float",
	TYPE_BOOL: "_to_bool",
	TYPE_VECTOR2: "_to_vector2",
	TYPE_VECTOR3: "_to_vector3",
	TYPE_ARRAY: "_to_array",
	TYPE_DICTIONARY: "_to_dictionary"
}
#endregion

#region Member Variables
var _property_access: PropertyAccess
var _cache: PropertyCache
#endregion

func _init(context: Dictionary = {}) -> void:
	_property_access = PropertyAccess.new(context.ant)
	_cache = PropertyCache.new()

#region Expression Evaluation
## Evaluates a property expression
## Expression format: "property_name operator value" or "property_name"
## Returns: PropertyResult with evaluation result
func evaluate_expression(expression: String, context: Dictionary = {}) -> PropertyResult:
	# Check cache
	var cache_key = _get_cache_key(expression, context)
	if _cache.has_valid_cache(cache_key):
		return PropertyResult.new(_cache.get_cached(cache_key))
	
	# Parse expression
	var parsed = _parse_expression(expression)
	if not parsed.success():
		return parsed
	
	# Evaluate parsed expression
	var result = _evaluate_parsed_expression(parsed.value, context)
	
	# Cache successful results
	if result.success():
		_cache.cache_value(cache_key, result.value)
	
	return result

## Evaluates a direct comparison between two values
## Returns: PropertyResult with boolean result
func evaluate_comparison(
	value1: Variant,
	operator: String,
	value2: Variant
) -> PropertyResult:
	if not COMPARISON_OPERATORS.has(operator):
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.INVALID_PATH,
			"Unknown operator: %s" % operator
		)
	
	var compare_func = COMPARISON_OPERATORS[operator]
	return PropertyResult.new(compare_func.call(value1, value2))
#endregion

#region Type Conversion
## Converts a value to the specified Component.PropertyType
## Returns: PropertyResult with converted value
func convert_value(value: Variant, target_type: Component.PropertyType) -> PropertyResult:
	if _is_type_match(value, target_type):
		return PropertyResult.new(value)
	
	var method = TYPE_CONVERSIONS.get(target_type)
	if not method or not has_method(method):
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.TYPE_MISMATCH,
			"Cannot convert to type: %s" % Component.type_to_string(target_type)
		)
	
	return call(method, value)
#endregion

#region Expression Parsing
## Parses an expression into components
func _parse_expression(expression: String) -> PropertyResult:
	var parts = expression.strip_edges().split(" ", false)
	
	match parts.size():
		# Simple property reference
		1:
			return PropertyResult.new({
				"type": "property",
				"path": parts[0]
			})
		
		# Property comparison
		3:
			return PropertyResult.new({
				"type": "comparison",
				"left": parts[0],
				"operator": parts[1],
				"right": parts[2]
			})
		
		_:
			return PropertyResult.new(
				null,
				PropertyResult.ErrorType.INVALID_PATH,
				"Invalid expression format: %s" % expression
			)

## Evaluates a parsed expression
func _evaluate_parsed_expression(parsed: Dictionary, context: Dictionary) -> PropertyResult:
	match parsed.type:
		"property":
			return _property_access.get_property(parsed.path)
		
		"comparison":
			var left = _property_access.get_property(parsed.left)
			if not left.success():
				return left
			
			# Handle direct value comparison
			if parsed.right.begins_with('"') and parsed.right.ends_with('"'):
				var right_value = parsed.right.substr(1, parsed.right.length() - 2)
				return evaluate_comparison(left.value, parsed.operator, right_value)
			
			# Handle property comparison
			var right = _property_access.get_property(parsed.right)
			if not right.success():
				return right
			
			return evaluate_comparison(left.value, parsed.operator, right.value)
	
	return PropertyResult.new(
		null,
		PropertyResult.ErrorType.INVALID_PATH,
		"Unknown expression type: %s" % parsed.type
	)
#endregion

#region Helper Methods
## Gets cache key for an expression
func _get_cache_key(expression: String, context: Dictionary) -> String:
	return "%s|%s" % [expression, str(context)]

## Checks if values are comparable
static func _are_comparable(a: Variant, b: Variant) -> bool:
	var type_a = typeof(a)
	var type_b = typeof(b)
	
	if type_a == type_b:
		return true
	
	if type_a in [TYPE_INT, TYPE_FLOAT] and type_b in [TYPE_INT, TYPE_FLOAT]:
		return true
	
	return false

## Checks if a value contains another value
static func _contains_value(container: Variant, value: Variant) -> bool:
	match typeof(container):
		TYPE_STRING:
			return (container as String).contains(str(value))
		TYPE_ARRAY:
			return (container as Array).has(value)
		TYPE_DICTIONARY:
			return (container as Dictionary).has(value)
	return false

## Checks if value matches expected type
func _is_type_match(value: Variant, expected_type: Component.PropertyType) -> bool:
	match expected_type:
		Component.PropertyType.BOOL:
			return typeof(value) == TYPE_BOOL
		Component.PropertyType.INT:
			return typeof(value) == TYPE_INT
		Component.PropertyType.FLOAT:
			return typeof(value) == TYPE_FLOAT
		Component.PropertyType.STRING:
			return typeof(value) == TYPE_STRING
		Component.PropertyType.VECTOR2:
			return value is Vector2
		Component.PropertyType.VECTOR3:
			return value is Vector3
		Component.PropertyType.ARRAY:
			return value is Array
		Component.PropertyType.DICTIONARY:
			return value is Dictionary
		Component.PropertyType.OBJECT:
			return value is Object
	return false

## Formats a value for display
static func format_value(value: Variant) -> String:
	return PropertyResult.format_value(value)
#endregion
