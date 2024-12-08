class_name DebugLogger
extends RefCounted

## Log levels for different types of messages
enum LogLevel {
	NONE = 0,    ## No logging
	ERROR = 1,   ## Error messages only
	WARN = 2,    ## Warnings and errors
	INFO = 3,    ## General information
	DEBUG = 4,   ## Detailed debug information
	TRACE = 5    ## Most verbose logging
}

## Categories for different components
enum Category {
	TASK,           ## Task-related messages
	ENTITY,
	ACTION,         ## Action-related messages
	BEHAVIOR,       ## Behavior-related messages
	CONDITION,      ## Condition evaluation messages
	CONTEXT,        ## Context building messages
	LOGIC,          ## Logic-related messages
	PROPERTY,       ## Property-related messsages
	TRANSITION,     ## State transition messages
	HIERARCHY,      ## Tree hierarchy messages
	UI,             ## UI-related messages
	PROGRAM,        ## Program-related messages
	DATA,           ## Data-related messages
}

#region Configuration
## Current log level
static var log_level := LogLevel.INFO

## Show context in logs
static var show_context: bool = false

## Source filtering configuration
class SourceFilter:
	var enabled: bool
	var categories: Array[Category]

	func _init(p_enabled: bool = true, p_categories: Array[Category] = []) -> void:
		enabled = p_enabled
		categories = p_categories

## Maps source identifiers to their filter configuration
static var source_filters: Dictionary = {}

## Enabled categories (whitelist)
static var enabled_categories := {
	Category.TASK: false,
	Category.ACTION: false,
	Category.BEHAVIOR: false,
	Category.CONDITION: false,
	Category.PROPERTY: false,
	Category.CONTEXT: false,
	Category.ENTITY: true,
	Category.TRANSITION: false,
	Category.HIERARCHY: false,
	Category.UI: false,
	Category.PROGRAM: true, # Should always be on?
	Category.DATA: false
}
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
	Category.ACTION: "ACTION",
	Category.BEHAVIOR: "BEHAVIOR",
	Category.CONDITION: "CONDITION",
	Category.PROPERTY: "PROPERTY",
	Category.CONTEXT: "CONTEXT",
	Category.ENTITY: "ENTITY",
	Category.TRANSITION: "TRANSITION",
	Category.HIERARCHY: "HIERARCHY",
	Category.UI: "UI",
	Category.DATA: "DATA",
	Category.PROGRAM: "PROGRAM" # Should always be on?
}
#endregion

#region Configuration Methods
## Configure source filtering
static func configure_source(source: String, enabled: bool = true, categories: Array[Category] = []) -> void:
	source_filters[source] = SourceFilter.new(enabled, categories)
	#info(Category.PROGRAM, "Configured source '%s' (enabled: %s, categories: %s)" % [
		#source, enabled, categories
	#])

## Enable or disable specific categories
static func set_category_enabled(category: Category, enabled: bool = true, from: String = "") -> void:
	enabled_categories[category] = enabled
	info(Category.PROGRAM, "%s logging category %s" % [
				"Enabled" if enabled else "Disabled",
				CATEGORY_NAMES[category]
			],
		{"from": from if from else "debug_logger"}
	)

## Set the global log level
static func set_log_level(level: LogLevel, from: String = "") -> void:
	log_level = level
	info(Category.PROGRAM, "Set log level to %s" % LogLevel.keys()[level], {"from": from if from else "debug_logger"})

## Enable or disable context print
static func set_show_context(enabled: bool = true, from: String = "") -> void:
	show_context = enabled
	info(Category.PROGRAM, "%s context display" % ["Enabled" if enabled else "Disabled"], {"from": from if from else "debug_logger"})
#endregion

#region Logging Implementation
## Determine if a message should be logged based on source and category
static func should_log(source: String, category: Category) -> bool:
	# First check if the category is enabled globally
	if not enabled_categories.get(category, false):
		return false

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

## Log a message with specified level and category
static func log(level: LogLevel, category: Category, message: String, context: Dictionary = {}) -> void:
	# Check log level first
	if level > log_level:
		return

	var source = context.get("from", "")

	# Check if this combination of source and category should be logged
	if not should_log(source, category):
		return

	var timestamp = Time.get_datetime_string_from_system()
	var level_name = LogLevel.keys()[level]
	var category_name = CATEGORY_NAMES[category]
	var color = COLORS.get(level, "ffffff")

	# Split message into lines and format each line
	var lines = message.split("\n")
	var formatted_message = ""

	for i in range(lines.size()):
		var line = lines[i]
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
			formatted_message += "\n[color=#%s]    %s" % [
				color,
				line
			]

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
