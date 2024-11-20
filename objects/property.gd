class_name Property
extends BaseRefCounted

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
				return format_value(p)
			elif value is Foods:
				var f: Array[String]
				for food in value:
					f.append("Mass: %.1f" % [food.mass])
				return format_value(f)
			elif value is Ants:
				return format_value(value.to_array())
			else:
				return value.to_string()
		_:
			return str(value)

static func is_valid_type(value: Variant, expected_type: Type) -> bool:
	match expected_type:
		Type.BOOL:
			return typeof(value) == TYPE_BOOL
		Type.INT:
			return typeof(value) == TYPE_INT
		Type.FLOAT:
			return typeof(value) == TYPE_FLOAT
		Type.STRING:
			return typeof(value) == TYPE_STRING
		Type.VECTOR2:
			return value is Vector2
		Type.VECTOR3:
			return value is Vector3
		Type.ARRAY:
			return value is Array
		Type.DICTIONARY:
			return value is Dictionary
		Type.FOODS:
			return value is Foods
		Type.PHEROMONES:
			return value is Pheromones
		Type.ANTS:
			return value is Ants
		Type.OBJECT:
			return value is Object
	return false
#endregion
