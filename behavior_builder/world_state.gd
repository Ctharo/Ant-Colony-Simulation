class_name BBWorldState
extends RefCounted
## Mutable world snapshot the graph evaluates against.
## The side-panel sliders write into this; every change re-evaluates the graph.
##
## Fields are grouped: "ant" values live on the ant itself (vitals, carried
## mass, its max stats), "world" values are things the ant senses around it.
## The two groups get separate value-reader nodes and separate slider sections.
##
## LISTS: the state also holds mock SENSED ENTITIES — plain Dictionaries of
## value types only (mirroring the AntSenses safety rule: no Nodes ever flow
## through the graph). The 👁 SENSE node reads these via get_list(); the
## side panel can reroll them. An in-game adapter only needs to implement
## get_value(key) -> float and get_list(source) -> Array[Dictionary] built
## from AntPerception results, and authored graphs run unchanged.

signal changed(key: String, value: float)
signal entities_changed

const FIELDS: Array[Dictionary] = [
	# ---- world (sensed surroundings)
	{"key": "food_dist",     "label": "Food distance",        "group": "world", "min": 0.0,    "max": 100.0, "default": 50.0,  "step": 1.0},
	{"key": "enemy_dist",    "label": "Enemy distance",       "group": "world", "min": 0.0,    "max": 100.0, "default": 80.0,  "step": 1.0},
	{"key": "friend_dist",   "label": "Friend distance",      "group": "world", "min": 0.0,    "max": 100.0, "default": 20.0,  "step": 1.0},
	{"key": "colony_dist",   "label": "Colony distance",      "group": "world", "min": 0.0,    "max": 100.0, "default": 30.0,  "step": 1.0},
	{"key": "food_pher",     "label": "Food pheromone conc.", "group": "world", "min": 0.0,    "max": 1.0,   "default": 0.2,   "step": 0.01},
	{"key": "food_pher_dir", "label": "Food pheromone dir °", "group": "world", "min": -180.0, "max": 180.0, "default": 0.0,   "step": 1.0},
	{"key": "home_pher",     "label": "Home pheromone conc.", "group": "world", "min": 0.0,    "max": 1.0,   "default": 0.5,   "step": 0.01},
	{"key": "home_pher_dir", "label": "Home pheromone dir °", "group": "world", "min": -180.0, "max": 180.0, "default": 0.0,   "step": 1.0},

	# ---- ant (own body & vitals; max stats enable derived expressions
	#      like "health percentage" = health / max_health * 100)
	{"key": "health",        "label": "Health",               "group": "ant",   "min": 0.0,    "max": 200.0, "default": 100.0, "step": 1.0},
	{"key": "max_health",    "label": "Max health",           "group": "ant",   "min": 1.0,    "max": 200.0, "default": 100.0, "step": 1.0},
	{"key": "energy",        "label": "Energy",               "group": "ant",   "min": 0.0,    "max": 200.0, "default": 100.0, "step": 1.0},
	{"key": "max_energy",    "label": "Max energy",           "group": "ant",   "min": 1.0,    "max": 200.0, "default": 100.0, "step": 1.0},
	{"key": "carried_mass",  "label": "Carried mass",         "group": "ant",   "min": 0.0,    "max": 10.0,  "default": 0.0,   "step": 0.1},
]

## Sources the 👁 SENSE node can read. Mirrors AntPerception's query surface.
const LIST_SOURCES: Array[Dictionary] = [
	{"key": "ants_in_view", "label": "Vision: ants"},
	{"key": "food_in_view", "label": "Vision: food"},
	{"key": "food_in_reach", "label": "Reach: food"},
]

## Per-item properties readable by FILTER / SORT / ITEM VALUE nodes.
## "type" decides which UI a node shows ("float" → op + number, "bool" →
## is TRUE / is FALSE). Items missing a property simply fail filters and
## sort last — that is how "health" behaves on food, for example.
const ITEM_PROPS: Array[Dictionary] = [
	{"key": "distance",     "label": "distance",            "type": "float"},
	{"key": "angle_deg",    "label": "direction (°)",       "type": "float"},
	{"key": "health",       "label": "health (ants)",       "type": "float"},
	{"key": "amount",       "label": "amount (food)",       "type": "float"},
	{"key": "is_ally",      "label": "is ally (ants)",      "type": "bool"},
	{"key": "carrying",     "label": "is carrying (ants)",  "type": "bool"},
	{"key": "is_available", "label": "is available (food)", "type": "bool"},
]

## Mirrors the calibrated mouth-reach radius, scaled to slider units.
const REACH_DISTANCE: float = 12.0

var values: Dictionary = {}
var mock_ants: Array[Dictionary] = []
var mock_food: Array[Dictionary] = []
var ant_count: int = 6
var food_count: int = 5

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	for f: Dictionary in FIELDS:
		values[f.key] = f.default
	_rng.randomize()
	reroll_entities()


# ------------------------------------------------------------ scalar fields

static func fields_in_group(group: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f: Dictionary in FIELDS:
		if str(f.get("group", "world")) == group:
			out.append(f)
	return out


static func group_of(key: String) -> String:
	for f: Dictionary in FIELDS:
		if str(f.key) == key:
			return str(f.get("group", "world"))
	return "world"


func set_value(key: String, v: float) -> void:
	if values.get(key) != v:
		values[key] = v
		changed.emit(key, v)


func get_value(key: String) -> float:
	return float(values.get(key, 0.0))


# ------------------------------------------------------------- mock entities

## Regenerates the sensed-entity lists (new random ants and food).
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
			"health": snappedf(_rng.randf_range(10.0, 100.0), 1.0),
			"carrying": _rng.randf() < 0.2,
		})
	for i: int in food_count:
		mock_food.append({
			"kind": "food",
			"id": i,
			"distance": snappedf(_rng.randf_range(3.0, 100.0), 0.1),
			"angle_deg": snappedf(_rng.randf_range(-180.0, 180.0), 1.0),
			"amount": snappedf(_rng.randf_range(1.0, 10.0), 0.5),
			"is_available": _rng.randf() < 0.9,
		})
	entities_changed.emit()


func set_entity_counts(p_ant_count: int, p_food_count: int) -> void:
	ant_count = maxi(p_ant_count, 0)
	food_count = maxi(p_food_count, 0)
	reroll_entities()


## The 👁 SENSE node's data source. Returned lists are copies, so downstream
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


static func prop_type(key: String) -> String:
	for p: Dictionary in ITEM_PROPS:
		if str(p.key) == key:
			return str(p.get("type", "float"))
	return "float"


func snapshot() -> Dictionary:
	return {
		"values": values.duplicate(),
		"ants": mock_ants.duplicate(true),
		"food": mock_food.duplicate(true),
	}
