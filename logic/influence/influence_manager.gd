class_name InfluenceManager
extends Node

var entity: Node
var position_changed: bool = false
var eval_system: EvaluationSystem
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
	var actual_distance = entity.rng.randfn(distance, 15)
	return entity.global_position + direction * actual_distance

func calculate_weighted_direction(influences: Array[Influence]) -> Vector2:
	var total_weight = 0.0
	var weighted_direction = Vector2.ZERO

	for influence in influences:
		var weight = eval_system.get_value(influence.weight)
		var dir = eval_system.get_value(influence.direction).normalized()
		total_weight += weight
		weighted_direction += dir * weight

	return weighted_direction if total_weight > 0 else Vector2.ZERO
