class_name PropertyEvaluator
extends BaseRefCounted
## Evaluates property expressions and handles value comparisons

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
#endregion

func _init(context: Dictionary = {}) -> void:
	_property_access = PropertyAccess.new(context.ant)

#region Value Comparison
## Evaluates a direct comparison between two values
func evaluate_comparison(value1: Variant, operator: String, value2: Variant) -> Result:
	if not COMPARISON_OPERATORS.has(operator):
		return Result.new(
			Result.ErrorType.INVALID_OPERATOR,
			"Unknown operator: %s" % operator
		)

	if value1 == null or value2 == null:
		return Result.new(
			Result.ErrorType.INVALID_VALUE,
			"Cannot compare null values"
		)

	var compare_func = COMPARISON_OPERATORS[operator]
	return Result.new(compare_func.call(value1, value2))

## Compare values of the same type
func compare_values(value1: Variant, value2: Variant, type: Property.Type) -> Result:
	if not _is_type_match(value1, type) or not _is_type_match(value2, type):
		return Result.new(
			Result.ErrorType.TYPE_MISMATCH,
			"Values do not match expected type: %s" % Property.type_to_string(type)
		)

	return Result.new(value1 == value2)
#endregion

#region Type Conversion
## Converts a value to the specified Property.Type
func convert_value(value: Variant, target_type: Property.Type) -> Result:
	if value == null:
		return Result.new(
			Result.ErrorType.INVALID_VALUE,
			"Cannot convert null value"
		)

	if _is_type_match(value, target_type):
		return Result.new(value)

	var method = TYPE_CONVERSIONS.get(target_type)
	if not method or not has_method(method):
		return Result.new(
			Result.ErrorType.TYPE_MISMATCH,
			"Cannot convert to type: %s" % target_type
		)

	return call(method, value)
#endregion

#region Helper Methods
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
func _is_type_match(value: Variant, expected_type: int) -> bool:
	return typeof(value) == expected_type
#endregion
