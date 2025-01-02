class_name EvaluationCache
extends Node2D

#region Properties
signal value_invalidated(expression_id: String)

var _values: Dictionary = {}
var _timestamps: Dictionary = {}
var _dependencies: Dictionary = {}
var _reverse_dependencies: Dictionary = {}
var _changed_this_frame: Dictionary = {}
var _invalidation_count: Dictionary = {}
var _last_invalidation_time: Dictionary = {}
var _valid_flags: Dictionary = {}  # New: Track validity of cached values

var logger: Logger

const MIN_INVALIDATION_INTERVAL := 0.05
#endregion

func _init() -> void:
	logger = Logger.new("evaluation_cache", DebugLogger.Category.LOGIC)

#region Cache Operations
func set_value(expression_id: String, value: Variant, trigger_dependencies: bool = true) -> void:
	var old_value = _values.get(expression_id)
	var has_changed = old_value != value

	_values[expression_id] = value
	_timestamps[expression_id] = Time.get_ticks_msec() / 1000.0
	_valid_flags[expression_id] = true  # Mark as valid when set

	if has_changed and trigger_dependencies:
		_changed_this_frame[expression_id] = true
		logger.trace("Value changed for %s, triggering dependencies" % expression_id)
		invalidate_dependents(expression_id)

func has_value(expression_id: String) -> bool:
	return _values.has(expression_id) and _valid_flags.get(expression_id, false)

func has_valid_value(expression_id: String) -> bool:
	return has_value(expression_id) and not _changed_this_frame.get(expression_id, false)

func get_value(expression_id: String) -> Variant:
	return _values.get(expression_id)

func needs_update(expression_id: String) -> bool:
	return not has_valid_value(expression_id)

func invalidate_value(expression_id: String) -> void:
	_valid_flags[expression_id] = false
	_changed_this_frame[expression_id] = true
	value_invalidated.emit(expression_id)
	logger.trace("Invalidated value for %s" % expression_id)
#endregion

#region Dependency Management
func add_dependency(dependent: String, dependency: String) -> void:
	if not _dependencies.has(dependent):
		_dependencies[dependent] = []
	if not dependency in _dependencies[dependent]:
		_dependencies[dependent].append(dependency)
		logger.trace("Added forward dependency: %s depends on %s" % [dependent, dependency])

	if not _reverse_dependencies.has(dependency):
		_reverse_dependencies[dependency] = []
	if not dependent in _reverse_dependencies[dependency]:
		_reverse_dependencies[dependency].append(dependent)
		logger.trace("Added reverse dependency: %s affects %s" % [dependency, dependent])

func get_dependents(expression_id: String) -> Array:
	return _reverse_dependencies.get(expression_id, []).duplicate()

func get_dependencies(expression_id: String) -> Array:
	return _dependencies.get(expression_id, []).duplicate()

func remove_expression(id: String) -> void:
	_dependencies.erase(id)
	_values.erase(id)
	_timestamps.erase(id)
	_changed_this_frame.erase(id)
	_valid_flags.erase(id)

	if _reverse_dependencies.has(id):
		for dependent in _reverse_dependencies[id]:
			var deps = _dependencies.get(dependent, [])
			deps.erase(id)
			if deps.is_empty():
				_dependencies.erase(dependent)
		_reverse_dependencies.erase(id)

	logger.trace("Removed expression %s and its dependencies" % id)
#endregion

#region Invalidation
func invalidate_dependents(expression_id: String) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var last_time = _last_invalidation_time.get(expression_id, 0.0)

	if current_time - last_time < MIN_INVALIDATION_INTERVAL:
		logger.trace("Skipping invalidation for %s due to rate limiting" % expression_id)
		return

	_invalidate_dependents(expression_id)
	_last_invalidation_time[expression_id] = current_time

func _invalidate_dependents(expression_id: String) -> void:
	if not _reverse_dependencies.has(expression_id):
		return

	var dependents = _reverse_dependencies[expression_id]
	for dependent_id in dependents:
		_valid_flags[dependent_id] = false
		_changed_this_frame[dependent_id] = true
		value_invalidated.emit(dependent_id)
		logger.trace("Invalidated dependent %s due to change in %s" % [dependent_id, expression_id])

		# Cascade invalidation to higher-level dependents
		_invalidate_dependents(dependent_id)

func clear_frame_changes() -> void:
	_changed_this_frame.clear()
#endregion
