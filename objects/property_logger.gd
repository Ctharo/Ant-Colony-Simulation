class_name PropertyLogger
extends RefCounted

var logger: Logger
var _last_access_stats: Dictionary = {}

func _init() -> void:
	logger = Logger.new("property_logger", DebugLogger.Category.PROPERTY)

func log_access(path: Path, value: Variant, operation: String) -> void:
	var now = Time.get_ticks_msec()
	var stats = _last_access_stats.get(path.full, {
		"timestamp": 0,
		"value": null,
		"count": 0
	})

	if now - stats.timestamp < 1000 and stats.value == value:
		stats.count += 1
		if stats.count % 10 == 0:
			logger.trace("[%s] %s accessed %d times, value: %s" % [
				operation,
				path.full,
				stats.count,
				Property.format_value(value)
			])
	else:
		if stats.count > 1:
			logger.trace("[%s] Final summary - %s accessed %d times with value: %s" % [
				operation,
				path.full,
				stats.count,
				Property.format_value(stats.value)
			])
		logger.trace("[%s] %s = %s" % [
			operation,
			path.full,
			Property.format_value(value)
		])
		stats = {
			"timestamp": now,
			"value": value,
			"count": 1
		}

	_last_access_stats[path.full] = stats

func log_change(path: Path, old_value: Variant, new_value: Variant) -> void:
	if old_value == new_value:
		return

	logger.trace("Property changed: %s\n" % path.full +
		"  From: %s\n" % Property.format_value(old_value) +
		"  To:   %s" % Property.format_value(new_value)
	)
