## Base class for all property-related results
class_name PropertyResult
extends RefCounted

enum ErrorType {
	NONE,
	INVALID_PATH,        # Property path format is invalid
	NO_CONTEXT,         # Required context object missing
	NO_CONTAINER,       # Container object not found
	PROPERTY_NOT_FOUND, # Property doesn't exist
	ACCESS_ERROR,       # Error accessing property
	TYPE_MISMATCH,      # Property value type doesn't match expected
	DUPLICATE_PROPERTY, # Property already exists
	INVALID_GETTER,     # Getter method is invalid
	INVALID_SETTER,     # Setter method is invalid
	CACHE_ERROR        # Error with cache operations
}

var value: Variant
var error: ErrorType
var error_message: String

func _init(p_value: Variant = null, p_error: ErrorType = ErrorType.NONE, p_message: String = "") -> void:
	value = p_value
	error = p_error
	error_message = p_message

func success() -> bool:
	return error == ErrorType.NONE

## Property information structure
class PropertyInfo:
	var name: String
	var type: Component.PropertyType
	var value: Variant
	var getter: Callable
	var setter: Callable
	var category: String
	var description: String
	var metadata: Dictionary
	var writable: bool
	
	func _init(
		p_name: String,
		p_type: Component.PropertyType,
		p_value: Variant,
		p_getter: Callable,
		p_setter: Callable = Callable(),
		p_category: String = "",
		p_description: String = "",
		p_metadata: Dictionary = {}
	) -> void:
		name = p_name
		type = p_type
		value = p_value
		getter = p_getter
		setter = p_setter
		category = p_category
		description = p_description
		metadata = p_metadata
		writable = setter.is_valid()
	
	func to_dict() -> Dictionary:
		return {
			"name": name,
			"type": Component.type_to_string(type),
			"value": value,
			"category": category,
			"writable": writable,
			"description": description,
			"metadata": metadata
		}


## Standardized category information structure
class CategoryInfo:
	var name: String
	var properties: Array[PropertyInfo]
	var metadata: Dictionary  # For any additional category-specific data
	
	func _init(p_name: String, p_metadata: Dictionary = {}) -> void:
		name = p_name
		properties = []
		metadata = p_metadata
	
	func add_property(property: PropertyInfo) -> void:
		properties.append(property)
	
	func to_dict() -> Dictionary:
		return {
			"name": name,
			"properties": properties.map(func(p): return p.to_dict()),
			"metadata": metadata
		}

## Interface for property container operations
class IPropertyContainer:
	## Property Operations
	func get_property_value(name: String) -> PropertyResult:
		return PropertyResult.new(null, PropertyResult.ErrorType.ACCESS_ERROR, "Not implemented")
		
	func set_property_value(name: String, value: Variant) -> PropertyResult:
		return PropertyResult.new(null, PropertyResult.ErrorType.ACCESS_ERROR, "Not implemented")
		
	func has_property(name: String) -> bool:
		return false
		
	func get_property_info(name: String) -> PropertyInfo:
		return null
		
	func get_properties() -> Array[String]:
		return []
	
	## Category Operations
	func get_categories() -> Array[String]:
		return []
		
	func get_category_info(name: String) -> CategoryInfo:
		return null
		
	func get_properties_in_category(category: String) -> Array[String]:
		return []

## Standard format for property access paths
class PropertyPath:
	var container: String  # "properties" or "attributes"
	var category: String   # Category or attribute name
	var property: String   # Property name
	
	static func parse(path: String) -> PropertyPath:
		var result = PropertyPath.new()
		var parts = path.split(".")
		
		match parts.size():
			1:  # Direct property
				result.container = "properties"
				result.property = parts[0]
			2:  # Attribute property
				result.container = "attributes"
				result.category = parts[0]
				result.property = parts[1]
			_:
				return null
		
		return result
	
## Standard value formatting for all property types
static func format_value(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "<null>"
		TYPE_ARRAY:
			return "[%s]" % ", ".join(value.map(func(v): return format_value(v)))
		TYPE_DICTIONARY:
			var items = []
			for k in value:
				items.append("%s: %s" % [format_value(k), format_value(value[k])])
			return "{%s}" % ", ".join(items)
		TYPE_STRING:
			return '"%s"' % value
		TYPE_FLOAT:
			return "%.2f" % value
		TYPE_VECTOR2:
			var v = value as Vector2
			return "(%.1f, %.1f)" % [v.x, v.y]
		TYPE_VECTOR3:
			var v = value as Vector3
			return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]
		TYPE_BOOL:
			return "true" if value else "false"
		_:
			return str(value)
