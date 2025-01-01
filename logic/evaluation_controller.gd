class_name EvaluationController
extends Node2D

#region Properties
## Batch size for processing evaluations per frame
@export var batch_size: int = 10

## Maximum time budget per frame (in milliseconds)
@export var max_frame_time_ms: float = 5.0

## Default evaluation priority (higher = evaluated sooner)
@export var default_priority: int = 0

## Priority constants
const HIGH_PRIORITY := 100
const NORMAL_PRIORITY := 0
const LOW_PRIORITY := -100

## Timer for tracking frame processing time
var _frame_timer: float = 0.0

## Queue of pending evaluations
var _evaluation_queue: Array[String] = []

## Map of expression IDs to their priorities
var _priorities: Dictionary = {}

## Track queued expression states
var _queued_states: Dictionary = {}

## Last evaluation timestamps
var _last_update_time: Dictionary = {}

## Minimum time between evaluations (in seconds)
const MIN_EVAL_INTERVAL := 0.016  # ~60fps

## Logger instance
var logger: Logger

## Signal when expression needs evaluation
signal expression_needs_evaluation(expression_id: String)
#endregion

class QueuedState:
	var last_queue_time: float = 0.0
	var priority: int = 0

	func _init(p_priority: int) -> void:
		priority = p_priority
		last_queue_time = Time.get_ticks_msec() / 1000.0

	func can_queue(current_time: float) -> bool:
		return current_time - last_queue_time >= MIN_EVAL_INTERVAL

	func update_queue_time(current_time: float) -> void:
		last_queue_time = current_time

#region Initialization
func _init() -> void:
	logger = Logger.new("eval_controller", DebugLogger.Category.LOGIC)
	logger.trace("EvaluationController initialized")
#endregion

#region Queue Management
## Register an expression with a specific evaluation priority
func register_expression(expression_id: String, priority: int = default_priority) -> void:
	_priorities[expression_id] = priority
	logger.trace("Registered expression %s with priority %d" % [expression_id, priority])

## Queue expression with high priority (immediate evaluation needed)
func queue_high_priority(expression_id: String) -> void:
	# Skip if already queued at same or higher priority
	if _queued_states.has(expression_id):
		var state = _queued_states[expression_id]
		if state.priority >= HIGH_PRIORITY:
			return

	_priorities[expression_id] = HIGH_PRIORITY
	_add_to_queue(expression_id)
	logger.trace("Queued high priority evaluation for %s" % expression_id)

## Queue expression with normal priority
func queue_normal_priority(expression_id: String) -> void:
	# Skip if already queued at a higher priority
	if _queued_states.has(expression_id):
		var state = _queued_states[expression_id]
		if state.priority >= NORMAL_PRIORITY:
			return

	_priorities[expression_id] = default_priority
	_add_to_queue(expression_id)
	logger.trace("Queued normal priority evaluation for %s" % expression_id)

## Queue expression with low priority (idle evaluation)
func queue_idle_priority(expression_id: String) -> void:
	# Skip if already queued at any higher priority
	if _queued_states.has(expression_id):
		var state = _queued_states[expression_id]
		if state.priority > LOW_PRIORITY:
			return

	_priorities[expression_id] = LOW_PRIORITY
	_add_to_queue(expression_id)
	logger.trace("Queued low priority evaluation for %s" % expression_id)

## Check if expression is already queued
func is_queued(expression_id: String) -> bool:
	return expression_id in _evaluation_queue

## Add expression to queue if not already present
func _add_to_queue(expression_id: String) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0

	# Get or create queued state
	if not _queued_states.has(expression_id):
		_queued_states[expression_id] = QueuedState.new(_priorities.get(expression_id, default_priority))

	var state = _queued_states[expression_id]
	if not state.can_queue(current_time):
		return

	if not is_queued(expression_id):
		_evaluation_queue.append(expression_id)
		state.update_queue_time(current_time)

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

	var current_time = Time.get_ticks_msec() / 1000.0
	_frame_timer = current_time
	var processed_count := 0
	var initial_queue_size := _evaluation_queue.size()

	logger.trace("Starting evaluation processing. Queue size: %d" % initial_queue_size)

	# Sort queue by priority (higher priority first)
	_evaluation_queue.sort_custom(func(a, b):
		return _priorities.get(a, default_priority) > _priorities.get(b, default_priority)
	)

	logger.trace("Queue sorted by priority")

	while not _evaluation_queue.is_empty() and processed_count < batch_size:
		var elapsed = Time.get_ticks_msec() - _frame_timer
		if elapsed > max_frame_time_ms:
			logger.trace("Frame budget exceeded: %.2fms. Processed %d/%d expressions" % [
				elapsed, processed_count, initial_queue_size
			])
			break

		var expression_id = _evaluation_queue.pop_front()
		var state = _queued_states.get(expression_id)
		if state and state.can_queue(current_time):
			_queued_states.erase(expression_id)  # Remove tracking state
			logger.trace("Processing expression %s (priority: %d)" % [
				expression_id,
				_priorities.get(expression_id, default_priority)
			])

			expression_needs_evaluation.emit(expression_id)
			processed_count += 1

	if not _evaluation_queue.is_empty():
		logger.trace("Evaluation cycle complete. Processed: %d, Remaining: %d, Elapsed: %.2fms" % [
			processed_count,
			_evaluation_queue.size(),
			Time.get_ticks_msec() - _frame_timer
		])
#endregion

#region Statistics
## Get debug statistics about the evaluation controller
func get_stats() -> Dictionary:
	var priority_counts := {
		"high": 0,
		"normal": 0,
		"low": 0
	}

	for priority in _priorities.values():
		match priority:
			HIGH_PRIORITY: priority_counts.high += 1
			NORMAL_PRIORITY: priority_counts.normal += 1
			LOW_PRIORITY: priority_counts.low += 1

	var stats := {
		"queue_size": _evaluation_queue.size(),
		"registered_expressions": _priorities.size(),
		"priority_distribution": priority_counts,
		"current_frame_time": Time.get_ticks_msec() - _frame_timer if _frame_timer > 0 else 0.0
	}

	logger.trace("Current stats: %s" % str(stats))
	return stats
#endregion
