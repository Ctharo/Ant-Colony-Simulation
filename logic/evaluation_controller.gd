class_name EvaluationController
extends Node2D
@warning_ignore("unused_signal")
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

## Process queued evaluations within time and batch constraints
func process_evaluations() -> void:
	if evaluation_queue.is_empty():
		return

	frame_timer = Time.get_ticks_msec()
	var processed_count := 0
	var initial_queue_size := evaluation_queue.size()

	logger.trace("Starting evaluation processing. Queue size: %d" % initial_queue_size)

	# Sort queue by priority (higher priority first)
	evaluation_queue.sort_custom(func(a, b):
		return _priorities.get(a, default_priority) > _priorities.get(b, default_priority)
	)

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
