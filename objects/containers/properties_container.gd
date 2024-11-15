class_name PropertiesContainer
extends BaseRefCounted

#region Signals
signal property_added(property: Property)
signal property_removed(name: String)
signal property_changed(name: String, old_value: Variant, new_value: Variant)
signal nested_property_added(property: NestedProperty)
signal nested_property_removed(path: String)
#endregion

#region Member Variables
## Dictionary mapping property names to their PropertyInfo
var _properties: Dictionary = {}  # name -> Property

## Dictionary mapping property names to their NestedProperty
var _nested_properties: Dictionary = {}  # name -> NestedProperty

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
	property_added.emit(property)
	return Result.new()

## Exposes a nested property structure
func expose_nested_property(property: NestedProperty) -> Result:
	# Validate root property
	if has_nested_property(property.name):
		return Result.new(
			Result.ErrorType.DUPLICATE,
			"Nested property '%s' already exists" % property.name
		)

	# Validate all getters/setters in the tree
	var validation_result = _validate_nested_property_tree(property)
	if validation_result.has_error():
		return validation_result

	# Setup property
	_nested_properties[property.name] = property
	_setup_nested_dependencies(property)
	nested_property_added.emit(property)
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

## Removes a nested property and all its children
func remove_nested_property(name: String) -> Result:
	if not has_nested_property(name):
		return Result.new(
			Result.ErrorType.NOT_FOUND,
			"Nested property '%s' doesn't exist" % name
		)

	var property = _nested_properties[name]
	_cleanup_nested_dependencies(property)
	_nested_properties.erase(name)
	nested_property_removed.emit(property.get_full_path())
	return Result.new()
#endregion

#region Property Access
## Gets a property if exists else returns null
func get_property(path: String) -> Property:
	if has_property(path):
		return _properties[path]
	return null

## Gets a nested property by its full path
func get_nested_property(path: String) -> NestedProperty:
	var parts = path.split(".", true, 1)
	var root_name = parts[0]

	if not _nested_properties.has(root_name):
		return null

	if parts.size() == 1:
		return _nested_properties[root_name]

	return _nested_properties[root_name].get_child(parts[1])

## Gets a property value by its full path
func get_property_value(path: String) -> Variant:
	# Try regular property first
	var property = get_property(path)
	if property != null:
		return property.value

	# Try nested property
	var nested = get_nested_property(path)
	if nested != null and nested.type == NestedProperty.Type.PROPERTY:
		return nested.get_value()

	return null

## Sets a property value by its full path
func set_property_value(path: String, value: Variant) -> Result:
	# Try regular property first
	var property = get_property(path)
	if property != null:
		var old_value = property.value
		var result = property.set_value(value)
		if not result.has_error():
			property_changed.emit(path, old_value, value)
		return result

	# Try nested property
	var nested = get_nested_property(path)
	if nested != null and nested.type == NestedProperty.Type.PROPERTY:
		var old_value = nested.get_value()
		var result = nested.set_value(value)
		if not result.has_error():
			property_changed.emit(nested.get_full_path(), old_value, value)
		return result

	return Result.new(
		Result.ErrorType.NOT_FOUND,
		"Property '%s' not found" % path
	)
#endregion

#region Property Information
func get_properties() -> Array[Property]:
	var properties: Array[Property] = []
	for property in _properties.values():
		properties.append(property)
	return properties

func get_property_names() -> Array[String]:
	var names: Array[String] = []
	for key in _properties.keys():
		names.append(key)
	return names

func get_nested_property_paths() -> Array[String]:
	var paths: Array[String] = []
	for property in _nested_properties.values():
		_collect_nested_paths(property, paths)
	return paths

func has_property(name: String) -> bool:
	return _properties.has(name)

func has_nested_property(path: String) -> bool:
	return get_nested_property(path) != null
#endregion

#region Helper Functions
func _validate_property_accessors(name: String, getter: Callable, setter: Callable) -> bool:
	if not _is_valid_getter(getter):
		return false

	if setter.is_valid() and not _is_valid_setter(setter):
		return false

	return true

func _validate_nested_property_tree(property: NestedProperty) -> Result:
	# Validate this property's accessors if it's a leaf
	if property.type == NestedProperty.Type.PROPERTY:
		if not _is_valid_getter(property.getter):
			return Result.new(
				Result.ErrorType.INVALID_GETTER,
				"Invalid getter for property '%s'" % property.get_full_path()
			)
		if property.setter.is_valid() and not _is_valid_setter(property.setter):
			return Result.new(
				Result.ErrorType.INVALID_SETTER,
				"Invalid setter for property '%s'" % property.get_full_path()
			)

	# Recursively validate children
	for child in property.children.values():
		var result = _validate_nested_property_tree(child)
		if result.has_error():
			return result

	return Result.new()

func _setup_nested_dependencies(property: NestedProperty) -> void:
	if property.type == NestedProperty.Type.PROPERTY:
		# Add this property's dependencies to the map
		for dependency in property.dependencies:
			if not _local_dependency_map.has(dependency):
				_local_dependency_map[dependency] = []
			_local_dependency_map[dependency].append(property.get_full_path())

	# Recursively process children
	for child in property.children.values():
		_setup_nested_dependencies(child)

func _cleanup_nested_dependencies(property: NestedProperty) -> void:
	if property.type == NestedProperty.Type.PROPERTY:
		# Remove this property's dependencies from the map
		var full_path = property.get_full_path()
		for deps in _local_dependency_map.values():
			deps.erase(full_path)

	# Recursively process children
	for child in property.children.values():
		_cleanup_nested_dependencies(child)

func _collect_nested_paths(property: NestedProperty, paths: Array[String]) -> void:
	paths.append(property.get_full_path())
	for child in property.children.values():
		_collect_nested_paths(child, paths)

func _is_valid_getter(getter: Callable) -> bool:
	return Property.is_valid_getter(getter)

func _is_valid_setter(setter: Callable) -> bool:
	return Property.is_valid_setter(setter)
#endregion
