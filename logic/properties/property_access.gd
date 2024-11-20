class_name PropertyAccess
extends BaseRefCounted
## Central system for managing property trees and accessing properties

#region Signals
signal property_changed(path: String, old_value: Variant, new_value: Variant)
#endregion

#region Member Variables
## Root level property container nodes
var _root_nodes: Dictionary = {}  # name -> PropertyNode

## Caching system for property values
var _cache: Cache

## Owner entity for context
var _owner: Object

var _last_access_stats: Dictionary = {}  # path -> {timestamp, value, count}
#endregion

func _init(owner: Object, use_caching: bool = true) -> void:
	_owner = owner
	_cache = Cache.new() if use_caching else null

	log_category = DebugLogger.Category.PROPERTY
	log_from = "property_access"

	_debug("Initialized for %s [Cache: %s]" % [owner.get_class(), "enabled" if use_caching else "disabled"])

#region Node Management
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
	var parent = find_property_node(parent_path)
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

	var parent = find_property_node(parent_path)
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

#region Node Access
## Find a property node by its path
func find_property_node(path: Path) -> PropertyNode:
	if not path:
		_error("Path cannot be null")
		return null

	if path.is_root():
		_error("Cannot find node at root path")
		return null

	# Direct lookup for root level nodes
	if path.is_root_node():
		return get_root_node(path.get_root_name())

	# Get root node first
	var root = get_root_node(path.get_root_name())
	if not root:
		return null  # Error already logged by get_root_node

	# Find nested node
	return root.find_node(path)

## Get a root node by name
func get_root_node(name: String) -> PropertyNode:
	var node = _root_nodes.get(name)
	if not node:
		_error("Root node not found: %s" % name)
	return node

## Get all value nodes in a root
func get_root_values(root_name: String) -> Array[PropertyNode]:
	var root = get_root_node(root_name)
	if not root:
		_error("Root node not found: %s" % root_name)
		return []

	return root.get_all_values()

## Get all containers under a root node
func get_root_containers(root_name: String) -> Array[PropertyNode]:
	var root = get_root_node(root_name)
	if not root:
		_error("Root node not found: %s" % root_name)
		return []

	return root.get_all_containers()

## Get all registered root names
func get_root_names() -> Array[String]:
	var names: Array[String] = []
	names.append_array(_root_nodes.keys())
	return names

## Get children at a specific path
func get_children_at_path(path: Path) -> Array[PropertyNode]:
	var node = find_property_node(path)
	if not node or node.type != PropertyNode.Type.CONTAINER:
		return []
	return node.children.values()

func _get_dependent_paths(path: Path) -> Array[String]:
	var dependent_paths: Array[String] = []

	for root in _root_nodes.values():
		for value_node in root.get_all_values():
			if value_node.dependencies.has(path):
				dependent_paths.append(value_node.path.full)

	return dependent_paths

#endregion

#region Value Access
## Get a property's value with caching support
func get_property_value(path: Path) -> Variant:
	if _cache and _cache.has_valid_cache(path):
		var value = _cache.get_cached(path)
		_log_property_access(path, value, "READ[cached]")
		return value

	var node = find_property_node(path)
	if not node:
		_error("Node not found: %s" % path.full)
		return null

	if node.type != PropertyNode.Type.VALUE:
		_error("Cannot get value from container node: %s" % path.full)
		return null

	var value = node.get_value()

	if _cache:
		var result = _cache.cache_value(path, value)
		if result.is_error():
			_warn("Cache failed for %s: %s" % [path.full, result.get_error()])

	_log_property_access(path, value, "READ")
	return value


## Set a property's value
func set_property_value(path: Path, value: Variant) -> Result:
	var node = find_property_node(path)
	if not node:
		_error("Node not found: %s" % path.full)
		return Result.new(Result.ErrorType.NOT_FOUND, "Property not found")

	if node.type != PropertyNode.Type.VALUE:
		_error("Cannot set value for container node: %s" % path.full)
		return Result.new(Result.ErrorType.TYPE_MISMATCH, "Not a value node")

	var old_value = node.get_value()
	var result = node.set_value(value)

	if result.success():
		_log_property_change(path, old_value, value)
		_invalidate_cache(path)
		property_changed.emit(path.full, old_value, value)
		_log_property_access(path, value, "WRITE")
	else:
		_error("Failed to set value for %s: %s" % [path.full, result.get_error()])

	return result
#endregion

#region Cache Management
## Invalidate cache for a specific property
func _invalidate_cache(path: Path) -> void:
	if _cache:
		_cache.invalidate(path)
		# Invalidate any properties that depend on this one
		for root in _root_nodes.values():
			for value_node in root.get_all_values():
				if value_node.dependencies.has(path):
					_cache.invalidate(value_node.path)

## Invalidate cache for all properties in a root node
func _invalidate_node_cache(node_name: String) -> void:
	if not _cache:
		return

	var root = get_root_node(node_name)
	if not root:
		return

	for value_node in root.get_all_values():
		_invalidate_cache(value_node.path)
#endregion

#region Logging Helpers
## Log property access with smart throttling and aggregation
func _log_property_access(path: Path, value: Variant, operation: String) -> void:
	var now = Time.get_ticks_msec()
	var stats = _last_access_stats.get(path.full, {
		"timestamp": 0,
		"value": null,
		"count": 0
	})

	# If same value accessed within 1 second, increment count
	if now - stats.timestamp < 1000 and stats.value == value:
		stats.count += 1
		# Only log every 10th access
		if stats.count % 10 == 0:
			_trace("[%s] %s accessed %d times, value: %s" % [
				operation,
				path.full,
				stats.count,
				Property.format_value(value)
			])
	else:
		# New access pattern, log and reset stats
		if stats.count > 1:
			_trace("[%s] Final summary - %s accessed %d times with value: %s" % [
				operation,
				path.full,
				stats.count,
				Property.format_value(stats.value)
			])
		_trace("[%s] %s = %s" % [
			operation,
			path.full,
			Property.format_value(value)
		])
		stats = {
			"timestamp": now,
			"value": value,
			"count": 1
		}

	_last_access_stats[path.full] = stats

## Log property changes with context
func _log_property_change(path: Path, old_value: Variant, new_value: Variant) -> void:
	if old_value == new_value:
		return

	_info("Property changed: %s\n" % path.full +
		"  From: %s\n" % Property.format_value(old_value) +
		"  To:   %s" % Property.format_value(new_value)
	)

	# Log any cache invalidations
	if _cache:
		var invalidated = _get_dependent_paths(path)
		if not invalidated.is_empty():
			_debug("Invalidated dependent properties:\n  - %s" % "\n  - ".join(invalidated))

## Log node registration with dependency tracking
func _log_node_registration(node: PropertyNode, parent_path: Path = null) -> void:
	var registration_info = "\nRegistered"

	if parent_path:
		registration_info += " at '%s':" % parent_path.full
	else:
		registration_info += " root node:"

	registration_info += "\n  Name: %s" % node.name
	registration_info += "\n  Type: %s" % PropertyNode.Type.keys()[node.type]

	if node.type == PropertyNode.Type.VALUE:
		registration_info += "\n  Value Type: %s" % Property.type_to_string(node.value_type)
		if not node.dependencies.is_empty():
			registration_info += "\n  Dependencies:"
			for dep in node.dependencies:
				registration_info += "\n    - %s" % dep.full

	if node.type == PropertyNode.Type.CONTAINER:
		var children = node.children.values()
		if not children.is_empty():
			registration_info += "\n  Children:"
			for child in children:
				registration_info += "\n    - %s (%s)" % [
					child.name,
					PropertyNode.Type.keys()[child.type]
				]

	_debug(registration_info)
#endregion
