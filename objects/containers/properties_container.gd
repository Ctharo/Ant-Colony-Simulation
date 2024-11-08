class_name PropertiesContainer
extends RefCounted

#region Signals
signal property_added(info: PropertyResult.PropertyInfo)
signal property_removed(name: String)
signal property_changed(name: String, old_value: Variant, new_value: Variant)
#endregion

#region Member Variables
## Dictionary mapping property names to their PropertyInfo
var _properties: Dictionary = {}

## Reference to the owner object
var _owner: Object

## Dictionary mapping property names to their local dependent properties
var _local_dependency_map: Dictionary = {}

## Dictionary mapping full paths to their externally dependent properties
var _external_dependency_map: Dictionary = {}
#endregion

func _init(owner: Object) -> void:
	_owner = owner

#region Property Management
## Exposes multiple properties at once
## Returns: Array of PropertyResults for each exposed property
func expose_properties(properties: Array) -> Array[PropertyResult]:
	var results: Array[PropertyResult] = []
	for prop in properties:
		results.append(expose_property(prop))
	return results
	
## Exposes a single property with the given configuration
func expose_property(property: PropertyResult.PropertyInfo) -> PropertyResult:
	# Validate property
	if _properties.has(property.name):
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.DUPLICATE_PROPERTY,
			"Property '%s' already exists" % property.name
		)
	
	if not _validate_property_accessors(property.name, property.getter, property.setter):
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.INVALID_GETTER,
			"Invalid getter or setter for property '%s'" % property.name
		)
	
	# Setup property
	_setup_property_dependencies(property)
	_properties[property.name] = property
	
	# Get initial value
	var result = get_property(property.name)
	if result.success():
		property.value = result.value
	
	property_added.emit(property)
	return PropertyResult.new(property)

## Removes a property from the container
func remove_property(name: String) -> PropertyResult:
	if not _properties.has(name):
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.PROPERTY_NOT_FOUND,
			"Property '%s' doesn't exist" % name
		)
		
	_properties.erase(name)
	_cleanup_property_dependencies(name)
	property_removed.emit(name)
	return PropertyResult.new(null)
#endregion

#region Property Access
## Gets a property value and returns a PropertyResult
func get_property(name: String) -> PropertyResult:
	var prop_info = get_property_info(name)
	if not prop_info:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.PROPERTY_NOT_FOUND,
			"Property '%s' doesn't exist" % name
		)
	
	if not prop_info.getter.is_valid():
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.INVALID_GETTER,
			"Invalid getter for property '%s'" % name
		)
	
	var value = prop_info.getter.call()
	prop_info.value = value  # Update stored value
	return PropertyResult.new(value)

## Sets a property value and returns a PropertyResult
func set_property(name: String, value: Variant) -> PropertyResult:
	var prop_info = get_property_info(name)
	if not prop_info:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.PROPERTY_NOT_FOUND,
			"Property '%s' doesn't exist" % name
		)
	
	if not prop_info.writable:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.INVALID_SETTER,
			"Property '%s' is read-only" % name
		)
	
	if not _is_valid_type(value, prop_info.type):
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.TYPE_MISMATCH,
			"Invalid type for property '%s'" % name
		)
	
	var old_value = prop_info.value
	prop_info.setter.call(value)
	prop_info.value = value
	
	property_changed.emit(name, old_value, value)
	return PropertyResult.new(value)
#endregion

#region Property Information
func get_property_info(name: String) -> PropertyResult.PropertyInfo:
	return _properties.get(name)

func get_properties() -> Array[PropertyResult]:
	var results: Array[PropertyResult] = []
	for name in _properties:
		results.append(get_property(name))
	return results

func get_property_names() -> Array[String]:
	return _properties.keys()

func has_property(name: String) -> bool:
	return _properties.has(name)

func get_dependent_properties(name: String, full_path: String = "") -> Array[String]:
	var dependents: Array[String] = []
	
	if _local_dependency_map.has(name):
		dependents.append_array(_local_dependency_map[name])
	
	if not full_path.is_empty() and _external_dependency_map.has(full_path):
		dependents.append_array(_external_dependency_map[full_path])
		
	return dependents

func get_external_dependencies() -> Array[String]:
	return _external_dependency_map.keys()
#endregion

#region Helper Functions
func _validate_property_accessors(name: String, getter: Callable, setter: Callable) -> bool:
	if not _is_valid_getter(getter):
		return false
	
	if setter.is_valid() and not _is_valid_setter(setter):
		return false
		
	return true

func _setup_property_dependencies(property: PropertyResult.PropertyInfo) -> void:
	if property.dependencies.is_empty():
		return
		
	for dependency in property.dependencies:
		var map = _external_dependency_map if "." in dependency else _local_dependency_map
		var key = dependency
		
		if not map.has(key):
			map[key] = []
		map[key].append(property.name)

func _cleanup_property_dependencies(name: String) -> void:
	# Remove as a dependent
	_local_dependency_map.erase(name)
	_external_dependency_map.erase(name)
	
	# Remove from other properties' dependencies
	for deps in _local_dependency_map.values():
		deps.erase(name)
	for deps in _external_dependency_map.values():
		deps.erase(name)

func _is_valid_getter(getter: Callable) -> bool:
	if not getter.is_valid() or not getter.get_object() or getter.get_method().is_empty():
		return false
	return getter.get_argument_count() == 0 and getter.get_object().has_method(getter.get_method())

func _is_valid_setter(setter: Callable) -> bool:
	if not setter.is_valid() or not setter.get_object() or setter.get_method().is_empty():
		return false
	return setter.get_argument_count() == 1 and setter.get_object().has_method(setter.get_method())

func _is_valid_type(value: Variant, expected_type: PropertyResult.PropertyType) -> bool:
	match expected_type:
		PropertyResult.PropertyType.BOOL:
			return typeof(value) == TYPE_BOOL
		PropertyResult.PropertyType.INT:
			return typeof(value) == TYPE_INT
		PropertyResult.PropertyType.FLOAT:
			return typeof(value) == TYPE_FLOAT
		PropertyResult.PropertyType.STRING:
			return typeof(value) == TYPE_STRING
		PropertyResult.PropertyType.VECTOR2:
			return value is Vector2
		PropertyResult.PropertyType.VECTOR3:
			return value is Vector3
		PropertyResult.PropertyType.ARRAY:
			return value is Array
		PropertyResult.PropertyType.DICTIONARY:
			return value is Dictionary
		PropertyResult.PropertyType.OBJECT:
			return value is Object
	return false
#endregion
