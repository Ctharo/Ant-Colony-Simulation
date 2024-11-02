class_name Component
extends RefCounted

# Stores property metadata and access methods
var _exposed_properties = {}
var properties: PropertiesContainer = PropertiesContainer.new()

# Type enum for easier reference
enum PropertyType {
	BOOL,
	INT,
	FLOAT,
	STRING,
	VECTOR2,
	VECTOR3,
	ARRAY,
	DICTIONARY,
	OBJECT,
	UNKNOWN
}


## Expose a property with type information
func expose_property(
		name: String, 
		getter: Callable, 
		type: PropertyType, 
		setter: Callable = Callable(),
		description: String = ""
	) -> void:
		properties.expose_property(name, getter, type, setter, description)
	
func get_property(name: String):
	if not _exposed_properties.has(name):
		return null
	
	var getter = _exposed_properties[name]["getter"]
	# Try to call the getter, return null if it fails (might need arguments)
	if getter.is_valid():
		if getter.get_object() and getter.get_method() and getter.get_argument_count() == 0:
			return getter.call()
	return null

func set_property(name: String, value) -> bool:
	if not _exposed_properties.has(name) or _exposed_properties[name]["setter"].is_null():
		return false
	_exposed_properties[name]["setter"].call(value)
	return true
	
func get_exposed_properties() -> Dictionary:
	var result = {}
	for prop_name in _exposed_properties:
		var prop_info = {
			"value": get_property(prop_name),
			"type": _exposed_properties[prop_name]["type"]
		}
		result[prop_name] = prop_info
	return result

# Helper function to check if a getter requires arguments
func _getter_requires_args(getter: Callable) -> bool:
	return getter.get_argument_count() > 0

# Helper function to convert PropertyType to string
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
		PropertyType.OBJECT: return "Object"
		_: return "Unknown"
