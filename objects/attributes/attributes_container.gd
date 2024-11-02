class_name AttributesContainer
extends RefCounted

## Container class for managing exposed attributes and their properties

signal attribute_added(name: String, attribute: Component)
signal attribute_removed(name: String)
signal attribute_changed(name: String, attribute: Component)

var _attributes: Dictionary = {}
var _property_cache: Dictionary = {}
var _owner: Node  # Reference to owning object

func _init(owner: Node) -> void:
	_owner = owner

#region Attribute Management
## Add an attribute to the container
## Returns true if successful, false if attribute already exists
func add_attribute(name: String, attribute: Component) -> bool:
	if has_attribute(name):
		push_warning("Attribute '%s' already exists" % name)
		return false
		
	_attributes[name] = attribute
	_property_cache.clear()  # Invalidate cache
	attribute_added.emit(name, attribute)
	return true

## Remove an attribute from the container
## Returns true if successful, false if attribute doesn't exist
func remove_attribute(name: String) -> bool:
	if not has_attribute(name):
		push_warning("Attribute '%s' doesn't exist" % name)
		return false
		
	_attributes.erase(name)
	_property_cache.clear()  # Invalidate cache
	attribute_removed.emit(name)
	return true

## Check if an attribute exists
func has_attribute(name: String) -> bool:
	return _attributes.has(name)

## Get an attribute by name
## Returns null if attribute doesn't exist
func get_attribute(name: String) -> Component:
	return _attributes.get(name)

## Get all attributes
func get_attributes() -> Dictionary:
	return _attributes.duplicate()
#endregion

#region Property Access
## Get all properties for a specific attribute
## Returns empty dict if attribute doesn't exist
func get_attribute_properties(attribute_name: String) -> Dictionary:
	if not has_attribute(attribute_name):
		return {}
		
	# Check cache first
	if attribute_name in _property_cache:
		return _property_cache[attribute_name]
		
	# Get properties and cache them
	var properties = _attributes[attribute_name].get_exposed_properties()
	_property_cache[attribute_name] = properties
	return properties

## Get a specific property from an attribute
## Returns null if attribute or property doesn't exist
func get_attribute_property(attribute_name: String, property_name: String) -> Variant:
	if not has_attribute(attribute_name):
		return null
		
	return _attributes[attribute_name].get_property(property_name)

## Set a specific property on an attribute
## Returns true if successful
func set_attribute_property(attribute_name: String, property_name: String, value: Variant) -> bool:
	if not has_attribute(attribute_name):
		return false
		
	var success = _attributes[attribute_name].set_property(property_name, value)
	if success:
		_property_cache.erase(attribute_name)  # Invalidate cache for this attribute
	return success

## Get all properties from all attributes
func get_all_properties() -> Dictionary:
	var all_properties = {}
	for attr_name in _attributes:
		all_properties[attr_name] = get_attribute_properties(attr_name)
	return all_properties
#endregion

#region Serialization
## Get serializable data for all attributes
func to_dict() -> Dictionary:
	var data = {}
	for attr_name in _attributes:
		var attribute = _attributes[attr_name]
		if attribute.has_method("to_dict"):
			data[attr_name] = attribute.to_dict()
	return data

## Load attributes from serialized data
func from_dict(data: Dictionary) -> void:
	for attr_name in data:
		if has_attribute(attr_name):
			var attribute = _attributes[attr_name]
			if attribute.has_method("from_dict"):
				attribute.from_dict(data[attr_name])
#endregion

#region Property Types
## Get the type information for a specific property
func get_property_type(attribute_name: String, property_name: String) -> Component.PropertyType:
	if not has_attribute(attribute_name):
		return Component.PropertyType.UNKNOWN
		
	var properties = get_attribute_properties(attribute_name)
	if property_name in properties:
		return properties[property_name]["type"]
	return Component.PropertyType.UNKNOWN

## Convert property type to string representation
static func type_to_string(type: Component.PropertyType) -> String:
	return Component.type_to_string(type)
#endregion
