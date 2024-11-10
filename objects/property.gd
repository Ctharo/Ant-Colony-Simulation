class_name Property
extends RefCounted

## Supported property types
enum Type {
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

var name: String
var attribute_name: String
var path: Path : get = _get_path
var type: Type
var value: Variant : get = _get_value, set = set_value
var getter: Callable
var setter: Callable
var dependencies: Array[String]
var description: String
var writable: bool : get = _writable

class Builder:
	var name: String
	var attribute_name: String
	var type: Type
	var getter: Callable
	var setter: Callable
	var dependencies: Array[String]
	var description: String

	func _init(p_name: String) -> void:
		name = p_name.to_lower()

	func with_attribute(p_name: String) -> Builder:
		attribute_name = p_name.to_lower()
		return self

	func of_type(p_type: Type) -> Builder:
		type = p_type
		return self

	func with_getter(p_getter: Callable) -> Builder:
		if Property.is_valid_getter(p_getter):
			getter = p_getter
		return self

	func with_setter(p_setter: Callable) -> Builder:
		if Property.is_valid_setter(p_setter):
			setter = p_setter
		return self

	func with_dependencies(p_dependencies: Array[String]) -> Builder:
		for dependency in p_dependencies:
			if not Helper.is_full_path(dependency):
				# Fix if possible, abort otherwise
				if attribute_name.is_empty():
					DebugLogger.warn(DebugLogger.Category.PROPERTY, "Cannot set dependency %s for property %s as invalid path format" % [dependency, name])
					return
				dependency = attribute_name + "." + dependency
			dependencies.append(dependency)
		return self

	func described_as(p_description: String) -> Builder:
		description = p_description
		return self

	func build() -> Property:
		return Property.new(name, type, attribute_name, getter, setter, dependencies, description)

func _init(p_name: String, p_type: Type, p_attribute_name: String, p_getter: Callable, p_setter: Callable = Callable(), p_dependencies: Array[String] = [], p_description: String = "") -> void:
	name = p_name
	type = p_type
	attribute_name = p_attribute_name
	getter = p_getter
	setter = p_setter
	dependencies = p_dependencies
	description = p_description

func _get_value() -> Variant:
	return getter.call()

static func create(p_name: String) -> Builder:
	return Builder.new(p_name)

func set_value(p_value: Variant) -> Result:
	if not Property.is_valid_type(value, type):
		return Result.new(
			Result.ErrorType.TYPE_MISMATCH,
			"Cannot set property value"
		)
	setter.call(p_value)
	return Result.new()

func has_valid_getter() -> bool:
	return Property.is_valid_getter(getter)

func _get_path() -> Path:
	return Path.new(attribute_name, name)

func _writable() -> bool:
	return Property.is_valid_setter(setter)

#region Statics
static func is_valid_getter(p_getter: Callable) -> bool:
	if not p_getter.is_valid() or not p_getter.get_object() or p_getter.get_method().is_empty():
		return false
	return p_getter.get_argument_count() == 0 and p_getter.get_object().has_method(p_getter.get_method())

static func is_valid_setter(p_setter: Callable) -> bool:
	if not p_setter.is_valid() or not p_setter.get_object() or p_setter.get_method().is_empty():
		return false
	return p_setter.get_argument_count() == 1 and p_setter.get_object().has_method(p_setter.get_method())

static func type_to_string(type: Type) -> String:
	match type:
		Type.BOOL: return "Boolean"
		Type.INT: return "Integer"
		Type.FLOAT: return "Float"
		Type.STRING: return "String"
		Type.VECTOR2: return "Vector2"
		Type.VECTOR3: return "Vector3"
		Type.ARRAY: return "Array"
		Type.DICTIONARY: return "Dictionary"
		Type.FOODS: return "Foods"
		Type.ANTS: return "Ants"
		Type.PHEROMONES: return "Pheromones"
		Type.OBJECT: return "Object"
		_: return "Unknown"

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
				var p: Array[String]
				for pheromone in value:
					p.append("T: %s, [%.1f]" % [pheromone.type, pheromone.concentration])
				return Property.format_value(p)
			elif value is Foods:
				return Property.format_value("%.2f units" % value.mass())
			elif value is Ants:
				return Property.format_value(value.to_array())
			else:
				return value.to_string()
		_:
			return str(value)

static func is_valid_type(value: Variant, expected_type: Property.Type) -> bool:
	match expected_type:
		Property.Type.BOOL:
			return typeof(value) == TYPE_BOOL
		Property.Type.INT:
			return typeof(value) == TYPE_INT
		Property.Type.FLOAT:
			return typeof(value) == TYPE_FLOAT
		Property.Type.STRING:
			return typeof(value) == TYPE_STRING
		Property.Type.VECTOR2:
			return value is Vector2
		Property.Type.VECTOR3:
			return value is Vector3
		Property.Type.ARRAY:
			return value is Array
		Property.Type.DICTIONARY:
			return value is Dictionary
		Property.Type.OBJECT:
			return value is Object
	return false
#endregion
