class_name PropertyInspector
extends RefCounted

## Structure to hold property metadata
class PropertyInfo:
	var name: String
	var type: String
	var value: Variant
	var can_write: bool
	var description: String
	
	func _init(p_name: String, p_type: String, p_value: Variant, p_can_write: bool = false, p_description: String = ""):
		name = p_name
		type = p_type
		value = p_value
		can_write = p_can_write
		description = p_description
	
	func to_dict() -> Dictionary:
		return {
			"name": name,
			"type": type,
			"value": value,
			"can_write": can_write,
			"description": description
		}

## Structure to hold object metadata
class ObjectInfo:
	var name: String
	var type: String
	var properties: Array[PropertyInfo]
	var children: Array[ObjectInfo]
	
	func _init(p_name: String, p_type: String):
		name = p_name
		type = p_type
		properties = []
		children = []
	
	func add_property(property: PropertyInfo) -> void:
		properties.append(property)
	
	func add_child(child: ObjectInfo) -> void:
		children.append(child)
	
	func to_dict() -> Dictionary:
		return {
			"name": name,
			"type": type,
			"properties": properties.map(func(p): return p.to_dict()),
			"children": children.map(func(c): return c.to_dict())
		}

## Get all exposed properties from an object recursively
static func get_object_info(object: Variant, name: String = "") -> ObjectInfo:
	if object == null:
		return null
	
	var info = ObjectInfo.new(
		name if not name.is_empty() else object.get_class(),
		object.get_class()
	)
	
	# Handle Ant specifically
	if object is Ant:
		# Add exposed methods
		for category in object._exposed_methods:
			var category_info = ObjectInfo.new(category, "MethodCategory")
			for method_name in object._exposed_methods[category]:
				var value = object.get_method_result(method_name)
				category_info.add_property(
					PropertyInfo.new(method_name, typeof_as_string(value), value)
				)
			info.add_child(category_info)
		
		# Add exposed attributes
		for attr_name in object.exposed_attributes:
			var attr = object.exposed_attributes[attr_name]
			if attr:
				var attr_info = get_object_info(attr, attr_name)
				if attr_info:
					info.add_child(attr_info)
	
	# Handle Attribute objects
	elif object is Attribute:
		for prop_name in object._exposed_properties:
			var prop_data = object._exposed_properties[prop_name]
			var value = prop_data["getter"].call() if prop_data["getter"].is_valid() else null
			var can_write = prop_data["setter"].is_valid()
			info.add_property(
				PropertyInfo.new(
					prop_name,
					typeof_as_string(value),
					value,
					can_write
				)
			)
	
	return info

## Helper function to convert type to string
static func typeof_as_string(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL: return "Null"
		TYPE_BOOL: return "Boolean"
		TYPE_INT: return "Integer"
		TYPE_FLOAT: return "Float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR3: return "Vector3"
		TYPE_ARRAY: return "Array"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_OBJECT: return value.get_class() if value else "Object"
		_: return "Unknown"

## Get flat path to a property
static func get_property_path(object_info: ObjectInfo, property_name: String) -> String:
	# Check direct properties
	for prop in object_info.properties:
		if prop.name == property_name:
			return property_name
	
	# Check children recursively
	for child in object_info.children:
		var child_path = get_property_path(child, property_name)
		if not child_path.is_empty():
			return "%s.%s" % [child.name, child_path]
	
	return ""

## Print the object hierarchy for debugging
static func print_hierarchy(object_info: ObjectInfo, indent: int = 0) -> void:
	var indent_str = "  ".repeat(indent)
	print("%s%s (%s)" % [indent_str, object_info.name, object_info.type])
	
	# Print properties
	for prop in object_info.properties:
		print("%s  └─ %s: %s%s" % [
			indent_str,
			prop.name,
			prop.type,
			" (RW)" if prop.can_write else " (RO)"
		])
	
	# Print children recursively
	for child in object_info.children:
		print_hierarchy(child, indent + 1)
