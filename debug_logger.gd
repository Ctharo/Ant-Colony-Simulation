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
	ACTION,         ## Action-related messages
	BEHAVIOR,       ## Behavior-related messages
	CONDITION,      ## Condition evaluation messages
	CONTEXT,        ## Context building messages
	ENTITY,         ## Ant, colony, pheromone, etc. related messages
	PROPERTY,       ## Property-related messsages
	TRANSITION,     ## State transition messages
	HIERARCHY,      ## Tree hierarchy messages
	PROGRAM         ## Program-related messages
}

## Current log level
static var log_level := LogLevel.INFO

static var enabled_from := {}

## Enabled categories (dictionary for O(1) lookup)
static var enabled_categories := {
	Category.TASK: false,
	Category.ACTION: false,
	Category.BEHAVIOR: false,
	Category.CONDITION: false,
	Category.PROPERTY: false,
	Category.CONTEXT: false,
	Category.ENTITY: false,
	Category.TRANSITION: false,
	Category.HIERARCHY: false,
	Category.PROGRAM: true
}

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
	Category.PROGRAM: "PROGRAM"
}

## Enable or disable specific categories
static func set_category_enabled(category: Category, enabled: bool = true) -> void:
	enabled_categories[category] = enabled
	var t = "Enabled" if enabled else "Disabled"
	info(DebugLogger.Category.PROGRAM, "%s logging category %s" % [t, CATEGORY_NAMES[category]])

## Set the global log level
static func set_log_level(level: LogLevel) -> void:
	log_level = level
	info(DebugLogger.Category.PROGRAM, "Set log level to %s" % level)

static func set_from_enabled(from_string: String, enabled: bool = true) -> void:
	enabled_from[from_string] = enabled
	var t = "Enabled" if enabled else "Disabled"
	info(DebugLogger.Category.PROGRAM, "%s logs from %s" % [t, from_string])

## Log a message with specified level and category
static func log(level: LogLevel, category: Category, message: String, context: Dictionary = {}) -> void:
	var log_level_check: bool = level > log_level
	var sent_from: String = context.get("from", "")
	var enabled_sender = enabled_from.get(sent_from, false)
	if log_level_check:
		if not enabled_sender:
			return
		

	var timestamp = Time.get_datetime_string_from_system()
	var level_name = LogLevel.keys()[level]
	var category_name = CATEGORY_NAMES[category]
	var color = COLORS.get(level, "ffffff")

	var formatted_message = "[color=#%s][%s][%s][%s] %s[/color]" % [
		color,
		timestamp,
		level_name,
		category_name,
		message
	]

	# Add context information if provided
	if not context.is_empty():
		formatted_message += "\n  Context: " + str(context)

	print_rich(formatted_message)

## Convenience methods for different log levels
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
