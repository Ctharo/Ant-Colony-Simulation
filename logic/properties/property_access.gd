class_name PropertyAccess
extends BaseRefCounted
## Central system for managing property trees and accessing properties

#region Signals
signal property_changed(path: String, old_value: Variant, new_value: Variant)
#endregion

#region Member Variables
## Root level property containers
var _property_groups: Dictionary = {}  # name -> PropertyNode

## Caching system for property values
var _cache: Cache

## Owner entity for context
var _owner: Object
#endregion

func _init(owner: Object, use_caching: bool = true) -> void:
	_owner = owner
	_cache = Cache.new() if use_caching else null

	log_category = DebugLogger.Category.PROPERTY
	log_from = "property_access"

	_trace("PropertyAccess initialized with caching: %s" % use_caching)

#region Property Group Management
## Registers a new property tree at the root level
func register_group(root: PropertyNode) -> Result:
	return register_group_at_path(root, null)

## Registers a property tree at a specific path
func register_group_at_path(root: PropertyNode, parent_path: Path) -> Result:
	if not root:
		return Result.new(
			Result.ErrorType.INVALID_ARGUMENT,
			"Cannot register null property node"
		)

	# For root registration
	if not parent_path:
		if _property_groups.has(root.name):
			return Result.new(
				Result.ErrorType.DUPLICATE,
				"Property group '%s' already registered" % root.name
			)
		_property_groups[root.name] = root
		_invalidate_group_cache(root.name)
		_trace("Registered root property group: %s" % root.name)
		return Result.new()

	# For nested registration
	var parent = get_property(parent_path)
	if not parent:
		return Result.new(
			Result.ErrorType.NOT_FOUND,
			"Parent path not found: %s" % parent_path
		)

	if parent.type != PropertyNode.Type.CONTAINER:
		return Result.new(
			Result.ErrorType.TYPE_MISMATCH,
			"Parent path is not a container: %s" % parent_path
		)

	# Add all children of the root to the parent container
	for child in root.children.values():
		parent.add_child(child)

	_invalidate_cache(parent_path)
	_trace("Registered nested property group '%s' at path '%s'" % [
		root.name,
		parent_path
	])
	return Result.new()

## Removes a property tree from a specific path
func remove_group_at_path(group_name: String, parent_path: Path) -> Result:
	if not parent_path:
		return remove_group(group_name)

	var parent = get_property(parent_path)
	if not parent or parent.type != PropertyNode.Type.CONTAINER:
		return Result.new(
			Result.ErrorType.NOT_FOUND,
			"Parent container not found: %s" % parent_path
		)

	var removed = false
	for child in parent.children.values():
		if child.name == group_name:
			parent.remove_child(child.name)
			removed = true
			break

	if not removed:
		return Result.new(
			Result.ErrorType.NOT_FOUND,
			"Group '%s' not found at path '%s'" % [group_name, parent_path]
		)

	_invalidate_cache(parent_path)
	_trace("Removed nested property group '%s' from path '%s'" % [
		group_name,
		parent_path
	])
	return Result.new()

## Removes a property tree from the system
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
func get_property(path: Path) -> PropertyNode:
	if not path or path.parts.is_empty():
		_error("Invalid property path")
		return null

	var group_name = path.parts[0]
	var group = _property_groups.get(group_name)
	if not group:
		_error("Property group not found: %s" % group_name)
		return null

	# If only requesting the root group
	if path.parts.size() == 1:
		return group

	# Look for nested property
	return group.find_node(Path.new(path.parts.slice(1)))

## Get a property by string path
func get_property_from_str(path: String) -> PropertyNode:
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

	if property.type != PropertyNode.Type.VALUE:
		_error("Cannot get value from container property: %s" % path)
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

	if property.type != PropertyNode.Type.VALUE:
		return Result.new(
			Result.ErrorType.TYPE_MISMATCH,
			"Cannot set value for container property: %s" % path
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
func get_group_properties(group_name: String) -> Array[PropertyNode]:
	var group = _property_groups.get(group_name)
	if not group:
		_error("Property group not found: %s" % group_name)
		return []

	return group.get_all_values()

## Get all registered group names
func get_group_names() -> Array[String]:
	var names: Array[String] = []
	names.append_array(_property_groups.keys())
	return names

## Get children at a specific path
func get_children_at_path(path: Path) -> Array[PropertyNode]:
	var property = get_property(path)
	if not property or property.type != PropertyNode.Type.CONTAINER:
		return []
	return property.children.values()
#endregion

#region Cache Management
## Invalidate cache for a specific property
func _invalidate_cache(path: Path) -> void:
	if _cache:
		_cache.invalidate(path)
		# Invalidate any properties that depend on this one
		for group in _property_groups.values():
			for property in group.get_all_values():
				if property.dependencies.has(path):
					_cache.invalidate(property.get_path())

## Invalidate cache for all properties in a group
func _invalidate_group_cache(group_name: String) -> void:
	if not _cache:
		return

	var group = _property_groups.get(group_name)
	if not group:
		return

	for property in group.get_all_values():
		_invalidate_cache(property.get_path())
#endregion
