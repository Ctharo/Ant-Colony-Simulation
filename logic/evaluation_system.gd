class_name EvaluationSystem
extends Node2D

#region Inner Classes
class ExpressionState:
	var expression: Expression
	var compiled_expression: String
	var logic: Logic  # Store reference to the Logic object
	var is_parsed: bool = false

	func _init(p_logic: Logic) -> void:
		expression = Expression.new()
		compiled_expression = p_logic.expression_string
		logic = p_logic

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

class TimingState:
	var last_eval_time: float = 0.0
	var next_allowed_time: float = 0.0
	var last_change_time: float = 0.0

	func can_evaluate(current_time: float, logic: Logic) -> bool:
		# Skip evaluation if we haven't reached the next allowed time
		if current_time < next_allowed_time:
			return false

		# Force evaluation overrides timing checks
		if logic.force_evaluation:
			next_allowed_time = current_time + logic.min_eval_interval
			return true

		var time_since_last = current_time - last_eval_time

		# Must evaluate if max interval exceeded
		if logic.max_eval_interval > 0 and time_since_last >= logic.max_eval_interval:
			next_allowed_time = current_time + logic.min_eval_interval
			return true

		# Can't evaluate if min interval not met
		if logic.min_eval_interval > 0 and time_since_last < logic.min_eval_interval:
			return false

		# For expressions with no min interval, still enforce a minimum frame time
		next_allowed_time = current_time + 0.016  # ~60fps max
		return true

	func mark_evaluated(current_time: float) -> void:
		last_eval_time = current_time

	func mark_changed(current_time: float) -> void:
		last_change_time = current_time

class ChangeState:
	var last_value: Variant = null
	var cumulative_change: float = 0.0
	var cumulative_vector_change: Vector2 = Vector2.ZERO

	func is_significant_change(old_value: Variant, new_value: Variant, threshold: float) -> bool:
		if old_value == null or threshold <= 0.0:
			return old_value != new_value

		# Handle different value types
		match typeof(new_value):
			TYPE_FLOAT:
				cumulative_change += abs(new_value - old_value)
				if cumulative_change > threshold:
					cumulative_change = 0.0
					return true
				return false
			TYPE_VECTOR2:
				var old_vec := old_value as Vector2
				var new_vec := new_value as Vector2
				cumulative_vector_change.x += abs(new_vec.x - old_vec.x)
				cumulative_vector_change.y += abs(new_vec.y - old_vec.y)
				if cumulative_vector_change.x > threshold or \
				   cumulative_vector_change.y > threshold:
					cumulative_vector_change = Vector2.ZERO
					return true
				return false
			_:
				return old_value != new_value

	func update_value(new_value: Variant) -> void:
		last_value = new_value
#endregion

#region Properties
## Evaluation controller for batching and rate limiting
@onready var _controller: EvaluationController = $EvaluationController
@onready var _cache: EvaluationCache = $EvaluationCache

## Array of registered logic expressions
var _registered_logic: Array[Logic] = []

## Currently evaluating expressions to prevent recursion
var _evaluating_expressions: Array[String] = []

## Maps expression ID to state
var _expression_states: Dictionary = {}
var _timing_states: Dictionary = {}
var _change_states: Dictionary = {}

## Entity for evaluations
var entity: Node

## Logger instance
var logger: Logger

## Performance monitoring enabled state
var _perf_monitor_enabled := false

## Threshold for logging slow evaluations (ms)
var _slow_threshold_ms := 1.0

var _last_evaluation_times: Dictionary = {}
const MIN_REQUEUE_INTERVAL := 0.016  # ~60fps
#endregion

#region Initialization
func _init() -> void:
	logger = Logger.new("eval", DebugLogger.Category.LOGIC)

func initialize(p_entity: Node) -> void:
	entity = p_entity

func _get_expression_state(expression: Logic) -> ExpressionState:
	if not _expression_states.has(expression.id):
		_expression_states[expression.id] = ExpressionState.new(expression)
	return _expression_states[expression.id]

func _get_timing_state(logic_id: String) -> TimingState:
	if not _timing_states.has(logic_id):
		_timing_states[logic_id] = TimingState.new()
	return _timing_states[logic_id]

func _get_change_state(logic_id: String) -> ChangeState:
	if not _change_states.has(logic_id):
		_change_states[logic_id] = ChangeState.new()
	return _change_states[logic_id]
#endregion

#region Expression Processing
func _process(_delta: float) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var processed_this_frame = {}

	# Check all registered logic for evaluation needs
	for logic in _registered_logic:
		if logic == null or logic.id.is_empty():
			continue

		# Skip if already processed this frame
		if processed_this_frame.has(logic.id):
			continue

		# Check if enough time has passed since last evaluation
		var last_eval_time = _last_evaluation_times.get(logic.id, 0.0)
		if current_time - last_eval_time < MIN_REQUEUE_INTERVAL:
			continue

		var timing_state = _get_timing_state(logic.id)
		var needs_eval = false

		# Check evaluation conditions
		if logic.force_evaluation or logic.needs_immediate_eval():
			needs_eval = true
		elif timing_state.can_evaluate(current_time, logic):
			# Check if value is invalid or dependencies have changed
			needs_eval = _cache.needs_update(logic.id) or _has_changed_dependencies(logic)

		if needs_eval:
			if logic.needs_immediate_eval() or logic.force_evaluation:
				_controller.queue_high_priority(logic.id)
				logger.trace("Queued high priority: %s (force=%s, immediate=%s)" % [
					logic.id,
					logic.force_evaluation,
					logic.needs_immediate_eval()
				])
			else:
				_controller.queue_normal_priority(logic.id)
				logger.trace("Queued normal priority: %s" % logic.id)

			processed_this_frame[logic.id] = true

	# Let controller handle actual evaluations
	_controller.process_evaluations()

func _has_changed_dependencies(logic: Logic) -> bool:
	for nested in logic.nested_expressions:
		if _cache.has_changed_this_frame(nested.id):
			return true
	return false

func _on_evaluation_complete(expression_id: String) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	_last_evaluation_times[expression_id] = current_time
	logger.trace("Completed evaluation of %s at %.3f" % [expression_id, current_time])

func _on_expression_value_changed(_value: Variant, expression_id: String) -> void:
	# Invalidate cache and dependencies
	_cache.invalidate_value(expression_id)
	_cache.invalidate_dependents(expression_id)

	# Force re-evaluation of dependents
	var dependents = _cache.get_dependents(expression_id)
	for dependent in dependents:
		if dependent in _registered_logic:
			_controller.queue_normal_priority(dependent)
			logger.trace("Requeued dependent expression: %s" % dependent)

# Update cache handling
func get_value(expression: Logic, force_update: bool = false) -> Variant:
	assert(expression != null and not expression.id.is_empty())
	logger.trace("Getting value: id=%s force=%s" % [expression.id, force_update])

	# Prevent recursive evaluation
	if expression.id in _evaluating_expressions:
		return _cache.get_value(expression.id)

	_evaluating_expressions.append(expression.id)

	var current_time = Time.get_ticks_msec() / 1000.0
	var timing_state = _get_timing_state(expression.id)
	var change_state = _get_change_state(expression.id)

	# Calculate new value if needed
	force_update = force_update or expression.force_evaluation
	var needs_update = force_update or not _cache.has_valid_value(expression.id)

	var result
	if needs_update and timing_state.can_evaluate(current_time, expression):
		timing_state.mark_evaluated(current_time)
		result = _calculate(expression.id)

		# Update cache and notify changes
		if change_state.is_significant_change(_cache.get_value(expression.id), result, expression.change_threshold):
			_cache.set_value(expression.id, result)
			timing_state.mark_changed(current_time)
		else:
			_cache.set_value(expression.id, result, false)

		change_state.update_value(result)
	else:
		result = _cache.get_value(expression.id)

	_evaluating_expressions.erase(expression.id)
	return result

func register_expression(expression: Logic) -> void:
	if expression.id.is_empty():
		expression.id = str(expression.get_instance_id())

	logger.trace("Expression details: string=%s, force_eval=%s, nested=%s" % [
		expression.expression_string,
		expression.force_evaluation,
		expression.nested_expressions
	])

	# Create and parse state
	var state := _get_expression_state(expression)
	if not state.is_parsed:
		_parse_expression(expression)

	# Register nested expressions and dependencies
	for nested in expression.nested_expressions:
		if nested == null:
			logger.error("Cannot register null nested expression")
			return

		logger.trace("Registering nested expression %s for %s" % [
			nested.id,
			expression.id
		])
		register_expression(nested)
		_cache.add_dependency(expression.id, nested.id)

	if not expression in _registered_logic:
		_registered_logic.append(expression)

	logger.trace("Completed registration of %s" % expression.id)


#endregion

#region Private Methods
func _parse_expression(expression: Logic) -> void:
	var state := _get_expression_state(expression)
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

	var state: ExpressionState = _expression_states[expression_id]
	if not state.is_parsed:
		return null

	logger.trace("Calculating %s" % expression_id)

	# Get values from nested expressions
	var bindings = []
	for nested in state.logic.nested_expressions:
		logger.trace("Getting nested value for %s" % nested.id)
		var force = nested.force_evaluation
		# Don't force if we're in a recursive situation
		if nested.id in _evaluating_expressions:
			force = false
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

	if _perf_monitor_enabled:
		var duration = (Time.get_ticks_usec() - start_time) / 1000.0
		if duration > _slow_threshold_ms:
			logger.warn("Slow expression calculation: id=%s duration=%.2fms" % [
				expression_id,
				duration
			])

	logger.debug("Final result for %s = %s" % [expression_id, result])

	return result
#endregion

#region Signal Handlers

func _on_expression_dependencies_changed(expression_id: String) -> void:
	_cache.invalidate_dependents(expression_id)
#endregion
