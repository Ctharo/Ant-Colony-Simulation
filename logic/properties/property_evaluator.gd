class_name PropertyEvaluator
extends RefCounted

## Error codes for property access
enum ErrorCode {
	SUCCESS,
	INVALID_PATH,
	INVALID_ATTRIBUTE,
	INVALID_PROPERTY,
	INVALID_METHOD,
	ACCESS_ERROR
}

## Result structure for property access
class PropertyResult:
	var value: Variant
	var error: ErrorCode
	var error_message: String
	
	func _init(p_value: Variant = null, p_error: ErrorCode = ErrorCode.SUCCESS, p_message: String = ""):
		value = p_value
		error = p_error
		error_message = p_message
	
	func is_error() -> bool:
		return error != ErrorCode.SUCCESS

## Format a value for consistent string representation
static func format_value(value: Variant) -> String:
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
			return '"%s"' % value
		TYPE_FLOAT:
			return "%.2f" % value
		TYPE_VECTOR2:
			var v = value as Vector2
			return "(%.1f, %.1f)" % [v.x, v.y]
		TYPE_BOOL:
			return "true" if value else "false"
		_:
			return str(value)

## Get a property value either from context or through ant attributes
static func get_property_value(property_path: String, context: Dictionary) -> PropertyResult:
	# First try getting from context (existing behavior)
	if property_path in context:
		return PropertyResult.new(context[property_path])
		
	# If not in context, check if we can access through ant attributes
	var ant = context.get("ant")
	if not ant:
		return PropertyResult.new(null, ErrorCode.ACCESS_ERROR, "No ant reference in context")
		
	# Check if it's a direct method call
	var method_result = ant.get_method_result(property_path)
	if method_result != null:
		return PropertyResult.new(method_result)
	
	# Try attribute property access
	var segments = property_path.split(".")
	if segments.size() != 2:
		return PropertyResult.new(
			null, 
			ErrorCode.INVALID_PATH,
			"Invalid property path format. Expected 'attribute.property'"
		)
	
	var attribute_name = segments[0]
	var property_name = segments[1]
	
	if not attribute_name in ant.exposed_attributes:
		return PropertyResult.new(
			null,
			ErrorCode.INVALID_ATTRIBUTE,
			"Invalid attribute: %s" % attribute_name
		)
	
	var attribute = ant.exposed_attributes[attribute_name]
	var value = attribute.get_property(property_name)
	if value == null:
		return PropertyResult.new(
			null,
			ErrorCode.INVALID_PROPERTY,
			"Invalid property '%s' for attribute '%s'" % [property_name, attribute_name]
		)
	
	return PropertyResult.new(value)

## Compare two values using the specified operator
static func compare_values(value_a: Variant, value_b: Variant, operator: String) -> bool:
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

## Helper function to check if a value is empty
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
