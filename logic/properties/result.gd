## Base class for all property-related results
class_name Result
extends RefCounted

enum ErrorType {
	NONE,               # No error
	INVALID_PATH,       # Property path format is invalid
	NO_CONTEXT,         # Required context object missing
	NO_CONTAINER,       # Container object not found
	NOT_FOUND,          # Something doesn't exist
	ACCESS_ERROR,       # Error accessing
	INVALID_ARGUMENT,   # Invalid argument passed
	INVALID_OPERATOR,
	INVALID_VALUE,
	TYPE_MISMATCH,      # Type doesn't match expected
	DUPLICATE,          # Something already exists
	INVALID_GETTER,     # Getter method is invalid
	INVALID_SETTER,     # Setter method is invalid
	SYSTEM_ERROR,       # Critical system component unavailable or not initialized
	CACHE_ERROR         # Error with cache operations
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
