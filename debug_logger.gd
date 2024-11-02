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
	TRANSITION,     ## State transition messages
	HIERARCHY,      ## Tree hierarchy messages
	PROGRAM         ## Program-related messages
	
}

## Current log level
static var log_level := LogLevel.INFO

## Enabled categories (dictionary for O(1) lookup)
static var enabled_categories := {
	Category.TASK: true,
	Category.ACTION: true,
	Category.BEHAVIOR: true,
	Category.CONDITION: true,
	Category.CONTEXT: true,
	Category.TRANSITION: true,
	Category.HIERARCHY: true,
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
	Category.CONTEXT: "CONTEXT",
	Category.TRANSITION: "TRANSITION",
	Category.HIERARCHY: "HIERARCHY",
	Category.PROGRAM: "PROGRAM"
}

## Enable or disable specific categories
static func set_category_enabled(category: Category, enabled: bool) -> void:
	enabled_categories[category] = enabled

## Set the global log level
static func set_log_level(level: LogLevel) -> void:
	log_level = level

## Log a message with specified level and category
static func log(level: LogLevel, category: Category, message: String, context: Dictionary = {}) -> void:
	if level > log_level or not enabled_categories.get(category, false):
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
