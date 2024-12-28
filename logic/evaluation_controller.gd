class_name EvaluationController
extends Node2D

#region Properties
## Batch size for processing evaluations per frame
@export var batch_size: int = 10
## Maximum time budget per frame (in milliseconds)
@export var max_frame_time_ms: float = 5.0
## Default evaluation priority (higher = evaluated sooner)
@export var default_priority: int = 0
## Timer for tracking frame processing time
var _frame_timer: float = 0.0
## Queue of pending evaluations
var _evaluation_queue: Array = []
## Map of expression IDs to their priorities
var _priorities: Dictionary = {}
## Logger instance
var logger: Logger
#endregion

func _init() -> void:
	logger = Logger.new("eval_controller", DebugLogger.Category.LOGIC)

## Register an expression with a specific evaluation priority
func register_expression(expression_id: String, priority: int = default_priority) -> void:
	_priorities[expression_id] = priority

## Queue an expression for evaluation
func queue_evaluation(expression_id: String) -> void:
	if expression_id not in _evaluation_queue:
		_evaluation_queue.append(expression_id)

## Process queued evaluations within time and batch constraints
func process_evaluations() -> void:
	if _evaluation_queue.is_empty():
		return

	_frame_timer = Time.get_ticks_msec()
	var processed_count := 0

	# Sort queue by priority
	_evaluation_queue.sort_custom(func(a, b):
		return _priorities.get(a, default_priority) > _priorities.get(b, default_priority)
	)

	while not _evaluation_queue.is_empty() and processed_count < batch_size:
		var elapsed = Time.get_ticks_msec() - _frame_timer
		if elapsed > max_frame_time_ms:
			if logger.is_debug_enabled():
				logger.debug("Frame budget exceeded: %.2fms" % elapsed)
			break

		var expression_id = _evaluation_queue.pop_front()
		# This would call back to EvaluationSystem
		evaluate_expression(expression_id)
		processed_count += 1

	if not _evaluation_queue.is_empty() and logger.is_debug_enabled():
		logger.debug("Deferred %d evaluations" % _evaluation_queue.size())

## Evaluate a specific expression (implemented in EvaluationSystem)
func evaluate_expression(_expression_id: String) -> void:
	pass  # Implementation in EvaluationSystem

## Get debug statistics
func get_stats() -> Dictionary:
	return {
		"queue_size": _evaluation_queue.size(),
		"registered_expressions": _priorities.size()
	}
