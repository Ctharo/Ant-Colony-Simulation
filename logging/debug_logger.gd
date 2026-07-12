class_name DebugLogger
extends RefCounted
## Central logging funnel.
##
## Levels are gated PER CATEGORY: a message prints only if its level is at or
## below min(global log_level, category_levels[category]). The global level is
## a master cap; per-category levels tune verbosity independently.
##
## ERROR and WARN are exempt from ALL filtering. They always reach the editor's
## Debugger -> Errors tab (via push_error / push_warning, with stack trace) AND
## always print to Output, no matter which categories are muted. An error in a
## muted category is still an error.
##
## Doctrine (see ERRORS.md): never call push_error/push_warning directly from
## instanced code — go through an iLogger. Static / pre-logger contexts (e.g.
## DefaultLibrarySeeder) use the static DebugLogger.error()/warn() funnels.

## Log levels for different types of messages
enum LogLevel {
	NONE = 0,    ## No logging
	ERROR = 1,   ## Error messages only
	WARN = 2,    ## Warnings and errors
	INFO = 3,    ## General information
	DEBUG = 4,   ## Detailed debug information
	TRACE = 5,   ## Most verbose logging
}

## Categories for different components
enum Category {
	TASK,           ## Task-related messages
	LOGIC,          ## Logic evaluation messages
	MOVEMENT,       ## Movement-related messages
	INFLUENCE,      ## Influence system messages
	BEHAVIOR,       ## Behavior-related messages
	CONDITION,      ## Condition evaluation messages
	CONTEXT,        ## Context building messages
	ENTITY,         ## Ant, colony, pheromone, etc. related messages
	PROPERTY,       ## Property-related messages
	TRANSITION,     ## State transition messages
	HIERARCHY,      ## Tree hierarchy messages
	UI,             ## UI-related messages
	PROGRAM,        ## Program-related messages
	DATA,           ## Data-related messages
}


#region Configuration

## Global level CAP - default to TRACE, SettingsManager will set the actual
## value. Effective level for a message = min(log_level, category level).
static var log_level := LogLevel.TRACE

## Show context in logs
static var show_context: bool = false

## Registered logic expressions (for debugging)
static var registered_logic: PackedStringArray = []
static var parsed_expression_strings: PackedStringArray = []

## Source filtering configuration
class SourceFilter:
	var enabled: bool
	var categories: Array[Category]

	func _init(p_enabled: bool = true, p_categories: Array[Category] = []) -> void:
		enabled = p_enabled
		categories = p_categories

## Maps source identifiers to their filter configuration
static var source_filters: Dictionary = {}

## Per-category log levels (Category -> LogLevel). NONE = muted.
## Initialized so PROGRAM can log before SettingsManager applies real values.
static var category_levels: Dictionary = _create_initial_category_levels()

## Create initial category levels - only PROGRAM open by default.
## This ensures we can log during startup before SettingsManager runs.
static func _create_initial_category_levels() -> Dictionary:
	var levels := {}
	for category in Category.keys():
		levels[Category[category]] = LogLevel.TRACE if category == "PROGRAM" else LogLevel.NONE
	return levels

#endregion


#region Formatting Constants

## Color codes for different log levels
const COLORS := {
	LogLevel.ERROR: "ff5555",
	LogLevel.WARN: "ffb86c",
	LogLevel.INFO: "8be9fd",
	LogLevel.DEBUG: "50fa7b",
	LogLevel.TRACE: "bd93f9"
}

## Category names for pretty printing
const CATEGORY_NAMES := {
	Category.TASK: "TASK",
	Category.MOVEMENT: "MOVEMENT",
	Category.LOGIC: "LOGIC",
	Category.INFLUENCE: "INFLUENCE",
	Category.BEHAVIOR: "BEHAVIOR",
	Category.CONDITION: "CONDITION",
	Category.PROPERTY: "PROPERTY",
	Category.CONTEXT: "CONTEXT",
	Category.ENTITY: "ENTITY",
	Category.TRANSITION: "TRANSITION",
	Category.HIERARCHY: "HIERARCHY",
	Category.UI: "UI",
	Category.DATA: "DATA",
	Category.PROGRAM: "PROGRAM"
}

#endregion


#region Configuration Methods

## Configure source filtering
static func configure_source(source: String, enabled: bool = true, categories: Array[Category] = []) -> void:
	source_filters[source] = SourceFilter.new(enabled, categories)


## Set the log level for a specific category
static func set_category_level(category: Category, level: LogLevel, from: String = "") -> void:
	var current: int = category_levels.get(category, LogLevel.NONE)
	if current != level:
		category_levels[category] = level
		info(Category.PROGRAM, "Set category %s to level %s" % [
			CATEGORY_NAMES[category],
			LogLevel.keys()[level]
		], {"from": from if from else "debug_logger"})


## Back-compat shim over set_category_level.
## enabled -> TRACE (category fully open; the global cap decides what prints),
## disabled -> NONE. This reproduces the old boolean semantics exactly.
static func set_category_enabled(category: Category, enabled: bool = true, from: String = "") -> void:
	set_category_level(category, LogLevel.TRACE if enabled else LogLevel.NONE, from)


## Set the global log level cap
static func set_log_level(level: LogLevel, from: String = "") -> void:
	if DebugLogger.log_level != level:
		info(Category.PROGRAM, "Set log level to %s" % LogLevel.keys()[level],
			{"from": from if from else "debug_logger"})
	DebugLogger.log_level = level


## Enable or disable context printing
static func set_show_context(enabled: bool = true, from: String = "") -> void:
	if DebugLogger.show_context != enabled:
		info(Category.PROGRAM, "%s context display" % ["Enabled" if enabled else "Disabled"],
			{"from": from if from else "debug_logger"})
	DebugLogger.show_context = enabled


## Current configured level for a category (before applying the global cap)
static func get_category_level(category: Category) -> LogLevel:
	return category_levels.get(category, LogLevel.NONE) as LogLevel


## The level that actually gates messages: min(global cap, category level)
static func effective_level(category: Category) -> LogLevel:
	return mini(log_level, category_levels.get(category, LogLevel.NONE)) as LogLevel


## Check if a category is enabled at all (any level above NONE)
static func is_category_enabled(category: Category) -> bool:
	return effective_level(category) > LogLevel.NONE


## Check if a given level would print for a given category.
## NOTE: pure filter check — ERROR/WARN bypass this in log() regardless.
static func is_level_enabled(category: Category, level: LogLevel) -> bool:
	return level <= effective_level(category)

#endregion


#region Logging Implementation

## Source-filter check only (category levels are handled in log())
static func _source_allows(source: String, category: Category) -> bool:
	# If no source filter exists, allow logging
	if not source_filters.has(source):
		return true

	var filter: SourceFilter = source_filters[source]

	# If source is disabled, block logging
	if not filter.enabled:
		return false

	# If source has specific categories and this category isn't included, block logging
	if not filter.categories.is_empty() and not category in filter.categories:
		return false

	return true


## Determine if a message should be logged. ERROR/WARN always pass.
static func should_log(source: String, category: Category, level: LogLevel = LogLevel.INFO) -> bool:
	if level == LogLevel.NONE:
		return false
	if level <= LogLevel.WARN:
		return true
	if level > effective_level(category):
		return false
	return _source_allows(source, category)


## Log a message with specified level and category
static func log(level: LogLevel, category: Category, message: String, context: Dictionary = {}) -> void:
	if level == LogLevel.NONE:
		return

	var source: String = context.get("from", "")
	var always_surface := level <= LogLevel.WARN

	if not always_surface:
		# Filters only apply to INFO/DEBUG/TRACE
		if level > effective_level(category):
			return
		if not _source_allows(source, category):
			return

	if always_surface:
		_push_native(level, category, source, message)

	_print_formatted(level, category, source, message, context)


## Mirror ERROR/WARN into the editor debugger (Errors tab, with stack trace)
static func _push_native(level: LogLevel, category: Category, source: String, message: String) -> void:
	var tagged := "[%s]%s %s" % [
		CATEGORY_NAMES[category],
		"[%s]" % source if source else "",
		message
	]
	if level == LogLevel.ERROR:
		push_error(tagged)
	elif level == LogLevel.WARN:
		push_warning(tagged)


## Rich-text Output print (formatting unchanged from previous version)
static func _print_formatted(level: LogLevel, category: Category, source: String,
		message: String, context: Dictionary) -> void:
	var timestamp: String = Time.get_datetime_string_from_system()
	var level_name: String = LogLevel.keys()[level]
	var category_name: String = CATEGORY_NAMES[category]
	var color: String = COLORS.get(level, "ffffff")

	# Split message into lines and format each line
	var lines: PackedStringArray = message.split("\n")
	var formatted_message := ""

	for i in range(lines.size()):
		var line: String = lines[i]
		if i == 0:
			# First line gets full header
			formatted_message += "[color=#%s][%s][%s][%s]%s %s" % [
				color,
				timestamp,
				level_name,
				category_name,
				"[%s]" % source if source else "",
				line
			]
		else:
			# Subsequent lines get indented and colored
			formatted_message += "\n[color=#%s]    %s" % [color, line]

	# Add context information if provided and enabled
	if show_context and not context.is_empty():
		formatted_message += "\n[color=#%s]    Context: %s" % [color, str(context)]

	# Add color end tag just once at the end
	formatted_message += "[/color]"

	print_rich(formatted_message)

#endregion


#region Convenience Methods

static func error(category: Category, message: String, context: Dictionary = {}) -> void:
	DebugLogger.log(LogLevel.ERROR, category, message, context)


static func warn(category: Category, message: String, context: Dictionary = {}) -> void:
	DebugLogger.log(LogLevel.WARN, category, message, context)


static func info(category: Category, message: String, context: Dictionary = {}) -> void:
	DebugLogger.log(LogLevel.INFO, category, message, context)


static func debug(category: Category, message: String, context: Dictionary = {}) -> void:
	DebugLogger.log(LogLevel.DEBUG, category, message, context)


static func trace(category: Category, message: String, context: Dictionary = {}) -> void:
	DebugLogger.log(LogLevel.TRACE, category, message, context)

#endregion


#region Level Check Methods (global-cap only; prefer is_level_enabled)

static func is_trace_enabled() -> bool:
	return LogLevel.TRACE <= log_level


static func is_debug_enabled() -> bool:
	return LogLevel.DEBUG <= log_level

#endregion
