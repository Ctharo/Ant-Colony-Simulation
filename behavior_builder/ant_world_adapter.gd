class_name AntWorldAdapter
extends RefCounted
## Live-world implementation of the behavior-graph read surface: the
## in-game counterpart to BBWorldState's slider mock. BBEval evaluates
## graphs against this object when they run on a real ant (GraphLogic,
## Batch B) and when the designer previews against the probe ant (Batch C).
##
## CONTRACT (duck-typed, shared with BBWorldState — BBEval cannot tell
## the two apart):
##   get_value(key: String) -> float
##   get_list(source: String) -> Array[Dictionary]
##   snapshot() -> Dictionary
##
## SAFETY: this class is the graph runtime's equivalent of AntSenses — the
## only object UI-authored graph data evaluates against. Every return is a
## VALUE TYPE: floats from get_value, Dictionaries of value types from
## get_list. It reads AntPerception internally (legal — this is Tier-0
## engine glue, the same standing AntSenses has), but no Node, Resource,
## or other reference type ever crosses the boundary.
##
## UNKNOWN SEMANTICS: distances degrade to INF when nothing qualifies
## (the AntSenses Vector2.INF convention — "< 50" simply reads false);
## counts degrade to 0; a freed or dead ant reads neutral values. BBEval's
## null-unknown never originates here: get_value is total over the
## vocabulary. Unknown keys return 0.0 WITHOUT logging — BBGraphValidator
## is the detecting gate for those (log once at source), and by the time a
## graph evaluates it has passed validation.
##
## Keep get_value()'s key mapping in lockstep with BBVocabulary.FIELDS.

var _ant: Ant


func _init(p_ant: Ant) -> void:
	_ant = p_ant


## True while the wrapped ant is a usable read source.
func is_alive() -> bool:
	return is_instance_valid(_ant) and not _ant.is_dead


#region Contract: scalars
func get_value(key: String) -> float:
	if not is_alive():
		return _neutral_value(key)

	if key.begins_with(BBVocabulary.PHER_CONC_PREFIX):
		var conc_name: String = key.trim_prefix(BBVocabulary.PHER_CONC_PREFIX)
		return _ant.perception.get_pheromone_concentration(conc_name)
	if key.begins_with(BBVocabulary.PHER_DIR_PREFIX):
		var dir_name: String = key.trim_prefix(BBVocabulary.PHER_DIR_PREFIX)
		var gradient: Vector2 = _ant.perception.get_pheromone_direction(dir_name)
		return rad_to_deg(gradient.angle()) if gradient != Vector2.ZERO else 0.0

	match key:
		"health":
			return _ant.health_level
		"max_health":
			return Ant.HEALTH_MAX
		"energy":
			return _ant.energy_level
		"max_energy":
			return Ant.ENERGY_MAX
		"carrying_food":
			return 1.0 if _ant.is_carrying_food else 0.0
		"is_resting":
			return 1.0 if _ant.is_resting else 0.0
		"speed":
			return _ant.velocity.length()
		"movement_rate":
			return _ant.movement_rate
		"vision_range":
			return _ant.vision_range
		"food_dist":
			return _nearest_distance(_ant.perception.get_food_in_view())
		"food_reach_dist":
			return _nearest_distance(_ant.perception.get_food_in_reach())
		"food_in_view":
			return float(_ant.perception.get_food_in_view().size())
		"colony_dist":
			return _colony_distance()
		"in_colony":
			return 1.0 if _ant.perception.is_colony_in_range() else 0.0
		"ants_in_view":
			return float(_ant.perception.get_ants_in_view().size())
		"allies_in_view":
			return float(_ants_split(true).size())
		"enemies_in_view":
			return float(_ants_split(false).size())
		"enemy_dist":
			return _nearest_distance(_ants_split(false))
		"ally_dist":
			return _nearest_distance(_ants_split(true))
	return 0.0  # unknown key: validator's job, not runtime's (see class docs)
#endregion


#region Contract: lists
## Sensed entities flattened to Dictionaries of value types only — the
## AntSenses safety rule. Copies by construction; downstream sort/filter
## nodes can never mutate world state.
func get_list(source: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not is_alive():
		return out
	match source:
		"ants_in_view":
			for other: Ant in _ant.perception.get_ants_in_view():
				out.append(_flatten_ant(other))
		"food_in_view":
			for food: Food in _ant.perception.get_food_in_view():
				out.append(_flatten_food(food))
		"food_in_reach":
			for food: Food in _ant.perception.get_food_in_reach():
				out.append(_flatten_food(food))
	return out
#endregion


#region Contract: snapshot
## Debug-JSON support (the ⧉ copy includes a world snapshot). Same shape as
## BBWorldState.snapshot().
func snapshot() -> Dictionary:
	var field_values: Dictionary = {}
	for field: Dictionary in BBVocabulary.all_fields():
		var key: String = str(field.key)
		field_values[key] = get_value(key)
	return {
		"values": field_values,
		"ants": get_list("ants_in_view"),
		"food": get_list("food_in_view"),
	}
#endregion


#region Internals
func _flatten_ant(other: Ant) -> Dictionary:
	var offset: Vector2 = other.global_position - _ant.global_position
	return {
		"kind": "ant",
		"id": other.id,
		"distance": offset.length(),
		"angle_deg": rad_to_deg(offset.angle()),
		"is_ally": is_instance_valid(_ant.colony) and other.colony == _ant.colony,
		"health": other.health_level,
		"carrying": other.is_carrying_food,
	}


func _flatten_food(food: Food) -> Dictionary:
	var offset: Vector2 = food.global_position - _ant.global_position
	return {
		"kind": "food",
		"id": food.get_instance_id(),
		"distance": offset.length(),
		"angle_deg": rad_to_deg(offset.angle()),
		"size": food.get_size(),
		"is_available": food.is_available,
	}


## Allies (friendly = true) or enemies (false) among ants in view.
func _ants_split(friendly: bool) -> Array:
	return _ant.perception.filter_friendly_ants(
		_ant.perception.get_ants_in_view(), friendly)


## Distance to the nearest item in `items`, or INF when empty — reuses
## AntPerception's nearest search so tie-breaking matches AntSenses.
func _nearest_distance(items: Array) -> float:
	var nearest: Variant = _ant.perception.get_nearest_item(items)
	if nearest is Node2D and is_instance_valid(nearest):
		return _ant.global_position.distance_to((nearest as Node2D).global_position)
	return INF


func _colony_distance() -> float:
	if not is_instance_valid(_ant.colony):
		return INF
	return _ant.global_position.distance_to(_ant.colony.global_position)


## Values a freed/dead ant reads as: INF for distances (nothing qualifies),
## 0 for everything else.
func _neutral_value(key: String) -> float:
	return INF if key.ends_with("_dist") else 0.0
#endregion
