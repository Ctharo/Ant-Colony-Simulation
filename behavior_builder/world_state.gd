class_name BBWorldState
extends RefCounted
## Mutable world snapshot the graph evaluates against.
## The side-panel sliders write into this; every change re-evaluates the graph.
##
## Fields are grouped: "ant" values live on the ant itself (vitals, carried
## mass, its max stats), "world" values are things the ant senses around it.
## The two groups get separate value-reader nodes and separate slider sections.

signal changed(key: String, value: float)

const FIELDS := [
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

var values := {}


func _init() -> void:
	for f in FIELDS:
		values[f.key] = f.default


static func fields_in_group(group: String) -> Array:
	return FIELDS.filter(func(f): return str(f.get("group", "world")) == group)


static func group_of(key: String) -> String:
	for f in FIELDS:
		if f.key == key:
			return str(f.get("group", "world"))
	return "world"


func set_value(key: String, v: float) -> void:
	if values.get(key) != v:
		values[key] = v
		changed.emit(key, v)


func get_value(key: String) -> float:
	return float(values.get(key, 0.0))


func snapshot() -> Dictionary:
	return values.duplicate()
