class_name iLogger
extends RefCounted
## Per-object logging facade over DebugLogger.
##
## Error doctrine (see ERRORS.md):
##  - error()/warn() ALWAYS surface (push_error/push_warning into the editor
##    debugger + Output print), regardless of category or source filters.
##    Never call push_error/push_warning directly from instanced code.
##  - invariant() guards programmer bugs: hard assert (stops at the line) in
##    debug builds, logged error + continue in release builds.
##  - require() guards data/environment failures: logs once at the source and
##    returns the condition so the caller can bail:
##        if not logger.require(profile != null, "No profile for '%s'" % id):
##            return null

var _log_from: String
var _log_category: DebugLogger.Category
var _additional_log_categories: Array[DebugLogger.Category]


func _init(name: String, category: DebugLogger.Category,
		additional_categories: Array[DebugLogger.Category] = []) -> void:
	_log_from = name
	_log_category = category
	_additional_log_categories = additional_categories
	_configure_logger()


func _configure_logger() -> void:
	var categories: Array[DebugLogger.Category] = [_log_category]
	categories.append_array(_additional_log_categories)
	DebugLogger.configure_source(_log_from, true, categories)


## -1 sentinel = "use this logger's default category". (GDScript default
## parameter values must be constant, so the default can't be _log_category.)
func _resolve(category: int) -> DebugLogger.Category:
	return _log_category if category < 0 else (category as DebugLogger.Category)


#region Level Guards
## Category-aware guards for skipping expensive message construction:
##   if logger.is_debug_enabled():
##       logger.debug(build_expensive_dump())

func is_trace_enabled(category: int = -1) -> bool:
	return DebugLogger.is_level_enabled(_resolve(category), DebugLogger.LogLevel.TRACE)


func is_debug_enabled(category: int = -1) -> bool:
	return DebugLogger.is_level_enabled(_resolve(category), DebugLogger.LogLevel.DEBUG)

#endregion


#region Logging Methods

func trace(message: String, category: int = -1) -> void:
	DebugLogger.trace(_resolve(category), message, {"from": _log_from})


func debug(message: String, category: int = -1) -> void:
	DebugLogger.debug(_resolve(category), message, {"from": _log_from})


func info(message: String, category: int = -1) -> void:
	DebugLogger.info(_resolve(category), message, {"from": _log_from})


func warn(message: String, category: int = -1) -> void:
	DebugLogger.warn(_resolve(category), message, {"from": _log_from})


func error(message: String, category: int = -1) -> void:
	DebugLogger.error(_resolve(category), message, {"from": _log_from})

#endregion


#region Error Doctrine Helpers

## Programmer invariant: "this cannot be false unless the CODE is wrong."
## Debug builds: logs the error, then assert(false) stops execution at the
## call site with the message. Release builds: assert compiles out, so it
## degrades to a logged error and execution continues.
## NEVER use for data/user/environment failures (missing .tres, user-deleted
## catalog entries, unparseable files) — those are reachable in release and
## belong to require() + graceful handling.
## Returns the condition so it can double as a guard in release:
##     if not logger.invariant(kind in USER_ROOTS, "Unknown kind '%s'" % kind):
##         return
func invariant(condition: bool, message: String) -> bool:
	if not condition:
		error("INVARIANT VIOLATED: %s" % message)
		assert(false, "[%s] %s" % [_log_from, message])
	return condition


## Data/environment guard: logs an ERROR once at the detection site and
## returns the condition. The caller decides what happens next (fallback,
## skip, propagate) WITHOUT re-logging — one failure, one log line.
func require(condition: bool, message: String) -> bool:
	if not condition:
		error(message)
	return condition


## Same as require() but at WARN severity, for recoverable/expected misses
## (e.g. an optional condition id that resolves to nothing).
func require_warn(condition: bool, message: String) -> bool:
	if not condition:
		warn(message)
	return condition

#endregion
