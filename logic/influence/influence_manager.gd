class_name InfluenceManager
extends BaseComponent

#region Properties
## Active influences
var influences: Array[Influence] = []

## Heat map for tracking ant movement
var heat_map: ExplorationHeatMap

## State tracking
var _dirty: bool = true
var _total_influence: Influence
var _raw_total_weight: float = 0.0
var _total_direction: Vector2 = Vector2.ZERO

## The normalized total influence
var total_influence: Influence:
	get:
		if _dirty:
			_recalculate_total_influence()
		return _total_influence
#endregion

func _init() -> void:
	name = "influence_manager"
	heat_map = ExplorationHeatMap.new()

func _setup_dependencies(dependencies: Dictionary) -> void:
	if not entity is Ant:
		logger.error("Entity must be an Ant")
		return
		
	var eval_system = dependencies.get("evaluation_system", null)
	if not eval_system:
		return
	
func register_influences(move_action: Move, eval_system: EvaluationSystem) -> void:
	for expr in move_action.influences:
		eval_system.register_expression(expr.direction)
		eval_system.register_expression(expr.weight)

#region Public Methods
func recalculate_target_position() -> Vector2:
	if not entity is Ant:
		push_error("Entity reference is null or not an Ant")
		return Vector2.ZERO
		
	var total_vector: Vector2 = get_total_direction()
	return entity.global_position + total_vector * 50.0  # Fixed target distance

func get_total_direction() -> Vector2:
	if _dirty:
		_recalculate_total_influence()
	return _total_direction

func clear_influences() -> void:
	influences.clear()
	_dirty = true
#endregion

#region Helper Methods
func _recalculate_total_influence() -> void:
	_raw_total_weight = 0.0
	var weighted_direction = Vector2.ZERO
	
	for influence in influences:
		var weight = influence.weight.get_value()
		_raw_total_weight += weight
		weighted_direction += influence.direction.get_value() * weight
	
	_total_direction = weighted_direction.normalized() if weighted_direction.length() > 0 else Vector2.ZERO	
	_dirty = false

func get_forward_direction() -> Vector2:
	var ant_ref := entity as Ant
	var forward = ant_ref.velocity
	if forward == Vector2.ZERO:
		forward = Vector2.RIGHT.rotated(ant_ref.global_rotation)
	return forward.normalized()

func get_direction_to_colony() -> Vector2:
	var ant_ref := entity as Ant
	if not ant_ref.colony:
		return Vector2.ZERO
	return ant_ref.global_position.direction_to(ant_ref.colony.global_position)

func accumulate_pheromone_influence(moving_toward_colony: bool) -> Vector2:
	var ant_ref := entity as Ant
	var total_influence = Vector2.ZERO
	var pheromone_type = "home" if moving_toward_colony else "food"
	var pheromones = ant_ref.get_sensed_pheromones(pheromone_type)
	
	for pheromone in pheromones:
		var direction = ant_ref.direction_to(pheromone)
		var dot_product = direction.dot(get_direction_to_colony())
		var weight = (dot_product + 1.0) * 0.5 if moving_toward_colony else (1.0 - dot_product) * 0.5
		total_influence += direction * pheromone.concentration * weight
	
	return total_influence.normalized() if total_influence.length() > 0 else Vector2.ZERO

func accumulate_ant_influence(moving_toward_colony: bool) -> Vector2:
	var ant_ref := entity as Ant
	var total_influence = Vector2.ZERO
	var sighted_ants = ant_ref.get_sighted_ants(true)
	
	for other_ant in sighted_ants:
		if not (moving_toward_colony or other_ant.is_carrying_food()):
			continue
		var direction = other_ant.velocity.normalized()
		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT.rotated(other_ant.global_rotation)
		var multiplier = 1.0 if moving_toward_colony == other_ant.is_carrying_food() else -1.0
		total_influence += direction * multiplier
	
	return total_influence.normalized() if total_influence.length() > 0 else Vector2.ZERO
#endregion
