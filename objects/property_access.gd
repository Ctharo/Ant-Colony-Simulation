class_name PropertyAccess
extends RefCounted

signal property_changed(path: String, old_value: Variant, new_value: Variant)

var _root_nodes: Dictionary = {}  # name -> PropertyNode
var _node_map: Dictionary = {}    # path string -> PropertyNode
var _owner: Object
var _validator: PropertyValidator
var _property_logger: PropertyLogger

func _init(owner: Object) -> void:
	_owner = owner
	_validator = PropertyValidator.new()
	_property_logger = PropertyLogger.new()

## Registers a property tree and builds the path map
func register_node_tree(root: PropertyNode) -> Result:
	if not root:
		return Result.new(Result.ErrorType.INVALID_ARGUMENT, "Cannot register null node")

	if _root_nodes.has(root.name):
		return Result.new(Result.ErrorType.DUPLICATE, "Root already exists")

	# Store root node
	_root_nodes[root.name] = root

	# Build path map from tree
	_build_path_map(root)

	return Result.new()

## Recursively builds path map for quick node lookup
func _build_path_map(node: PropertyNode) -> void:
	_node_map[node.path.full] = node

	for child in node.children.values():
		_build_path_map(child)

## Gets a property node
func get_property(path: Variant) -> PropertyNode:
	var property_path = _validator.validate_path(path)

	if not property_path or property_path.is_root():
		return null

	return _node_map.get(property_path.full)

## Gets a property's value
func get_property_value(path: Variant) -> Variant:
	var property_path = _validator.validate_path(path)
	if not property_path:
		return null

	var node = get_property(property_path)
	var validation = _validator.validate_node_operation(node, property_path)
	if not validation.success():
		return null

	var value = node.get_value()
	_property_logger.log_access(property_path, value, "READ")
	return value

## Sets a property's value
func set_property_value(path: Variant, value: Variant) -> Result:
	var property_path = _validator.validate_path(path)
	if not property_path:
		return Result.new(Result.ErrorType.INVALID_PATH, "Invalid path")

	var node = get_property(property_path)
	var validation = _validator.validate_node_operation(node, property_path, true)
	if not validation.success():
		return validation

	var old_value = node.get_value()
	var result = node.set_value(value)

	if result.success():
		_property_logger.log_change(property_path, old_value, value)
		property_changed.emit(property_path.full, old_value, value)
		_property_logger.log_access(property_path, value, "WRITE")

	return result

## Removes a property tree and its path mappings
func remove_node(root_name: String) -> Result:
	var root = _root_nodes.get(root_name)
	if not root:
		return Result.new(Result.ErrorType.NOT_FOUND, "Root node not found: %s" % root_name)

	# Remove from path map recursively
	_remove_from_path_map(root)

	# Remove root node
	_root_nodes.erase(root_name)

	return Result.new()

## Recursively removes nodes from path map
func _remove_from_path_map(node: PropertyNode) -> void:
	_node_map.erase(node.path.full)

	for child in node.children.values():
		_remove_from_path_map(child)

## Gets all registered nodes matching a path pattern
func get_nodes_matching(pattern: String) -> Array[PropertyNode]:
	var matches: Array[PropertyNode] = []
	for path: String in _node_map:
		if path.match(pattern):
			matches.append(_node_map[path])
	return matches

func get_root_names() -> Array:
	return _root_nodes.keys()
