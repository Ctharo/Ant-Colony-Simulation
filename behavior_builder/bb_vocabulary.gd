class_name BBVocabulary
extends RefCounted
## Single source of truth for the behavior-graph vocabulary (Batch A of the
## graph-editor integration): the scalar world keys, list sources, and
## per-item properties a graph node may reference.
##
## THREE consumers read this vocabulary, and all three read it from here so
## they cannot drift:
##   - BBWorldState      (slider mock — authoring without a live ant)
##   - AntWorldAdapter   (live ant — the in-game world implementation)
##   - BBGraphValidator  (closed-whitelist validation; LogicValidator's
##                        analogue for graph data)
##
## MEMBERSHIP RULE (mirrors AntSenses): a key belongs here iff it reads as
## a VALUE TYPE and requires engine/spatial state to produce. Anything
## derivable from these keys belongs in the graph itself (math nodes) or
## in a saved reusable value.
##
## DYNAMIC PHEROMONE KEYS: pheromones are user-editable resources
## (ResourceLibrary KIND_PHEROMONE), so their keys cannot be const. They
## are generated from the live catalog as "pher_conc:<name>" and
## "pher_dir_deg:<name>" — the pheromone NAME doubles as the heatmap key
## (see Pheromone class docs). Renaming a pheromone therefore invalidates
## graphs referencing the old key, exactly as it already breaks
## pheromone_direction("...") expressions; BBGraphValidator reports it.
##
## CLEAN BREAK (confirmed): keys match the live simulation, not the old
## prototype mocks (enemy_dist ranges, food_pher, amount, ...). Prototype
## graphs in user://behavior_conditions.json fail validation and must be
## re-authored. Distances are in world pixels; "0/1" fields are booleans
## surfaced as floats because world-value ports carry floats.

const GROUP_ANT: String = "ant"
const GROUP_WORLD: String = "world"

## Static scalar vocabulary. Slider metadata (min/max/default/step) drives
## the mock side panel; "doc" feeds tooltips. Runtime mapping for every key
## lives in AntWorldAdapter.get_value() — keep the two in lockstep.
const FIELDS: Array[Dictionary] = [
	# ---- ant (own body & vitals)
	{"key": "health", "label": "Health", "group": GROUP_ANT,
		"min": 0.0, "max": Ant.HEALTH_MAX, "default": Ant.HEALTH_MAX, "step": 1.0,
		"doc": "Current health, 0..max_health."},
	{"key": "max_health", "label": "Max health", "group": GROUP_ANT,
		"min": 1.0, "max": Ant.HEALTH_MAX, "default": Ant.HEALTH_MAX, "step": 1.0,
		"doc": "Health ceiling (constant in-game; a slider here for testing % math)."},
	{"key": "energy", "label": "Energy", "group": GROUP_ANT,
		"min": 0.0, "max": Ant.ENERGY_MAX, "default": Ant.ENERGY_MAX, "step": 1.0,
		"doc": "Current energy, 0..max_energy."},
	{"key": "max_energy", "label": "Max energy", "group": GROUP_ANT,
		"min": 1.0, "max": Ant.ENERGY_MAX, "default": Ant.ENERGY_MAX, "step": 1.0,
		"doc": "Energy ceiling (constant in-game)."},
	{"key": "carrying_food", "label": "Carrying food (0/1)", "group": GROUP_ANT,
		"min": 0.0, "max": 1.0, "default": 0.0, "step": 1.0,
		"doc": "1 while carrying a food item, else 0."},
	{"key": "is_resting", "label": "Resting (0/1)", "group": GROUP_ANT,
		"min": 0.0, "max": 1.0, "default": 0.0, "step": 1.0,
		"doc": "1 while rest_until_full() is in progress, else 0."},
	{"key": "speed", "label": "Speed (px/s)", "group": GROUP_ANT,
		"min": 0.0, "max": 100.0, "default": 0.0, "step": 1.0,
		"doc": "Current velocity magnitude."},
	{"key": "movement_rate", "label": "Movement rate", "group": GROUP_ANT,
		"min": 0.0, "max": 100.0, "default": 25.0, "step": 1.0,
		"doc": "Profile movement rate."},
	{"key": "vision_range", "label": "Vision range (px)", "group": GROUP_ANT,
		"min": 10.0, "max": 300.0, "default": 100.0, "step": 1.0,
		"doc": "Sight-area radius."},

	# ---- world (sensed surroundings)
	{"key": "food_dist", "label": "Nearest food distance (view)", "group": GROUP_WORLD,
		"min": 0.0, "max": 400.0, "default": 200.0, "step": 1.0,
		"doc": "Distance to the nearest visible food; INF when none is visible (comparisons degrade safely)."},
	{"key": "food_reach_dist", "label": "Nearest food distance (reach)", "group": GROUP_WORLD,
		"min": 0.0, "max": 50.0, "default": 30.0, "step": 1.0,
		"doc": "Distance to the nearest reachable food; INF when none."},
	{"key": "food_in_view", "label": "Food in view (count)", "group": GROUP_WORLD,
		"min": 0.0, "max": 20.0, "default": 0.0, "step": 1.0,
		"doc": "Available food items inside the sight area."},
	{"key": "colony_dist", "label": "Colony distance", "group": GROUP_WORLD,
		"min": 0.0, "max": 600.0, "default": 100.0, "step": 1.0,
		"doc": "Distance to own colony center; INF when the ant has no colony."},
	{"key": "in_colony", "label": "Inside colony (0/1)", "group": GROUP_WORLD,
		"min": 0.0, "max": 1.0, "default": 0.0, "step": 1.0,
		"doc": "1 while inside the colony radius, else 0."},
	{"key": "ants_in_view", "label": "Ants in view (count)", "group": GROUP_WORLD,
		"min": 0.0, "max": 30.0, "default": 0.0, "step": 1.0,
		"doc": "All other ants inside the sight area."},
	{"key": "allies_in_view", "label": "Allies in view (count)", "group": GROUP_WORLD,
		"min": 0.0, "max": 30.0, "default": 0.0, "step": 1.0,
		"doc": "Same-colony ants inside the sight area."},
	{"key": "enemies_in_view", "label": "Enemies in view (count)", "group": GROUP_WORLD,
		"min": 0.0, "max": 30.0, "default": 0.0, "step": 1.0,
		"doc": "Foreign-colony ants inside the sight area."},
	{"key": "enemy_dist", "label": "Nearest enemy distance", "group": GROUP_WORLD,
		"min": 0.0, "max": 400.0, "default": 300.0, "step": 1.0,
		"doc": "Distance to the nearest visible enemy ant; INF when none."},
	{"key": "ally_dist", "label": "Nearest ally distance", "group": GROUP_WORLD,
		"min": 0.0, "max": 400.0, "default": 50.0, "step": 1.0,
		"doc": "Distance to the nearest visible ally ant; INF when none."},
]

## Sources the SENSE (list) node can read. Mirrors AntPerception's query
## surface; AntWorldAdapter flattens the results to value-type Dictionaries.
const LIST_SOURCES: Array[Dictionary] = [
	{"key": "ants_in_view", "label": "Vision: ants"},
	{"key": "food_in_view", "label": "Vision: food"},
	{"key": "food_in_reach", "label": "Reach: food"},
]

## Per-item properties readable by FILTER / SORT / ITEM VALUE nodes.
## "type" decides which UI a node shows ("float" → op + number, "bool" →
## is TRUE / is FALSE). Items missing a property simply fail filters and
## sort last — that is how "health" behaves on food, for example.
## CLEAN BREAK: "size" (Food.get_size(), collision radius) replaces the
## prototype's "amount" — Food has no amount property.
const ITEM_PROPS: Array[Dictionary] = [
	{"key": "distance", "label": "distance", "type": "float"},
	{"key": "angle_deg", "label": "direction (°)", "type": "float"},
	{"key": "health", "label": "health (ants)", "type": "float"},
	{"key": "size", "label": "size (food)", "type": "float"},
	{"key": "is_ally", "label": "is ally (ants)", "type": "bool"},
	{"key": "carrying", "label": "is carrying (ants)", "type": "bool"},
	{"key": "is_available", "label": "is available (food)", "type": "bool"},
]

const PHER_CONC_PREFIX: String = "pher_conc:"
const PHER_DIR_PREFIX: String = "pher_dir_deg:"


## Dynamic pheromone fields for the CURRENT ResourceLibrary catalog. Called
## per catalog build (dropdown population, validation), never cached here —
## the catalog is the cache.
static func pheromone_fields() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: ResourceLibrary.Entry in ResourceLibrary.get_entries(ResourceLibrary.KIND_PHEROMONE):
		var pheromone: Pheromone = entry.resource as Pheromone
		if pheromone == null or pheromone.name.is_empty():
			continue
		out.append({
			"key": "%s%s" % [PHER_CONC_PREFIX, pheromone.name],
			"label": "%s pheromone conc." % pheromone.name.capitalize(),
			"group": GROUP_WORLD,
			"min": 0.0, "max": 50.0, "default": 0.0, "step": 0.1,
			"doc": "Raw heat at the ant's cell for the '%s' pheromone (HeatmapManager units)." % pheromone.name,
		})
		out.append({
			"key": "%s%s" % [PHER_DIR_PREFIX, pheromone.name],
			"label": "%s pheromone dir °" % pheromone.name.capitalize(),
			"group": GROUP_WORLD,
			"min": -180.0, "max": 180.0, "default": 0.0, "step": 1.0,
			"doc": "World-space gradient direction of '%s' in degrees (-180..180); reads 0 until enough samples form a gradient." % pheromone.name,
		})
	return out


## Static core plus the dynamic pheromone fields.
static func all_fields() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append_array(FIELDS)
	out.append_array(pheromone_fields())
	return out


static func fields_in_group(group: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for field: Dictionary in all_fields():
		if str(field.get("group", GROUP_WORLD)) == group:
			out.append(field)
	return out


static func group_of(key: String) -> String:
	for field: Dictionary in all_fields():
		if str(field.key) == key:
			return str(field.get("group", GROUP_WORLD))
	return GROUP_WORLD


static func has_field(key: String) -> bool:
	for field: Dictionary in all_fields():
		if str(field.key) == key:
			return true
	return false


static func has_list_source(key: String) -> bool:
	for source: Dictionary in LIST_SOURCES:
		if str(source.key) == key:
			return true
	return false


static func has_item_prop(key: String) -> bool:
	for prop: Dictionary in ITEM_PROPS:
		if str(prop.key) == key:
			return true
	return false


static func prop_type(key: String) -> String:
	for prop: Dictionary in ITEM_PROPS:
		if str(prop.key) == key:
			return str(prop.get("type", "float"))
	return "float"
