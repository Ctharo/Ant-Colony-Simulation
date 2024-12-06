class_name PropertyValidator
extends RefCounted

const ERROR_MESSAGES = {
	NODE_NOT_FOUND = "Node not found: %s",
	INVALID_PATH = "Invalid path: %s",
	NULL_PATH = "Path cannot be null",
	ROOT_NOT_FOUND = "Root node not found: %s",
	CONTAINER_VALUE_ERROR = "Cannot get value from container node: %s",
	CONTAINER_SET_ERROR = "Cannot set value for container node: %s",
	VALUE_SET_ERROR = "Failed to set value for %s: %s"
}

var logger: Logger

func _init() -> void:
	logger = Logger.new("property_validator", DebugLogger.Category.PROPERTY)

func validate_path(path: Variant) -> Path:
	match typeof(path):
		TYPE_STRING:
			if path.is_empty():
				logger.error("Empty path string")
				return null
			return Path.parse(path)
		TYPE_OBJECT:
			if path is Path:
				return path
			logger.error("Invalid object type for path: %s" % path.get_class())
			return null
		_:
			logger.error("Invalid type for path: %s" % typeof(path))
			return null

func validate_node_operation(node: PropertyNode, path: Path, for_write: bool = false) -> Result:
	if not node:
		return Result.new(
			Result.ErrorType.NOT_FOUND,
			ERROR_MESSAGES.NODE_NOT_FOUND % path.full
		)

	if for_write and not node.has_valid_accessor(true):
		return Result.new(
			Result.ErrorType.INVALID_SETTER,
			"Invalid setter for property: %s" % path.full
		)

	if node is PropertyValue and not node.has_valid_accessor():
		return Result.new(
			Result.ErrorType.INVALID_GETTER,
			"Invalid getter for property: %s" % path.full
		)

	return Result.new()
