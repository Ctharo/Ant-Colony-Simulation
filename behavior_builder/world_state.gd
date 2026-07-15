class_name BBWorldState
extends RefCounted
## Mutable world snapshot the graph evaluates against.
## The side-panel sliders write into this; every change re-evaluates the graph.

signal changed(key: String, value: float)

const FIELDS := [
	{"key": "food_dist",     "label": "Food distance",        "min": 0.0,    "max": 100.0, "default": 50.0,  "step": 1.0},
	{"key": "enemy_dist",    "label": "Enemy distance",       "min": 0.0,    "max": 100.0, "default": 80.0,  "step": 1.0},
	{"key": "friend_dist",   "label": "Friend distance",      "min": 0.0,    "max": 100.0, "default": 20.0,  "step": 1.0},
	{"key": "colony_dist",   "label": "Colony distance",      "min": 0.0,    "max": 100.0, "default": 30.0,  "step": 1.0},
	{"key": "food_pher",     "label": "Food pheromone conc.", "min": 0.0,    "max": 1.0,   "default": 0.2,   "step": 0.01},
	{"key": "food_pher_dir", "label": "Food pheromone dir °", "min": -180.0, "max": 180.0, "default": 0.0,   "step": 1.0},
	{"key": "home_pher",     "label": "Home pheromone conc.", "min": 0.0,    "max": 1.0,   "default": 0.5,   "step": 0.01},
	{"key": "home_pher_dir", "label": "Home pheromone dir °", "min": -180.0, "max": 180.0, "default": 0.0,   "step": 1.0},
	{"key": "health",        "label": "Health",               "min": 0.0,    "max": 100.0, "default": 100.0, "step": 1.0},
	{"key": "energy",        "label": "Energy",               "min": 0.0,    "max": 100.0, "default": 100.0, "step": 1.0},
	{"key": "carried_mass",  "label": "Carried mass",         "min": 0.0,    "max": 10.0,  "default": 0.0,   "step": 0.1},
]

var values := {}


func _init() -> void:
	for f in FIELDS:
		values[f.key] = f.default


func set_value(key: String, v: float) -> void:
	if values.get(key) != v:
		values[key] = v
		changed.emit(key, v)


func get_value(key: String) -> float:
	return float(values.get(key, 0.0))


func snapshot() -> Dictionary:
	return values.duplicate()
