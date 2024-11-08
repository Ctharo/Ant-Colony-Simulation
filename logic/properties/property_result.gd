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

## Supported property types
enum PropertyType {
	BOOL,
	INT,
	FLOAT,
	STRING,
	VECTOR2,
	VECTOR3,
	ARRAY,
	DICTIONARY,
	FOODS,
	PHEROMONES,
	ANTS,
	OBJECT,
	UNKNOWN
}

var value: Variant
var error: ErrorType
var error_message: String
var property_info: PropertyInfo  # Add PropertyInfo storage


func _init(p_value: Variant = null, p_error: ErrorType = ErrorType.NONE, p_message: String = "", p_property_info: PropertyInfo = null) -> void:
	value = p_value
	error = p_error
	error_message = p_message
	property_info = p_property_info

func success() -> bool:
	return error == ErrorType.NONE

func is_error() -> bool:
	return not success()
	
## Property information structure
class PropertyInfo:
	var name: String
	var type: PropertyType
	var value: Variant
	var getter: Callable
	var setter: Callable
	var category: String
	var description: String
	var metadata: Dictionary
	var writable: bool
	var dependencies: Array[String] = []  # Array of property paths this property depends on
	
	func _init(
		p_name: String,
		p_type: PropertyType,
		p_value: Variant,
		p_getter: Callable,
		p_setter: Callable = Callable(),
		p_category: String = "",
		p_description: String = "",
		p_metadata: Dictionary = {},
		p_dependencies: Array[String] = []
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
		dependencies = p_dependencies
	
	func to_dict() -> Dictionary:
		return {
			"name": name,
			"type": PropertyResult.type_to_string(type),
			"value": value,
			"category": category,
			"writable": writable,
			"description": description,
			"metadata": metadata
		}
		
	# Static factory method for creating properties
	static func create(name: String) -> PropertyInfoBuilder:
		return PropertyInfoBuilder.new(name)

## New builder class that works with existing PropertyInfo
class PropertyInfoBuilder:
	var _name: String
	var _type: PropertyType
	var _getter: Callable
	var _setter: Callable = Callable()
	var _dependencies: Array[String]
	var _category: String = ""
	var _description: String = ""
	var _metadata: Dictionary = {}
	
	func _init(p_name: String) -> void:
		_name = p_name
	
	func of_type(p_type: PropertyType) -> PropertyInfoBuilder:
		_type = p_type
		return self
	
	func with_getter(p_getter: Callable) -> PropertyInfoBuilder:
		_getter = p_getter
		return self
	
	func with_setter(p_setter: Callable) -> PropertyInfoBuilder:
		_setter = p_setter
		return self
		
	func with_dependencies(deps: Array[String]) -> PropertyInfoBuilder:
		_dependencies = deps
		return self
		
	func in_category(p_category: String) -> PropertyInfoBuilder:
		_category = p_category
		return self
	
	func described_as(p_description: String) -> PropertyInfoBuilder:
		_description = p_description
		return self
	
	func with_metadata(p_metadata: Dictionary) -> PropertyInfoBuilder:
		_metadata = p_metadata
		return self
	
	func build(initial_value: Variant = null) -> PropertyInfo:
		return PropertyInfo.new(
			_name,
			_type,
			initial_value,
			_getter,
			_setter,
			_category,
			_description,
			_metadata,
			_dependencies
		)

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
		TYPE_OBJECT:
			if value is Pheromones:
				return "Num: %s" % value.size()
			elif value is Foods:
				return "Num: %s" % value.size()
			elif value is Ants:
				return "Num: %s" % value.size()
			else:
				return value.to_string()
		_:
			return str(value)

static func type_to_string(type: PropertyType) -> String:
	match type:
		PropertyType.BOOL: return "Boolean"
		PropertyType.INT: return "Integer"
		PropertyType.FLOAT: return "Float"
		PropertyType.STRING: return "String"
		PropertyType.VECTOR2: return "Vector2"
		PropertyType.VECTOR3: return "Vector3"
		PropertyType.ARRAY: return "Array"
		PropertyType.DICTIONARY: return "Dictionary"
		PropertyType.FOODS: return "Foods"
		PropertyType.ANTS: return "Ants"
		PropertyType.PHEROMONES: return "Pheromones"
		PropertyType.OBJECT: return "Object"
		_: return "Unknown"
