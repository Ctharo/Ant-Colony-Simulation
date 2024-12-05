class_name PropertyAccess
extends RefCounted

signal property_changed(path: String, old_value: Variant, new_value: Variant)

var _root_nodes: Dictionary = {}
var _owner: Object
var _validator: PropertyValidator
var _property_logger: PropertyLogger

func _init(owner: Object) -> void:
	_owner = owner
	_validator = PropertyValidator.new()
	_property_logger = PropertyLogger.new()

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

func set_property_value(path: Variant, value: Variant) -> Result:
	var property_path: Path = _validator.validate_path(path)
	if not property_path:
		return Result.new(Result.ErrorType.INVALID_PATH, "Invalid path")

	var node: PropertyNode = get_property(property_path)
	var validation: Result = _validator.validate_node_operation(node, property_path, true)
	if not validation.success():
		return validation

	var old_value: Variant = node.get_value()
	var result: Result = node.set_value(value)

	if result.success():
		_property_logger.log_change(property_path, old_value, value)
		property_changed.emit(property_path.full, old_value, value)
		_property_logger.log_access(property_path, value, "WRITE")

	return result

func get_property(path: Path) -> PropertyNode:
	if not path or path.is_root():
		return null

	var root = _root_nodes.get(path.get_root_name())
	return root.find_node(path) if root else null

func register_node(root: PropertyNode) -> Result:
	if not root:
		return Result.new(Result.ErrorType.INVALID_ARGUMENT, "Cannot register null node")

	if _root_nodes.has(root.name):
		return Result.new(Result.ErrorType.DUPLICATE, "Root already exists")

	_root_nodes[root.name] = root
	return Result.new()

func register_node_from_resource(resource: PropertyResource) -> Result:
	var node = PropertyTreeBuilder.build(resource, _owner)
	if not node:
		return Result.new(Result.ErrorType.INVALID_RESOURCE, "Failed to create property tree")
	return register_node(node)
