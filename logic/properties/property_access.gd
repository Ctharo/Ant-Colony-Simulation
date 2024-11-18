class_name PropertyAccess
extends BaseRefCounted
## Central system for managing property trees and accessing properties

#region Signals
signal property_changed(path: String, old_value: Variant, new_value: Variant)
#endregion

#region Member Variables
## Root level property containers
var _root_nodes: Dictionary = {}  # name -> PropertyNode

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

#region Property Node Management
## Registers a new property tree at the root level
func register_node(root: PropertyNode) -> Result:
	return register_node_at_path(root, null)

## Registers a property tree at a specific path
func register_node_at_path(root: PropertyNode, parent_path: Path) -> Result:
	if not root:
		return Result.new(
			Result.ErrorType.INVALID_ARGUMENT,
			"Cannot register null property node"
		)

	# For root registration
	if not parent_path:
		if _root_nodes.has(root.name):
			return Result.new(
				Result.ErrorType.DUPLICATE,
				"Root node '%s' already registered" % root.name
			)
		_root_nodes[root.name] = root
		_invalidate_node_cache(root.name)
		_trace("Registered root node: %s" % root.name)
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
	_trace("Registered nested node '%s' at path '%s'" % [
		root.name,
		parent_path
	])
	return Result.new()

## Removes a property tree from a specific path
func remove_node_at_path(node_name: String, parent_path: Path) -> Result:
	if not parent_path:
		return remove_node(node_name)

	var parent = get_property(parent_path)
	if not parent or parent.type != PropertyNode.Type.CONTAINER:
		return Result.new(
			Result.ErrorType.NOT_FOUND,
			"Parent container not found: %s" % parent_path
		)

	var removed = false
	for child in parent.children.values():
		if child.name == node_name:
			parent.remove_child(child.name)
			removed = true
			break

	if not removed:
		return Result.new(
			Result.ErrorType.NOT_FOUND,
			"Node '%s' not found at path '%s'" % [node_name, parent_path]
		)

	_invalidate_cache(parent_path)
	_trace("Removed nested node '%s' from path '%s'" % [
		node_name,
		parent_path
	])
	return Result.new()

## Removes a property tree from the root level
func remove_node(name: String) -> Result:
	if not _root_nodes.has(name):
		return Result.new(
			Result.ErrorType.NOT_FOUND,
			"Root node '%s' not found" % name
		)

	_invalidate_node_cache(name)
	_root_nodes.erase(name)

	_trace("Removed root node: %s" % name)
	return Result.new()
#endregion

#region Core Property Access
## Get a property by its path
func get_property(path: Path) -> PropertyNode:
	if not path or path.parts.is_empty():
		_error("Invalid property path")
		return null

	var root_name = path.parts[0]
	var root = _root_nodes.get(root_name)
	if not root:
		_error("Root node not found: %s" % root_name)
		return null

	# If only requesting the root node
	if path.parts.size() == 1:
		return root

	# Look for nested property
	return root.find_node(Path.new(path.parts.slice(1)))

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
## Get all value properties for a root node
func get_node_properties(node_name: String) -> Array[PropertyNode]:
	var node = _root_nodes.get(node_name)
	if not node:
		_error("Root node not found: %s" % node_name)
		return []

	return node.get_all_values()

## Get all registered root node names
func get_root_names() -> Array[String]:
	var names: Array[String] = []
	names.append_array(_root_nodes.keys())
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
		for root in _root_nodes.values():
			for property in root.get_all_values():
				if property.dependencies.has(path):
					_cache.invalidate(property.get_path())

## Invalidate cache for all properties in a root node
func _invalidate_node_cache(node_name: String) -> void:
	if not _cache:
		return

	var node = _root_nodes.get(node_name)
	if not node:
		return

	for property in node.get_all_values():
		_invalidate_cache(property.get_path())
#endregion
