class_name PropertiesContainer
extends RefCounted

## Container for managing exposed properties with type safety and validation

signal property_added(name: String, type: int)
signal property_removed(name: String)
signal property_changed(name: String, old_value: Variant, new_value: Variant)

## Structure to store property metadata and access methods
class PropertyData:
	var getter: Callable
	var setter: Callable
	var type: Component.PropertyType
	var description: String
	var cached_value: Variant
	var cache_valid: bool
	
	func _init(
		p_getter: Callable, 
		p_type: Component.PropertyType, 
		p_setter: Callable = Callable(),
		p_description: String = ""
	) -> void:
		getter = p_getter
		setter = p_setter
		type = p_type
		description = p_description
		cache_valid = false

var _properties: Dictionary = {}
var _owner: Node  # Reference to owning object
var _use_caching: bool = true

func _init(use_caching: bool = true) -> void:
	_use_caching = use_caching

#region Property Management
## Expose a new property with getter and optional setter
func expose_property(
	name: String, 
	getter: Callable, 
	type: Component.PropertyType, 
	setter: Callable = Callable(),
	description: String = ""
) -> void:
	if _properties.has(name):
		push_warning("Property '%s' already exists" % name)
		return
		
	_validate_getter(getter)
	if setter.is_valid():
		_validate_setter(setter)
		
	_properties[name] = PropertyData.new(getter, type, setter, description)
	property_added.emit(name, type)

## Remove an exposed property
func remove_property(name: String) -> void:
	if not _properties.has(name):
		push_warning("Property '%s' doesn't exist" % name)
		return
		
	_properties.erase(name)
	property_removed.emit(name)

## Check if a property exists
func has_property(name: String) -> bool:
	return _properties.has(name)

## Get list of all exposed property names
func get_property_names() -> Array[String]:
	return _properties.keys()
#endregion

#region Property Access
## Get a property's value
func get_property(name: String) -> Variant:
	if not has_property(name):
		push_warning("Property '%s' doesn't exist" % name)
		return null
		
	var prop_data: PropertyData = _properties[name]
	
	# Check cache if enabled
	if _use_caching and prop_data.cache_valid:
		return prop_data.cached_value
		
	# Get fresh value
	var value = prop_data.getter.call()
	
	# Update cache
	if _use_caching:
		prop_data.cached_value = value
		prop_data.cache_valid = true
		
	return value

## Set a property's value
## Returns true if successful
func set_property(name: String, value: Variant) -> bool:
	if not has_property(name):
		push_warning("Property '%s' doesn't exist" % name)
		return false
		
	var prop_data: PropertyData = _properties[name]
	if not prop_data.setter.is_valid():
		push_warning("Property '%s' is read-only" % name)
		return false
		
	# Validate type
	if not _is_valid_type(value, prop_data.type):
		push_warning("Invalid type for property '%s'" % name)
		return false
		
	var old_value = get_property(name)
	prop_data.setter.call(value)
	
	# Invalidate cache
	if _use_caching:
		prop_data.cache_valid = false
		
	property_changed.emit(name, old_value, value)
	return true

## Invalidate cache for a specific property
func invalidate_cache(name: String) -> void:
	if has_property(name):
		_properties[name].cache_valid = false

## Invalidate all property caches
func invalidate_all_caches() -> void:
	for prop_data in _properties.values():
		prop_data.cache_valid = false
#endregion

#region Property Information
## Get property type
func get_property_type(name: String) -> Component.PropertyType:
	if not has_property(name):
		return Component.PropertyType.UNKNOWN
	return _properties[name].type

## Get property description
func get_property_description(name: String) -> String:
	if not has_property(name):
		return ""
	return _properties[name].description

## Check if property is writable
func is_property_writable(name: String) -> bool:
	if not has_property(name):
		return false
	return _properties[name].setter.is_valid()

## Get all property information
func get_properties_info() -> Dictionary:
	var info = {}
	for name in _properties:
		var prop_data: PropertyData = _properties[name]
		info[name] = {
			"type": prop_data.type,
			"description": prop_data.description,
			"writable": prop_data.setter.is_valid(),
			"value": get_property(name)
		}
	return info
#endregion

#region Helper Functions
## Validate getter callable
func _validate_getter(getter: Callable) -> void:
	if not getter.is_valid():
		push_error("Invalid getter callable")
	if getter.get_argument_count() != 0:
		push_error("Getter must take no arguments")

## Validate setter callable
func _validate_setter(setter: Callable) -> void:
	if not setter.is_valid():
		push_error("Invalid setter callable")
	if setter.get_argument_count() != 1:
		push_error("Setter must take exactly one argument")

## Check if value matches expected type
func _is_valid_type(value: Variant, expected_type: Component.PropertyType) -> bool:
	match expected_type:
		Component.PropertyType.BOOL:
			return typeof(value) == TYPE_BOOL
		Component.PropertyType.INT:
			return typeof(value) == TYPE_INT
		Component.PropertyType.FLOAT:
			return typeof(value) == TYPE_FLOAT
		Component.PropertyType.STRING:
			return typeof(value) == TYPE_STRING
		Component.PropertyType.VECTOR2:
			return value is Vector2
		Component.PropertyType.VECTOR3:
			return value is Vector3
		Component.PropertyType.ARRAY:
			return value is Array
		Component.PropertyType.DICTIONARY:
			return value is Dictionary
		Component.PropertyType.OBJECT:
			return value is Object
	return false
#endregion
