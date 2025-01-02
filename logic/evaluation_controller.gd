class_name EvaluationController
extends Node2D

signal evaluation_completed(expression_id: String)


#region Properties
## Batch size for processing evaluations per frame
@export var batch_size: int = 10
## Maximum time budget per frame (in milliseconds)
@export var max_frame_time_ms: float = 5.0
## Default evaluation priority (higher = evaluated sooner)
@export var default_priority: int = 0
## High priority value for immediate evaluations
const HIGH_PRIORITY := 100
## Low priority value for idle evaluations
const LOW_PRIORITY := -100
## Timer for tracking frame processing time
var frame_timer: float = 0.0
## Queue of pending evaluations
var evaluation_queue: Array = []
## Map of expression IDs to their priorities
var _priorities: Dictionary = {}
## Logger instance
var logger: Logger
#endregion

<<<<<<< HEAD
class QueuedState:
	var last_queue_time: float = 0.0
	var last_eval_time: float = 0.0
	var priority: int = 0
	var evaluation_count: int = 0

	func _init(p_priority: int) -> void:
		priority = p_priority
		last_queue_time = 0.0
		last_eval_time = 0.0

	func can_queue(current_time: float) -> bool:
		# High priority expressions should still respect minimum interval
		var time_diff = current_time - last_eval_time
		if time_diff < MIN_EVAL_INTERVAL and evaluation_count > 0:
			return false

		# First evaluation or sufficient time has passed
		return last_eval_time == 0.0 or time_diff >= MIN_EVAL_INTERVAL

	func mark_evaluated(current_time: float) -> void:
		last_eval_time = current_time
		evaluation_count += 1

#region Initialization
=======
>>>>>>> parent of 1272e56 (Many updates - removed influence)
func _init() -> void:
	logger = Logger.new("eval_controller", DebugLogger.Category.LOGIC)
	logger.trace("EvaluationController initialized")

## Register an expression with a specific evaluation priority
func register_expression(expression_id: String, priority: int = default_priority) -> void:
	_priorities[expression_id] = priority
	logger.trace("Registered expression %s with priority %d" % [expression_id, priority])

## Queue expression with high priority (immediate evaluation needed)
func queue_high_priority(expression_id: String) -> void:
	_priorities[expression_id] = HIGH_PRIORITY
	if expression_id not in evaluation_queue:
		evaluation_queue.append(expression_id)
		logger.trace("Queued high priority evaluation for %s" % expression_id)

## Queue expression with normal priority
func queue_normal_priority(expression_id: String) -> void:
	_priorities[expression_id] = default_priority
	if expression_id not in evaluation_queue:
		evaluation_queue.append(expression_id)
		logger.trace("Queued normal priority evaluation for %s" % expression_id)

## Queue expression with low priority (idle evaluation)
func queue_idle_priority(expression_id: String) -> void:
	_priorities[expression_id] = LOW_PRIORITY
	if expression_id not in evaluation_queue:
		evaluation_queue.append(expression_id)
		logger.trace("Queued low priority evaluation for %s" % expression_id)

<<<<<<< HEAD
## Check if expression is already queued
func is_queued(expression_id: String) -> bool:
	return expression_id in _evaluation_queue

## Add expression to queue if not already present
func _add_to_queue(expression_id: String) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0

	# Get or create queued state with current priority
	if not _queued_states.has(expression_id):
		var priority = _priorities.get(expression_id, default_priority)
		_queued_states[expression_id] = QueuedState.new(priority)
		logger.trace("Created new queued state for %s with priority %d" % [expression_id, priority])

	var state: QueuedState = _queued_states[expression_id]

	# Always update priority to match current request
	state.priority = _priorities.get(expression_id, default_priority)

	# Check if we can queue now
	if state.can_queue(current_time):
		if not is_queued(expression_id):
			_evaluation_queue.append(expression_id)
			state.last_queue_time = current_time
			logger.trace("Added %s to queue. Queue size: %d (eval count: %d)" % [
				expression_id,
				_evaluation_queue.size(),
				state.evaluation_count
			])
		else:
			logger.trace("Expression %s already in queue" % expression_id)
	else:
		logger.trace("Expression %s throttled (last eval: %.3f, current: %.3f)" % [
			expression_id,
			state.last_eval_time,
			current_time
		])
## Check if expression should be queued
func _should_queue(expression_id: String) -> bool:
	if expression_id.is_empty():
		logger.error("Attempted to queue empty expression ID")
		return false

	if is_queued(expression_id):
		logger.trace("Expression %s already queued" % expression_id)
		return false

	return true

## Clear all queued evaluations
func clear_queue() -> void:
	_evaluation_queue.clear()
	_queued_states.clear()
	logger.trace("Evaluation queue cleared")
#endregion

#region Evaluation Processing
## Process queued evaluations within time and batch constraints
func process_evaluations() -> void:
		if _evaluation_queue.is_empty():
			return

		var start_time = Time.get_ticks_msec()
		var processed_count := 0
		var initial_queue_size := _evaluation_queue.size()
=======
## Process queued evaluations within time and batch constraints
func process_evaluations() -> void:
	if evaluation_queue.is_empty():
		return

	frame_timer = Time.get_ticks_msec()
	var processed_count := 0
	var initial_queue_size := evaluation_queue.size()
>>>>>>> parent of 1272e56 (Many updates - removed influence)

		logger.trace("Starting evaluation processing. Queue size: %d" % initial_queue_size)

<<<<<<< HEAD
		# Sort queue by priority (higher priority first)
		_evaluation_queue.sort_custom(func(a, b):
			return _priorities.get(a, default_priority) > _priorities.get(b, default_priority)
		)
=======
	# Sort queue by priority (higher priority first)
	evaluation_queue.sort_custom(func(a, b):
		return _priorities.get(a, default_priority) > _priorities.get(b, default_priority)
	)
>>>>>>> parent of 1272e56 (Many updates - removed influence)

		while not _evaluation_queue.is_empty() and processed_count < batch_size:
			var elapsed = Time.get_ticks_msec() - start_time
			if elapsed > max_frame_time_ms:
				logger.trace("Frame budget exceeded: %.2fms. Processed %d/%d expressions" % [
					elapsed, processed_count, initial_queue_size
				])
				break

<<<<<<< HEAD
			var expression_id = _evaluation_queue.pop_front()
			var state = _queued_states.get(expression_id)

			if state:
				state.mark_evaluated(Time.get_ticks_msec() / 1000.0)
				logger.trace("Processing expression %s (priority: %d, eval count: %d)" % [
					expression_id,
					_priorities.get(expression_id, default_priority),
					state.evaluation_count
				])

				expression_needs_evaluation.emit(expression_id)
				evaluation_completed.emit(expression_id)
				processed_count += 1

		if not _evaluation_queue.is_empty():
			logger.trace("Evaluation cycle complete. Processed: %d, Remaining: %d, Elapsed: %.2fms" % [
				processed_count,
				_evaluation_queue.size(),
				Time.get_ticks_msec() - start_time
			])

#endregion
=======
	while not evaluation_queue.is_empty() and processed_count < batch_size:
		var elapsed = Time.get_ticks_msec() - frame_timer
		if elapsed > max_frame_time_ms:
			logger.trace("Frame budget exceeded: %.2fms. Processed %d/%d expressions" % [
				elapsed, processed_count, initial_queue_size
			])
			break

		var expression_id = evaluation_queue.pop_front()
		logger.trace("Processing expression %s (priority: %d)" % [
			expression_id,
			_priorities.get(expression_id, default_priority)
		])

		evaluate_expression(expression_id)
		processed_count += 1

	if not evaluation_queue.is_empty():
		logger.trace("Evaluation cycle complete. Processed: %d, Remaining: %d, Elapsed: %.2fms" % [
			processed_count,
			evaluation_queue.size(),
			Time.get_ticks_msec() - frame_timer
		])
>>>>>>> parent of 1272e56 (Many updates - removed influence)

## Evaluate a specific expression (implemented in EvaluationSystem)
func evaluate_expression(_expression_id: String) -> void:
	pass  # Implementation in EvaluationSystem

## Get debug statistics
func get_stats() -> Dictionary:
	var stats := {
		"queue_size": evaluation_queue.size(),
		"registered_expressions": _priorities.size(),
		"high_priority_count": _priorities.values().count(HIGH_PRIORITY),
		"low_priority_count": _priorities.values().count(LOW_PRIORITY)
	}

	logger.trace("Current stats: %s" % str(stats))
	return stats
