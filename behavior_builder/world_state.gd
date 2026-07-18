class_name BBWorldState
extends RefCounted
## Slider-backed MOCK world for authoring graphs without a live ant (the
## Behavior Designer already works sandbox-less; this is the graph editor's
## equivalent). Implements the same duck-typed contract as AntWorldAdapter
## — get_value / get_list / snapshot — so BBEval cannot tell them apart.
##
## The vocabulary itself lives in BBVocabulary (single source of truth,
## shared with AntWorldAdapter and BBGraphValidator); this class only adds
## slider storage and mock sensed-entity lists. FIELDS / LIST_SOURCES /
## ITEM_PROPS and the static helpers below are thin delegates kept so the
## existing node scripts (world_value_node, filter_node, ...) compile
## unchanged in Batch A.
##
## CLEAN BREAK (confirmed): keys are the live-simulation vocabulary, not
## the old prototype mocks. Prototype graphs saved against enemy_dist /
## food_pher / amount fail BBGraphValidator and must be re-authored.
##
## Pheromone fields are DYNAMIC (enumerated from ResourceLibrary at
## construction): values for them are seeded here too, so get_value() is
## total over the vocabulary. Pheromones added after this state was
## created read their fallback 0.0 until a new state is built.

signal changed(key: String, value: float)
signal entities_changed

## Delegates — see class docs. Node scripts reference these by name.
const FIELDS: Array[Dictionary] = BBVocabulary.FIELDS
const LIST_SOURCES: Array[Dictionary] = BBVocabulary.LIST_SOURCES
const ITEM_PROPS: Array[Dictionary] = BBVocabulary.ITEM_PROPS

## Mirrors the calibrated mouth-reach radius (world px).
const REACH_DISTANCE: float = 12.0

var values: Dictionary = {}
var mock_ants: Array[Dictionary] = []
var mock_food: Array[Dictionary] = []
var ant_count: int = 6
var food_count: int = 5

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	for field: Dictionary in BBVocabulary.all_fields():
		values[str(field.key)] = float(field.default)
	_rng.randomize()
	reroll_entities()


# ------------------------------------------------------------ scalar fields

## Delegate: includes dynamic pheromone fields (see BBVocabulary).
static func fields_in_group(group: String) -> Array[Dictionary]:
	return BBVocabulary.fields_in_group(group)


static func group_of(key: String) -> String:
	return BBVocabulary.group_of(key)


static func prop_type(key: String) -> String:
	return BBVocabulary.prop_type(key)


func set_value(key: String, v: float) -> void:
	if values.get(key) != v:
		values[key] = v
		changed.emit(key, v)


func get_value(key: String) -> float:
	return float(values.get(key, 0.0))


# ------------------------------------------------------------- mock entities

## Regenerates the sensed-entity lists (new random ants and food).
## Item shapes mirror AntWorldAdapter._flatten_ant/_flatten_food exactly —
## keep the two in lockstep so authored graphs behave identically against
## mock and live worlds.
func reroll_entities() -> void:
	mock_ants.clear()
	mock_food.clear()
	for i: int in ant_count:
		mock_ants.append({
			"kind": "ant",
			"id": i,
			"distance": snappedf(_rng.randf_range(4.0, 100.0), 0.1),
			"angle_deg": snappedf(_rng.randf_range(-180.0, 180.0), 1.0),
			"is_ally": _rng.randf() < 0.6,
			"health": snappedf(_rng.randf_range(10.0, Ant.HEALTH_MAX), 1.0),
			"carrying": _rng.randf() < 0.2,
		})
	for i: int in food_count:
		mock_food.append({
			"kind": "food",
			"id": i,
			"distance": snappedf(_rng.randf_range(3.0, 100.0), 0.1),
			"angle_deg": snappedf(_rng.randf_range(-180.0, 180.0), 1.0),
			"size": snappedf(_rng.randf_range(2.0, 8.0), 0.5),
			"is_available": _rng.randf() < 0.9,
		})
	entities_changed.emit()


func set_entity_counts(p_ant_count: int, p_food_count: int) -> void:
	ant_count = maxi(p_ant_count, 0)
	food_count = maxi(p_food_count, 0)
	reroll_entities()


## The SENSE node's data source. Returned lists are copies, so downstream
## sort/filter nodes can never mutate the state.
func get_list(source: String) -> Array[Dictionary]:
	match source:
		"ants_in_view":
			return mock_ants.duplicate()
		"food_in_view":
			return mock_food.duplicate()
		"food_in_reach":
			var out: Array[Dictionary] = []
			for item: Dictionary in mock_food:
				if float(item.get("distance", INF)) <= REACH_DISTANCE:
					out.append(item)
			return out
	var empty: Array[Dictionary] = []
	return empty


func snapshot() -> Dictionary:
	return {
		"values": values.duplicate(),
		"ants": mock_ants.duplicate(true),
		"food": mock_food.duplicate(true),
	}
