class_name PropertyAccess
extends RefCounted
## Front-end class for accessing ant properties with caching support

#region Signals
## Emitted when a property value changes
signal property_changed(path: String, old_value: Variant, new_value: Variant)
#endregion

#region Member Variables
## Container for all property groups
var _property_groups: Dictionary = {}  # name -> PropertyGroup

## Caching system for property values
var _cache: Cache
#endregion

func _init(owner: Object, use_caching: bool = true) -> void:
	_cache = Cache.new() if use_caching else null
	_trace("PropertyAccess initialized with caching: %s" % use_caching)

#region Property Group Management
## Registers a new property group with the system
func register_group(group: PropertyGroup) -> Result:
	if not group:
		return Result.new(
			Result.ErrorType.INVALID_ARGUMENT,
			"Cannot register null property group"
		)

	if _property_groups.has(group.name):
		return Result.new(
			Result.ErrorType.DUPLICATE,
			"Property group '%s' already registered" % group.name
		)

	_property_groups[group.name] = group
	_invalidate_group_cache(group.name)

	_trace("Registered property group: %s" % group.name)
	return Result.new()

## Removes a property group from the system
func remove_group(name: String) -> Result:
	if not _property_groups.has(name):
		return Result.new(
			Result.ErrorType.NOT_FOUND,
			"Property group '%s' not found" % name
		)

	_invalidate_group_cache(name)
	_property_groups.erase(name)

	_trace("Removed property group: %s" % name)
	return Result.new()
#endregion

#region Core Property Access
## Get a property by its path
func get_property(path: Path) -> NestedProperty:
	if not path or path.parts.is_empty():
		_error("Invalid property path")
		return null

	var group_name = path.parts[0]
	var group = _property_groups.get(group_name)
	if not group:
		_error("Property group not found: %s" % group_name)
		return null

	return group.get_property(path.to_string())

## Get a property by string path
func get_property_from_str(path: String) -> NestedProperty:
	if not path:
		_error("Invalid property path")
		return null

	return get_property(Path.parse(path))

## Get a property's value with caching support
func get_property_value(path: Path) -> Variant:
	# Check cache first if enabled
	if _cache and _cache.has_valid_cache(path):
		return _cache.get_cached(path)

	var property = get_property(path)
	if not property:
		_error("Property not found: %s" % path)
		return null

	var value = property.get_value()

	# Cache the value if caching is enabled
	if _cache:
		var result = _cache.cache_value(path, value)
		if result.is_error():
			_error("Problem caching value for %s: %s" % [path, result.get_error()])

	return value

## Set a property's value
func set_property_value(path: Path, value: Variant) -> Result:
	var property = get_property(path)
	if not property:
		return Result.new(
			Result.ErrorType.NOT_FOUND,
			"Property not found: %s" % path
		)

	var old_value = property.get_value()
	var result = property.set_value(value)

	if result.is_ok():
		_invalidate_cache(path)
		property_changed.emit(path.to_string(), old_value, value)

	return result
#endregion

#region Property Access Methods
## Get all properties for a group
func get_group_properties(group_name: String) -> Array[NestedProperty]:
	var group = _property_groups.get(group_name)
	if not group:
		_error("Property group not found: %s" % group_name)
		return []

	return group.get_properties()

## Get all registered group names
func get_group_names() -> Array[String]:
	var a: Array[String] = []
	for key in _property_groups.keys():
		a.append(key)
	return a

## Get a property group by name
func get_group(name: String) -> PropertyGroup:
	return _property_groups.get(name)
#endregion

#region Cache Management
## Invalidate cache for a specific property
func _invalidate_cache(path: Path) -> void:
	if _cache:
		_cache.invalidate(path)
		# Invalidate any properties that depend on this one
		for group in _property_groups.values():
			for property in group.get_properties():
				if property.dependencies.has(path):
					_cache.invalidate(property.get_path())

## Invalidate cache for all properties in a group
func _invalidate_group_cache(group_name: String) -> void:
	if not _cache:
		return

	var group = _property_groups.get(group_name)
	if not group:
		return

	for property in group.get_properties():
		_invalidate_cache(property.get_path())
#endregion

#region Logging Methods
func _trace(message: String) -> void:
	DebugLogger.trace(
		DebugLogger.Category.PROPERTY,
		message,
		{"From": "property_access"}
	)

func _warn(message: String) -> void:
	DebugLogger.warn(
		DebugLogger.Category.PROPERTY,
		message
	)

func _error(message: String) -> void:
	DebugLogger.error(
		DebugLogger.Category.PROPERTY,
		message
	)
#endregion
