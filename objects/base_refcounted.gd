class_name BaseRefCounted
extends RefCounted

var log_category: DebugLogger.Category = DebugLogger.Category.PROGRAM
var log_from: String = ""

#region Logging Methods
## Logs a trace message
## [param message] The message to log
func _trace(message: String) -> void:
	DebugLogger.trace(log_category,
		message,
		{"from": log_from}
	)

## Logs a warning message
## [param message] The message to log
func _warn(message: String) -> void:
	DebugLogger.warn(log_category,
		message,
		{"from": log_from}
	)

## Logs a debug message
## [param message] The message to log
func _debug(message: String) -> void:
	DebugLogger.debug(log_category,
		message,
		{"from": log_from}
	)

## Logs an info message
## [param message] The message to log
func _info(message: String) -> void:
	DebugLogger.info(log_category,
		message,
		{"from": log_from}
	)

## Logs an error message
## [param message] The message to log
func _error(message: String) -> void:
	DebugLogger.error(log_category,
		message,
		{"from": log_from}
	)
#endregion
