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

#region Initialization
func _init(owner: Object) -> void:
	_owner = owner
#endregion

#region Property Management - Exposure
## Accepts an Array of type [class PropertyResult.PropertyInfo] and calls [member expose_property] for each
## Returns: Array of type [class PropertyResult]
func expose_properties(properties: Array[PropertyResult.PropertyInfo]) -> Array[PropertyResult]:
	var results: Array[PropertyResult] = []
	for prop in properties:
		results.append(expose_property(prop))
	return results
	
## Exposes a new property with the given configuration
func expose_property(property: PropertyResult.PropertyInfo) -> PropertyResult:
	# Validate property doesn't exist
	var name = property.name
	var type = property.type
	var getter = property.getter
	var setter = property.setter
	var description = property.description
	
	if _properties.has(name):
		var error_msg: String = "Property '%s' already exists" % property.name
		DebugLogger.error(DebugLogger.Category.PROPERTY, "Failed to expose property %s -> %s" % [name, error_msg])
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.DUPLICATE_PROPERTY,
			error_msg
		)
	
	# Validate getter and setter
	if not _validate_property_accessors(name, getter, setter):
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.INVALID_GETTER,
			"Invalid getter or setter for property '%s'" % name
		)
	
	# Get initial value and handle dependencies
	var initial_value = getter.call()
	_setup_property_dependencies(property)
	
	# Store property
	_properties[name] = property
	
	property_added.emit(property)
	_trace("Property %s successfully added and exposed in property container" % name)
	return PropertyResult.new(property)
#endregion

#region Property Management - Access
func get_property(name: String) -> PropertyResult:
	if not _properties.has(name):
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.PROPERTY_NOT_FOUND,
			"Property '%s' doesn't exist" % name
		)
	
	var prop_info = _properties[name]
	var value = prop_info.getter.call()
	prop_info.value = value  # Update stored value
	
	return PropertyResult.new(value)

func get_property_value(name: String) -> Variant:
	var result = get_property(name)
	return result.value if result.success() else null

func set_property_value(name: String, value: Variant) -> PropertyResult:
	# Validate property exists and is writable
	if not _properties.has(name):
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.PROPERTY_NOT_FOUND,
			"Property '%s' doesn't exist" % name
		)
	
	var prop_info = _properties[name]
	if not prop_info.writable:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.INVALID_SETTER,
			"Property '%s' is read-only" % name
		)
	
	# Validate value type
	if not _is_valid_type(value, prop_info.type):
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.TYPE_MISMATCH,
			"Invalid type for property '%s'" % name
		)
	
	# Update value and emit change
	var old_value = get_property_value(name)
	prop_info.setter.call(value)
	prop_info.value = value
	
	property_changed.emit(name, old_value, value)
	return PropertyResult.new(value)
#endregion

#region Property Information
## Gets information about a specific property
func get_property_info(name: String) -> PropertyResult.PropertyInfo:
	return _properties.get(name)

## Gets all properties
func get_properties() -> Array[PropertyResult]:
	var a: Array[PropertyResult] = []
	for key in _properties.keys():
		a.append(get_property(key))
	return a
	
## Gets all property names
func get_property_names() -> Array[String]:
	var a: Array[String] = []
	for key in _properties.keys():
		a.append(key)
	return a
	
## Checks if a property exists
func has_property(name: String) -> bool:
	return _properties.has(name)

## Gets all properties that depend on a given property
func get_dependent_properties(name: String, full_path: String = "") -> Array[String]:
	var dependents: Array[String] = []
	
	if _local_dependency_map.has(name):
		dependents.append_array(_local_dependency_map[name])
	
	if not full_path.is_empty() and _external_dependency_map.has(full_path):
		dependents.append_array(_external_dependency_map[full_path])
		
	return dependents

## Gets all external dependencies of properties in this container
func get_external_dependencies() -> Array[String]:
	return _external_dependency_map.keys()
#endregion

#region Helper Functions
## Validates both getter and setter for a property
func _validate_property_accessors(name: String, getter: Callable, setter: Callable) -> bool:
	if not _is_valid_getter(getter):
		DebugLogger.error(DebugLogger.Category.PROPERTY, "Invalid getter for property '%s'" % name)
		return false
	
	if setter.is_valid() and not _is_valid_setter(setter):
		DebugLogger.error(DebugLogger.Category.PROPERTY, "Invalid setter for property '%s'" % name)
		return false
		
	return true

## Sets up dependency mappings for a property
func _setup_property_dependencies(property: PropertyResult.PropertyInfo) -> void:
	if property.dependencies.is_empty():
		return
		
	for dependency in property.dependencies:
		var map = _external_dependency_map if "." in dependency else _local_dependency_map
		var key = dependency
		
		if not map.has(key):
			map[key] = []
		map[key].append(property.name)
		
		_trace("Added %s dependency: %s depends on %s" % [
			"external" if "." in dependency else "local",
			property.name,
			dependency
		])

## Validates a getter callable
func _is_valid_getter(getter: Callable) -> bool:
	if not getter.is_valid() or not getter.get_object() or getter.get_method().is_empty():
		return false
	return getter.get_argument_count() == 0 and getter.get_object().has_method(getter.get_method())

## Validates a setter callable
func _is_valid_setter(setter: Callable) -> bool:
	if not setter.is_valid() or not setter.get_object() or setter.get_method().is_empty():
		return false
	return setter.get_argument_count() == 1 and setter.get_object().has_method(setter.get_method())

## Validates a value matches the expected type
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

## Logs a trace message with property container context
func _trace(message: String) -> void:
	DebugLogger.trace(DebugLogger.Category.PROPERTY,
		message,
		{"From": "properties_container"}
	)
#endregion
