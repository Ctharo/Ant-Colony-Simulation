class_name InfluenceManager
extends Node

## The entity this influence manager is attached to
var entity: Node

## Flag to track if position has changed
var position_changed: bool = false

## Reference to the evaluation system
var eval_system: EvaluationSystem

## Logger instance for debugging
var logger: Logger

func _init() -> void:
	name = "influence_manager"
	logger = Logger.new(name, DebugLogger.Category.INFLUENCE)

func initialize(p_entity: Node, p_eval_system: EvaluationSystem) -> void:
	entity = p_entity
	eval_system = p_eval_system

func register_influences(move_action: Move) -> void:
	for influence in move_action.influences:
		eval_system.register_expression(influence.direction)
		eval_system.register_expression(influence.weight)

func calculate_target_position(distance: float, influences: Array[Influence]) -> Vector2:
	var direction = calculate_weighted_direction(influences)
	var actual_distance = entity.rng.randfn(distance, distance * 0.33) # deviation from distance
	return entity.global_position + direction * actual_distance

func calculate_weighted_direction(influences: Array[Influence]) -> Vector2:
	var total_weight = 0.0
	var weighted_direction = Vector2.ZERO
	var evaluated_influences = []

	# First pass: evaluate all influences and calculate total weight
	for influence in influences:
		var weight = eval_system.get_value(influence.weight)
		var dir = eval_system.get_value(influence.direction).normalized()

		# Store evaluated values for second pass
		evaluated_influences.append({
			"id": influence.id,
			"weight": weight,
			"direction": dir
		})
		total_weight += weight

	# Second pass: normalize weights and calculate final direction
	if total_weight > 0:
		for eval_influence in evaluated_influences:
			# Normalize weight by dividing by total
			var normalized_weight = eval_influence.weight / total_weight
			weighted_direction += eval_influence.direction * normalized_weight

			logger.trace("Influence %s evaluated: Original Weight: %s, Normalized Weight: %s, Direction: %s" %
				[eval_influence.id, str(eval_influence.weight), str(normalized_weight), str(eval_influence.direction)])

	return weighted_direction
