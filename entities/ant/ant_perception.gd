class_name AntPerception
extends RefCounted
## All spatial and sensor queries for one ant: area overlap queries, nearest-
## item searches, colony proximity, and pheromone sampling. Extracted from
## Ant so the entity script holds only vitals, movement, actions, and
## lifecycle — the same decomposition as PheromoneMemory and AntSenses.
##
## Layering (who is allowed to call what):
##   AntPerception — node-returning queries. CODE ONLY: actions, influences'
##                   engine glue, debug UI. Never reachable from expressions.
##   AntSenses     — value-type facade over this class. The ONLY object
##                   expressions evaluate against.
##
## Holds a plain reference to the ant (not weak): the ant owns its perception
## and frees it by dropping the reference, so no cycle-through-Node exists.
## Every query guards on the ant being inside the tree, since area overlap
## results are meaningless (and error-prone) outside it.

var _ant: Ant

## Per-pheromone sample history used for gradient following.
## Owned here because sampling is what populates it.
var pheromone_memories: Dictionary[String, PheromoneMemory] = {}


func _init(p_ant: Ant) -> void:
	_ant = p_ant


#region Area queries
func _get_in_reach(predicate: Callable) -> Array:
	if not _ant.is_inside_tree() or not is_instance_valid(_ant.reach_area):
		return []
	return _ant.reach_area.get_overlapping_bodies().filter(predicate)


func _get_in_view(predicate: Callable) -> Array:
	if not _ant.is_inside_tree() or not is_instance_valid(_ant.sight_area):
		return []
	return _ant.sight_area.get_overlapping_bodies().filter(predicate)


func get_food_in_view() -> Array:
	return _get_in_view(func(n): return n is Food and n.is_available)


func get_food_in_reach() -> Array:
	return _get_in_reach(func(n): return n is Food and n.is_available)


func get_ants_in_view() -> Array:
	return _get_in_view(func(n): return n is Ant and n != _ant)


func get_colonies_in_view() -> Array:
	return _get_in_view(func(n): return n is Colony)


func get_colonies_in_reach() -> Array:
	return _get_in_reach(func(n): return n is Colony)
#endregion


#region Nearest / filtering
## Nearest available food within reach, or null.
func get_nearest_food_in_reach() -> Food:
	return get_nearest_item(get_food_in_reach()) as Food


## Nearest non-null item in `list` by distance to this ant, or null.
func get_nearest_item(list: Array) -> Variant:
	var nearest: Variant = null
	var min_distance: float = INF
	for item: Variant in list:
		if item == null:
			continue
		var distance: float = _ant.global_position.distance_to(item.global_position)
		if distance < min_distance:
			min_distance = distance
			nearest = item
	return nearest


func filter_friendly_ants(ants_arr: Array, friendly: bool = true) -> Array:
	return ants_arr.filter(func(ant): return friendly == (ant.colony == _ant.colony))
#endregion


#region Colony proximity
func is_colony_in_range() -> bool:
	if not is_instance_valid(_ant.colony):
		return false
	return _distance_to_colony() < _ant.colony.radius


func is_colony_in_sight() -> bool:
	if not is_instance_valid(_ant.colony):
		return false
	if not _ant.is_inside_tree() or not is_instance_valid(_ant.sight_area):
		return false
	var sight_shape: CollisionShape2D = _ant.sight_area.get_node("CollisionShape2D")
	var gap_to_colony_edge: float = _distance_to_colony() - _ant.colony.radius
	return gap_to_colony_edge < sight_shape.shape.radius


func _distance_to_colony() -> float:
	return _ant.colony.global_position.distance_to(_ant.global_position)
#endregion


#region Pheromone sensing
func get_pheromone_concentration(pheromone_name: String) -> float:
	return HeatmapManager.get_heat_at_position(_ant, pheromone_name)


## Samples heat at the current cell and accumulates a per-pheromone memory,
## returning the gradient direction (toward higher concentration by default).
## The memory write is sensor-internal state, not world mutation, which is
## why this is legal to reach from AntSenses.
func get_pheromone_direction(pheromone_name: String, follow_concentration: bool = true) -> Vector2:
	if not is_instance_valid(_ant.colony):
		return Vector2.ZERO

	if not pheromone_memories.has(pheromone_name):
		pheromone_memories[pheromone_name] = PheromoneMemory.new()

	var current_cell: Vector2i = HeatmapManager.world_to_cell(_ant.global_position)
	var current_concentration: float = HeatmapManager.get_heat_at_position(_ant, pheromone_name)
	pheromone_memories[pheromone_name].add_sample(current_cell, current_concentration)

	var direction: Vector2 = pheromone_memories[pheromone_name].get_concentration_vector()
	return direction if follow_concentration else -direction
#endregion
