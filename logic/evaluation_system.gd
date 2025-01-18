class_name EvaluationSystem
extends Node2D

#region Properties
## Evaluation controller for batching and rate limiting
@onready var _controller: EvaluationController = $EvaluationController
@onready var _cache: EvaluationCache = $EvaluationCache

## Registered logic expressions
var _registered_logic: Array[Logic] = []

## Map of expression resource ID to evaluation state
var _states: Dictionary = {}

## Cache statistics tracker
var _stats: Dictionary = {}

## Entity for evaluations
var entity: Node

## Logger instance
var logger: Logger

## Performance monitoring enabled state
var _perf_monitor_enabled := false

## Threshold for logging slow evaluations (ms)
var _slow_threshold_ms := 1.0
#endregion

#region Expression State
class ExpressionState:
	var expression: Expression
	var compiled_expression: String
	var logic: Logic  # Store reference to the Logic object
	var is_parsed: bool = false

	# Runtime state
	var last_value: Variant
	var last_eval_time: float = 0.0
	var last_change_time: float = 0.0
	var cumulative_change: float = 0.0
	var cumulative_vector_change: Vector2 = Vector2.ZERO

	func _init(p_logic: Logic) -> void:
		expression = Expression.new()
		compiled_expression = p_logic.expression_string
		logic = p_logic
		last_eval_time = Time.get_ticks_msec() / 1000.0
		last_change_time = last_eval_time

	func parse(variables: PackedStringArray) -> Error:
		if is_parsed:
			return OK

		# Check for unsafe access patterns
		var unsafe_patterns := [
			" _",  # Space followed by underscore
			"._",  # Dot followed by underscore
			"@",   # Direct property access
			"$/",  # Node path traversal
			"get_node",  # Node access
			" load",      # Resource loading
			" preload"    # Resource preloading
		]

		for pattern in unsafe_patterns:
			if compiled_expression.contains(pattern):
				push_error("Unsafe expression pattern detected: %s" % pattern)
				return ERR_UNAUTHORIZED

		# Validate variables don't contain unsafe patterns
		for var_name in variables:
			for pattern in unsafe_patterns:
				if var_name.contains(pattern):
					push_error("Unsafe variable name detected: %s" % var_name)
					return ERR_UNAUTHORIZED

		var error = expression.parse(compiled_expression, variables)
		is_parsed = error == OK
		return error

	func execute(bindings: Array, context: Object) -> Variant:
		if not is_parsed:
			return null
		return expression.execute(bindings, context)

	func has_error() -> bool:
		return expression.has_execute_failed()

	func is_significant_change(new_value: Variant) -> bool:
		if last_value == null or logic.change_threshold <= 0.0:
			return last_value != new_value

		match typeof(new_value):
			TYPE_FLOAT:
				cumulative_change += abs(new_value - last_value)
				if cumulative_change > logic.change_threshold:
					cumulative_change = 0.0
					return true
				return false

			TYPE_VECTOR2:
				var old_vec := last_value as Vector2
				var new_vec := new_value as Vector2
				cumulative_vector_change.x += abs(new_vec.x - old_vec.x)
				cumulative_vector_change.y += abs(new_vec.y - old_vec.y)
				if cumulative_vector_change.x > logic.change_threshold or \
				   cumulative_vector_change.y > logic.change_threshold:
					cumulative_vector_change = Vector2.ZERO
					return true
				return false

			_:
				return last_value != new_value

	func update_value(new_value: Variant, current_time: float) -> bool:
		var significant = is_significant_change(new_value)
		last_value = new_value
		if significant:
			last_change_time = current_time
		return significant

	func mark_evaluated(current_time: float) -> void:
		last_eval_time = current_time

	func should_evaluate(current_time: float) -> bool:
		var time_since_last = current_time - last_eval_time

		# Must evaluate if max interval exceeded
		if logic.max_eval_interval > 0 and time_since_last >= logic.max_eval_interval:
			return true

		# Can't evaluate if min interval not met
		if logic.min_eval_interval > 0 and time_since_last < logic.min_eval_interval:
			return false

		# Can evaluate if no min interval set
		return logic.min_eval_interval <= 0

	func has_changed_since(time: float) -> bool:
		return last_change_time > time
#endregion

#region Cache Statistics Structure
class ExpressionStats:
	var hits: int = 0
	var misses: int = 0

	func get_hit_rate() -> float:
		var total = hits + misses
		return 100.0 * hits / total if total > 0 else 0.0

	func to_dictionary() -> Dictionary:
		return {
			"hits": hits,
			"misses": misses,
			"hit_rate": get_hit_rate()
		}
#endregion

#region Initialization
func _init() -> void:
	logger = Logger.new("eval", DebugLogger.Category.LOGIC)

func _process(_delta: float) -> void:
	if _registered_logic.is_empty():
		return
		
	var current_time = Time.get_ticks_msec() / 1000.0

	# Check all registered logic for evaluation needs
	for logic in _registered_logic:
		var state = _states[logic.id]
		if not state.should_evaluate(current_time):
			continue

		if logic.needs_immediate_eval():
			_controller.queue_high_priority(logic.id)
		elif logic.can_eval_when_idle():
			_controller.queue_idle_priority(logic.id)
		else:
			_controller.queue_normal_priority(logic.id)

	# Let controller handle actual evaluations
	_controller.process_evaluations()

func initialize(p_entity: Node) -> void:
	entity = p_entity

func get_or_create_state(expression: Logic) -> ExpressionState:
	if expression.id.is_empty():
		logger.error("Expression has empty ID: %s" % expression)
		return null

	if not _states.has(expression.id):
		_states[expression.id] = ExpressionState.new(expression)
		
	if expression.auto_track and not expression in _registered_logic:
		_registered_logic.append(expression)

	return _states[expression.id]

func register_expression(expression: Logic) -> void:
	# Generate ID if needed
	if expression.id.is_empty():
		expression.id = str(expression.get_instance_id())

	# Log expression details for debugging
	logger.trace("Expression details: string=%s, always_eval=%s, nested=%s" % [
		expression.expression_string,
		expression.always_evaluate,
		expression.nested_expressions
	])

	# Create state (parsing will be done lazily when needed)
	var state := get_or_create_state(expression)
	if not state:
		logger.error("Failed to create state for expression %s" % expression.id)
		return

	# Register nested expressions and their dependencies
	for nested in expression.nested_expressions:
		if nested == null:
			logger.error("Cannot register null nested expression")
			continue

		# Only auto-register nested expressions if they're marked for tracking
		if nested.auto_track:
			logger.trace("Auto-registering nested expression %s for %s" % [
				nested.id,
				expression.id
			])
			register_expression(nested)
			_cache.add_dependency(expression.id, nested.id)
		else:
			logger.trace("Skipping auto-registration for nested expression %s (auto_track disabled)" % nested.id)

	# Emit signal to notify of changed dependencies
	_on_expression_dependencies_changed(expression.id)
	
	logger.trace("Completed registration of %s" % expression.id)
#endregion

#region Expression Evaluation
func get_value(expression: Logic, force_update: bool = false) -> Variant:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Lazy registration and parsing if needed
	if not _states.has(expression.id):
		logger.trace("Auto-registering expression %s" % expression.id)
		register_expression(expression)
	
	# Get expression state if available
	var state: ExpressionState = _states[expression.id]
	if not state:
		logger.error("Failed to get/create state for expression %s" % expression.id)
		return null
		
	# Lazy parsing if needed
	if not state.is_parsed:
		_parse_expression(expression)
		
	# Check if we can use cached value
	if _cache.has_value(expression.id) and not force_update:
		# Handle immediate evaluation needs
		if expression.needs_immediate_eval():
			if not state.should_evaluate(current_time):
				return _cache.get_value(expression.id)
		# Handle lazy evaluation
		elif expression.is_lazy_evaluated():
			if not _have_dependencies_changed(expression, state.last_change_time):
				return _cache.get_value(expression.id)
		# Handle normal evaluation
		elif not state.should_evaluate(current_time):
			return _cache.get_value(expression.id)

	# Calculate new value
	var result = _calculate(expression.id)

	# Update cache if value changed significantly
	if state.update_value(result, current_time):
		_cache.set_value(expression.id, result)
		logger.trace("Value changed significantly")
		expression.significant_value_change.emit(result, expression.id)
	else:
		_cache.set_value(expression.id, result, false)  # Update without triggering dependencies
		logger.trace("Value updated (not significant)")
		expression.value_changed.emit(result, expression.id)

	state.mark_evaluated(current_time)
	return result

func _have_dependencies_changed(expression: Logic, since_time: float) -> bool:
	for nested in expression.nested_expressions:
		var state: ExpressionState = _states[nested.id]
		if state.has_changed_since(since_time):
			logger.trace("Dependency %s changed since last eval" % nested.id)
			return true
	return false

func _has_always_evaluate_dependency(expression: Logic) -> bool:
	logger.trace("Checking for always_evaluate dependencies in %s" % expression.id)

	# Cache the result for this frame
	var cache_key = "_always_eval_deps_" + expression.id
	if _cache.has_value(cache_key):
		return _cache.get_value(cache_key)

	var has_always_eval = false
	for nested in expression.nested_expressions:
		if nested.always_evaluate:
			logger.trace("Found always_evaluate dependency: %s" % nested.id)
			has_always_eval = true
			break
		if _has_always_evaluate_dependency(nested):
			logger.trace("Found nested always_evaluate dependency in %s" % nested.id)
			has_always_eval = true
			break

	if not has_always_eval:
		logger.trace("No nested always_evaluate dependency found in %s" % expression.id)

	# Cache the result
	_cache.set_value(cache_key, has_always_eval)
	return has_always_eval

func _parse_expression(expression: Logic) -> void:
	var state := get_or_create_state(expression)
	if state.is_parsed or expression.expression_string.is_empty():
		return

	var variable_names = []
	for nested in expression.nested_expressions:
		if nested.name.is_empty():
			logger.error("Nested expression missing name: %s" % nested)
			return
		if nested.id.is_empty():
			logger.error("Nested expression missing ID (should be generated from name): %s" % nested)
			return
		variable_names.append(nested.id)

	if expression.id not in DebugLogger.parsed_expression_strings:
		if logger.is_debug_enabled():
			logger.debug("Parsing expression %s%s" % [
				expression.id,
				" with variables: %s" % str(variable_names) if variable_names else ""
			])
		DebugLogger.parsed_expression_strings.append(expression.id)

	var error = state.parse(PackedStringArray(variable_names))
	if error != OK:
		logger.error('Failed to parse expression "%s": %s' % [expression.name, expression.expression_string])
		return

func _calculate(expression_id: String) -> Variant:
	var start_time := 0.0
	if _perf_monitor_enabled and logger.is_debug_enabled():
		start_time = Time.get_ticks_usec()

	var state: ExpressionState = _states[expression_id]
	if not state.is_parsed:
		return null

	logger.trace("Calculating %s" % expression_id)

	# Get values from nested expressions
	var bindings = []
	for nested in state.logic.nested_expressions:
		logger.trace("Getting nested value for %s" % nested.id)
		var force = nested.always_evaluate
		var value = get_value(nested, force)
		bindings.append(value)
		logger.trace("Nested %s = %s" % [nested.id, value])

	var result = state.execute(bindings, entity)

	if state.has_error():
		logger.error('Expression execution failed: id=%s expr="%s"' % [
			expression_id,
			state.compiled_expression
		])
		return null

	if _perf_monitor_enabled and logger.is_debug_enabled():
		var duration = (Time.get_ticks_usec() - start_time) / 1000.0
		if duration > _slow_threshold_ms:
			logger.warn("Slow expression calculation: id=%s duration=%.2fms" % [
				expression_id,
				duration
			])

	if logger.is_debug_enabled():
		logger.debug("Final result for %s = %s" % [expression_id, result])

	return result
#endregion

#region Statistics
func get_expression_stats(id: String) -> Dictionary:
	if id in _stats:
		return _stats[id].to_dictionary()
	return {}

func get_cache_stats() -> Dictionary:
	var total_hits := 0
	var total_misses := 0
	var expression_stats := {}

	for id in _stats:
		var stats = _stats[id]
		total_hits += stats.hits
		total_misses += stats.misses
		expression_stats[id] = stats.to_dictionary()

	var total = total_hits + total_misses
	var overall_hit_rate = 100.0 * total_hits / total if total > 0 else 0.0

	return {
		"overall": {
			"hits": total_hits,
			"misses": total_misses,
			"hit_rate": overall_hit_rate
		},
		"expressions": expression_stats
	}
#endregion

#region Signal Handlers
func _on_expression_value_changed(_value: Variant, expression_id: String) -> void:
	_cache.invalidate_dependents(expression_id)

func _on_expression_dependencies_changed(expression_id: String) -> void:
	_cache.invalidate_dependents(expression_id)
#endregion
