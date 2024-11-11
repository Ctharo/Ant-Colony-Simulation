class_name PropertyContainer
extends RefCounted

#region Signals
signal property_added(path: String)
signal property_removed(path: String)
signal property_changed(path: String, old_value: Variant, new_value: Variant)
#endregion

#region Member Variables
## Root container of all properties
var _root: NestedProperty

## Reference to the owner object
var _owner: Object

## Dictionary mapping full paths to their dependent properties
var _dependency_map: Dictionary = {}
#endregion

func _init(owner: Object) -> void:
	_owner = owner
	_root = NestedProperty.create("root").as_container().described_as("Root property container").build()




#region Property Management
## Registers a new property branch (former Attribute)
func register_branch(name: String, properties: NestedProperty) -> Result:
	if has_branch(name):
		return Result.new(
			Result.ErrorType.DUPLICATE,
			"Branch '%s' already exists" % name
		)

	var validation_result = _validate_property_tree(properties)
	if validation_result.has_error():
		return validation_result

	_root.add_child(properties)
	_setup_dependencies(properties)
	property_added.emit(properties.get_full_path())
	return Result.new()

## Removes a property branch
func remove_branch(name: String) -> Result:
	var branch = get_branch(name)
	if not branch:
		return Result.new(
			Result.ErrorType.NOT_FOUND,
			"Branch '%s' doesn't exist" % name
		)

	_cleanup_dependencies(branch)
	_root.children.erase(name)
	property_removed.emit(branch.get_full_path())
	return Result.new()

## Gets a property value by its full path
func get_value(path: String) -> Variant:
	var property = get_property(path)
	if property and property.type == NestedProperty.Type.PROPERTY:
		return property.get_value()
	return null

## Sets a property value by its full path
func set_value(path: String, value: Variant) -> Result:
	var property = get_property(path)
	if not property:
		return Result.new(
			Result.ErrorType.NOT_FOUND,
			"Property '%s' not found" % path
		)

	if property.type != NestedProperty.Type.PROPERTY:
		return Result.new(
			Result.ErrorType.TYPE_MISMATCH,
			"'%s' is not a value property" % path
		)

	var old_value = property.get_value()
	var result = property.set_value(value)
	if not result.has_error():
		property_changed.emit(path, old_value, value)
		_notify_dependents(path)
	return result
#endregion

#region Property Access
func get_branch(name: String) -> NestedProperty:
	return _root.children.get(name)

func get_property(path: String) -> NestedProperty:
	if path.is_empty():
		return null

	var parts = path.split(".", true, 1)
	var branch_name = parts[0]

	var branch = get_branch(branch_name)
	if not branch:
		return null

	if parts.size() == 1:
		return branch

	return branch.get_child(parts[1])

func get_branch_names() -> Array[String]:
	return _root.children.keys()

func get_all_paths() -> Array[String]:
	var paths: Array[String] = []
	_collect_paths(_root, paths)
	return paths

func has_branch(name: String) -> bool:
	return _root.children.has(name)

func has_property(path: String) -> bool:
	return get_property(path) != null
#endregion

#region Dependencies
func get_dependencies(path: String) -> Array[String]:
	var property = get_property(path)
	if not property or property.type != NestedProperty.Type.PROPERTY:
		return []
	return property.dependencies

func get_dependents(path: String) -> Array[String]:
	return _dependency_map.get(path, [])

func _setup_dependencies(property: NestedProperty) -> void:
	if property.type == NestedProperty.Type.PROPERTY:
		# Add this property's dependencies to the map
		for dependency in property.dependencies:
			if not _dependency_map.has(dependency):
				_dependency_map[dependency] = []
			_dependency_map[dependency].append(property.get_full_path())

	# Recursively process children
	for child in property.children.values():
		_setup_dependencies(child)

func _cleanup_dependencies(property: NestedProperty) -> void:
	if property.type == NestedProperty.Type.PROPERTY:
		# Remove this property from dependency lists
		var path = property.get_full_path()
		for deps in _dependency_map.values():
			deps.erase(path)
		# Remove its own dependency entries
		_dependency_map.erase(path)

	# Recursively process children
	for child in property.children.values():
		_cleanup_dependencies(child)

func _notify_dependents(path: String) -> void:
	var dependents = get_dependents(path)
	for dependent in dependents:
		property_changed.emit(dependent, null, get_value(dependent))
#endregion

#region Helper Functions
func _validate_property_tree(property: NestedProperty) -> Result:
	if property.type == NestedProperty.Type.PROPERTY:
		if not NestedProperty.is_valid_getter(property.getter):
			return Result.new(
				Result.ErrorType.INVALID_GETTER,
				"Invalid getter for property '%s'" % property.get_full_path()
			)
		if property.setter.is_valid() and not NestedProperty.is_valid_setter(property.setter):
			return Result.new(
				Result.ErrorType.INVALID_SETTER,
				"Invalid setter for property '%s'" % property.get_full_path()
			)

	for child in property.children.values():
		var result = _validate_property_tree(child)
		if result.has_error():
			return result

	return Result.new()

func _collect_paths(property: NestedProperty, paths: Array[String], current_path: String = "") -> void:
	var path = current_path + ("." if not current_path.is_empty() else "") + property.name
	if property.type == NestedProperty.Type.PROPERTY:
		paths.append(path)
	for child in property.children.values():
		_collect_paths(child, paths, path)
#endregion
