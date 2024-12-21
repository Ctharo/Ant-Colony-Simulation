class_name Logger
extends RefCounted

var _log_from: String
var _log_category: DebugLogger.Category
var _additional_log_categories: Array[DebugLogger.Category]


func _init(name: String, category: DebugLogger.Category, additional_categories: Array[DebugLogger.Category] = []) -> void:
	_log_from = name
	_log_category = category
	_additional_log_categories = additional_categories
	_configure_logger()

func _configure_logger() -> void:
	var categories = [_log_category] as Array[DebugLogger.Category]
	categories.append_array(_additional_log_categories)
	DebugLogger.configure_source(_log_from, true, categories)
	
static func is_trace_enabled() -> bool:
	return DebugLogger.is_trace_enabled()
	
static func is_debug_enabled() -> bool:
	return DebugLogger.is_debug_enabled()
	
#region Logging Methods
func trace(message: String, category: DebugLogger.Category = _log_category) -> void:
	if DebugLogger.log_level >= DebugLogger.LogLevel.TRACE:
		DebugLogger.trace(category, message, {"from": _log_from})

func debug(message: String, category: DebugLogger.Category = _log_category) -> void:
	DebugLogger.debug(category, message, {"from": _log_from})

func info(message: String, category: DebugLogger.Category = _log_category) -> void:
	DebugLogger.info(category, message, {"from": _log_from})

func warn(message: String, category: DebugLogger.Category = _log_category) -> void:
	DebugLogger.warn(category, message, {"from": _log_from})

func error(message: String, category: DebugLogger.Category = _log_category) -> void:
	DebugLogger.error(category, message, {"from": _log_from})

func set_logging_category(category: DebugLogger.Category, enabled: bool = true) -> void:
	DebugLogger.set_category_enabled(category, enabled, _log_from)

func set_logging_level(level: DebugLogger.LogLevel) -> void:
	DebugLogger.set_log_level(level, _log_from)
#endregion
