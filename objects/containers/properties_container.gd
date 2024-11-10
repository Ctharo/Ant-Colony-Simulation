class_name PropertiesContainer
extends RefCounted

#region Signals
signal property_added(property: Property)
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
func expose_properties(properties: Array) -> Array[Result]:
	var results: Array[Result] = []
	for prop in properties:
		results.append(expose_property(prop))
	return results

## Exposes a single property with the given configuration
func expose_property(property: Property) -> Result:
	# Validate property
	if has_property(property.name):
		return Result.new(
			Result.ErrorType.DUPLICATE,
			"Property '%s' already exists" % property.name
		)

	if not _validate_property_accessors(property.name, property.getter, property.setter):
		return Result.new(
			Result.ErrorType.INVALID_GETTER,
			"Invalid getter or setter for property '%s'" % property.name
		)

	# Setup property
	_properties[property.name] = property
	property_added.emit(property.name)
	return Result.new()

## Removes a property from the container
func remove_property(name: String) -> Result:
	if not has_property(name):
		return Result.new(
			Result.ErrorType.NOT_FOUND,
			"Property '%s' doesn't exist" % name
		)
	_properties.erase(name)
	property_removed.emit(name)
	return Result.new()
#endregion

#region Property Access
## Gets a property if exists else returns null
func get_property(name: String) -> Property:
	if not has_property(name):
		return null
	return _properties[name]
#endregion

#region Property Information
func get_properties() -> Array[Property]:
	var properties: Array[Property] = []
	for name in get_property_names():
		properties.append(get_property(name))
	return properties

func get_property_names() -> Array[String]:
	var names: Array[String] = []
	for key: String in _properties:
		names.append(key)
	return names

func get_property_path(property_name: String) -> Path:
	if not has_property(property_name):
		return null
	if Helper.is_full_path(property_name):
		return Path.parse(property_name)
	return get_property(property_name).path

func has_property(name: String) -> bool:
	return _properties.has(name)

## Returns full_path format String names of dependencies belonging to property
func get_property_dependencies(property_name: String) -> Array[String]:
	if not has_property(property_name):
		return []
	return get_property(property_name).dependencies
#endregion

#region Helper Functions
func _validate_property_accessors(name: String, getter: Callable, setter: Callable) -> bool:
	if not _is_valid_getter(getter):
		return false

	if setter.is_valid() and not _is_valid_setter(setter):
		return false

	return true

func _is_valid_getter(getter: Callable) -> bool:
	if not getter.is_valid() or not getter.get_object() or getter.get_method().is_empty():
		return false
	return getter.get_argument_count() == 0 and getter.get_object().has_method(getter.get_method())

func _is_valid_setter(setter: Callable) -> bool:
	if not setter.is_valid() or not setter.get_object() or setter.get_method().is_empty():
		return false
	return setter.get_argument_count() == 1 and setter.get_object().has_method(setter.get_method())

func _is_valid_type(value: Variant, expected_type: Property.Type) -> bool:
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
