class_name Result
## Base class for all property-related results

enum ErrorType {
	NONE,               # No error
	INVALID_PATH,       # Property path format is invalid
	INVALID_RESOURCE,   # Property resource is invalid
	NO_CONTEXT,         # Required context object missing
	NO_CONTAINER,       # Container object not found
	NOT_FOUND,          # Something doesn't exist
	ACCESS_ERROR,       # Error accessing
	INVALID_ARGUMENT,   # Invalid argument passed
	INVALID_OPERATOR,
	INVALID_VALUE,
	INVALID_TYPE,
	TYPE_MISMATCH,      # Type doesn't match expected
	DUPLICATE,          # Something already exists
	INVALID_GETTER,     # Getter method is invalid
	INVALID_SETTER,     # Setter method is invalid
	SYSTEM_ERROR,       # Critical system component unavailable or not initialized
	CACHE_ERROR,        # Error with cache operations
	VALIDATION_FAILED
}

var error: ErrorType
var error_message: String

func _init(p_error: ErrorType = ErrorType.NONE, p_message: String = "") -> void:
	error = p_error
	error_message = p_message

func success() -> bool:
	return error == ErrorType.NONE

func is_error() -> bool:
	return not success()

func get_error() -> String:
	return error_message

static func OK() -> Result:
	return Result.new()

static func ERROR(error_type: ErrorType, error_msg: String = "") -> Result:
	return Result.new(error_type, error_msg)
