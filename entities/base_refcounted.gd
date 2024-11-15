class_name BaseRefCounted
extends RefCounted

## Default category for logging
var log_category: DebugLogger.Category = DebugLogger.Category.PROGRAM :
	set(value):
		log_category = value
		_configure_logger()

## Source identifier for logging
var log_from: String = "" :
	set(value):
		log_from = value
		_configure_logger()

## Additional categories this class can log to
var additional_log_categories: Array[DebugLogger.Category] = [] :
	set(value):
		additional_log_categories = value
		_configure_logger()

## Called when the reference counted object is initialized
func _init() -> void:
	# Configure logger if log_from is set
	if not log_from.is_empty():
		_configure_logger()

## Configures the logger with current settings
func _configure_logger() -> void:
	if log_from.is_empty():
		return

	var categories = [log_category] as Array[DebugLogger.Category]
	categories.append_array(additional_log_categories)
	DebugLogger.configure_source(log_from, true, categories)

#region Logging Methods
## Logs a trace message
## [param message] The message to log
## [param category] Optional override for log category
func _trace(message: String, category: DebugLogger.Category = log_category) -> void:
	DebugLogger.trace(category, message, {"from": log_from})

## Logs a debug message
## [param message] The message to log
## [param category] Optional override for log category
func _debug(message: String, category: DebugLogger.Category = log_category) -> void:
	DebugLogger.debug(category, message, {"from": log_from})

## Logs an info message
## [param message] The message to log
## [param category] Optional override for log category
func _info(message: String, category: DebugLogger.Category = log_category) -> void:
	DebugLogger.info(category, message, {"from": log_from})

## Logs a warning message
## [param message] The message to log
## [param category] Optional override for log category
func _warn(message: String, category: DebugLogger.Category = log_category) -> void:
	DebugLogger.warn(category, message, {"from": log_from})

## Logs an error message
## [param message] The message to log
## [param category] Optional override for log category
func _error(message: String, category: DebugLogger.Category = log_category) -> void:
	DebugLogger.error(category, message, {"from": log_from})
#endregion
