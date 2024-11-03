class_name Component
extends RefCounted

# Stores property metadata and access methods
var properties_container: PropertiesContainer = PropertiesContainer.new(self)

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
		properties_container.expose_property(name, getter, type, setter, description)
	
func get_property(name: String):
	return properties_container.get_property(name)

func set_property(name: String, value) -> bool:
	if properties_container.set_property(name, value):
		return true
	return false
	
func get_exposed_properties() -> Dictionary:
	return properties_container.get_properties_info()

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
