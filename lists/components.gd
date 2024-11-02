class_name Components
extends Iterator
## Container class for all exposed properties and attributes of object


var _exposed_methods: Dictionary = {}
var _exposed_attributes: Dictionary = {}


func _init(initial_components: Array[Component] = []):
	super._init()


#region Attributes
func get_attribute_properties(attribute_name: String) -> Dictionary:
	if attribute_name in _exposed_attributes:
		var attribute: Attribute = _exposed_attributes[attribute_name]
		return attribute.get_exposed_properties()
	return {}

# Get a specific property from an attribute
func get_attribute_property(attribute_name: String, property_name: String):
	if attribute_name in _exposed_attributes:
		return _exposed_attributes[attribute_name].get_property(property_name)
	return null

# Set a specific property on an attribute
func set_attribute_property(attribute_name: String, property_name: String, value) -> bool:
	if attribute_name in _exposed_attributes:
		return _exposed_attributes[attribute_name].set_property(property_name, value)
	return false

# Get all exposed properties from all attributes
func get_all_attribute_properties() -> Dictionary:
	var properties = {}
	for attr_name in _exposed_attributes:
		properties[attr_name] = get_attribute_properties(attr_name)
	return properties
#endregion
