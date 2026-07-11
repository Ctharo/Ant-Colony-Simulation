class_name AntSenses
extends RefCounted
## Tier 0 of the behavior language: the ATOMIC, read-only vocabulary that
## Logic expressions evaluate against. EvaluationSystem executes expressions
## against this object instead of the Ant, so UI-authored expressions cannot
## reach mutating methods.
##
## MEMBERSHIP RULE (the litmus test):
##   A symbol lives here if and only if it CANNOT be computed from other
##   AntSenses values using Expression math — i.e. it requires a spatial
##   query, node access, or engine state. Anything computable from these
##   primitives belongs in a Logic resource (Tier 1, "derived").
##
##   Atomic:  colony_position, nearest_food_in_view_position, energy_level
##   Derived: distance_to_colony, low_energy, food_is_near  →  Logic resources
##
## SAFETY RULE:
##   Every public symbol returns a VALUE TYPE (bool/int/float/String/Vector2).
##   Never expose Nodes, Resources, or Arrays of them — objects reachable
##   from an expression allow arbitrary chained method calls, which is the
##   residual risk this facade exists to close.
##
## Spatial queries go through AntPerception (the ant's node-returning query
## layer); this facade flattens their results to value types. Vitals and body
## state read straight off the ant.
##
## Every public symbol MUST have a VOCAB entry (category, doc, returns).
## get_vocabulary() joins reflection with VOCAB and warns loudly on drift,
## so the editor's picker can never silently fall out of sync.

var _ant: Ant
var _perception: AntPerception


func _init(p_ant: Ant) -> void:
	_ant = p_ant
	_perception = p_ant.perception


#region Vocabulary metadata (drives the expression editor's picker)
const CAT_VITALS := "Vitals"
const CAT_BODY := "Body & movement"
const CAT_COLONY := "Colony"
const CAT_FOOD := "Food senses"
const CAT_ANTS := "Other ants"
const CAT_PHEROMONE := "Pheromones"
const CAT_CONST := "Constants"

## name -> { category, returns, doc }. Signals intent to the editor; the
## reflection pass in get_vocabulary() enforces completeness.
const VOCAB: Dictionary = {
	# Constants
	"ENERGY_MAX": { "category": CAT_CONST, "returns": "float", "doc": "Maximum energy an ant can have." },
	"HEALTH_MAX": { "category": CAT_CONST, "returns": "float", "doc": "Maximum health an ant can have." },
	"CARRY_MAX": { "category": CAT_CONST, "returns": "int", "doc": "Maximum food items an ant can carry." },
	"ENERGY_DRAIN_FACTOR": { "category": CAT_CONST, "returns": "float", "doc": "Energy drained per unit of velocity per second." },

	# Vitals
	"energy_level": { "category": CAT_VITALS, "returns": "float", "doc": "Current energy, 0..ENERGY_MAX." },
	"health_level": { "category": CAT_VITALS, "returns": "float", "doc": "Current health, 0..HEALTH_MAX." },
	"is_carrying_food": { "category": CAT_VITALS, "returns": "bool", "doc": "True while carrying a food item." },
	"is_resting": { "category": CAT_VITALS, "returns": "bool", "doc": "True while rest_until_full() is in progress." },
	"is_dead": { "category": CAT_VITALS, "returns": "bool", "doc": "True once the ant has died." },

	# Body & movement
	"movement_rate": { "category": CAT_BODY, "returns": "float", "doc": "Base movement speed from the profile." },
	"vision_range": { "category": CAT_BODY, "returns": "float", "doc": "Sight radius in pixels." },
	"velocity": { "category": CAT_BODY, "returns": "Vector2", "doc": "Current velocity vector." },
	"global_position": { "category": CAT_BODY, "returns": "Vector2", "doc": "World position of this ant." },
	"global_rotation": { "category": CAT_BODY, "returns": "float", "doc": "Facing angle in radians." },
	"role": { "category": CAT_BODY, "returns": "String", "doc": "Role id from the profile (e.g. \"worker\", \"soldier\")." },

	# Colony (flattened — the Colony object itself is never exposed)
	"has_colony": { "category": CAT_COLONY, "returns": "bool", "doc": "True if this ant belongs to a live colony." },
	"colony_position": { "category": CAT_COLONY, "returns": "Vector2", "doc": "World position of the home colony (own position if none)." },
	"colony_radius": { "category": CAT_COLONY, "returns": "float", "doc": "Radius of the home colony (0 if none)." },
	"is_colony_in_range": { "category": CAT_COLONY, "returns": "bool", "doc": "True if the home colony overlaps the reach area." },
	"is_colony_in_sight": { "category": CAT_COLONY, "returns": "bool", "doc": "True if the home colony overlaps the sight area." },

	# Food senses (counts + nearest positions; never Food nodes)
	"food_in_view_count": { "category": CAT_FOOD, "returns": "int", "doc": "Available food items inside the sight area." },
	"food_in_reach_count": { "category": CAT_FOOD, "returns": "int", "doc": "Available food items inside the reach area." },
	"nearest_food_in_view_position": { "category": CAT_FOOD, "returns": "Vector2", "doc": "Position of the nearest visible food, or Vector2.INF when none (gate on food_in_view_count first)." },
	"nearest_food_in_reach_position": { "category": CAT_FOOD, "returns": "Vector2", "doc": "Position of the nearest reachable food, or Vector2.INF when none." },

	# Other ants
	"ants_in_view_count": { "category": CAT_ANTS, "returns": "int", "doc": "All other ants inside the sight area." },
	"allies_in_view_count": { "category": CAT_ANTS, "returns": "int", "doc": "Same-colony ants inside the sight area." },
	"enemies_in_view_count": { "category": CAT_ANTS, "returns": "int", "doc": "Foreign-colony ants inside the sight area." },
	"nearest_enemy_position": { "category": CAT_ANTS, "returns": "Vector2", "doc": "Position of the nearest visible enemy ant, or Vector2.INF when none." },
	"nearest_ally_position": { "category": CAT_ANTS, "returns": "Vector2", "doc": "Position of the nearest visible ally ant, or Vector2.INF when none." },

	# Pheromones (parameterized — must stay methods; args are value types)
	"pheromone_direction": { "category": CAT_PHEROMONE, "returns": "Vector2", "doc": "Gradient direction for the named pheromone (also updates the ant's sample memory — sensor-internal state, not world mutation)." },
	"pheromone_concentration": { "category": CAT_PHEROMONE, "returns": "float", "doc": "Local concentration of the named pheromone." },
}

## Old node-returning API, kept callable so nothing hard-crashes during
## migration, but hidden from the editor's vocabulary. The influence
## expressions under res://resources/influences are the last known callers.
## Run ResourceLibrary.audit_expressions() to list every resource still using
## one, rewrite those expressions, then delete this block and these methods.
const DEPRECATED: Array[String] = [
	"get_food_in_view", "get_food_in_reach", "get_ants_in_view",
	"get_colonies_in_view", "get_colonies_in_reach", "get_nearest_item",
	"get_nearest_food_in_reach", "filter_friendly_ants",
	"get_pheromone_direction", "get_pheromone_concentration",
]
#endregion


#region Constants
const ENERGY_MAX := Ant.ENERGY_MAX
const HEALTH_MAX := Ant.HEALTH_MAX
const CARRY_MAX := Ant.CARRY_MAX
const ENERGY_DRAIN_FACTOR := Ant.ENERGY_DRAIN_FACTOR
#endregion


#region Vitals
var energy_level: float:
	get: return _ant.energy_level
var health_level: float:
	get: return _ant.health_level
var is_carrying_food: bool:
	get: return _ant.is_carrying_food
var is_resting: bool:
	get: return _ant.is_resting
var is_dead: bool:
	get: return _ant.is_dead
#endregion


#region Body & movement
var movement_rate: float:
	get: return _ant.movement_rate
var vision_range: float:
	get: return _ant.vision_range
var velocity: Vector2:
	get: return _ant.velocity
var global_position: Vector2:
	get: return _ant.global_position
var global_rotation: float:
	get: return _ant.global_rotation
var role: String:
	get: return _ant.role
#endregion


#region Colony
var has_colony: bool:
	get: return is_instance_valid(_ant.colony)
var colony_position: Vector2:
	get: return _ant.colony.global_position if is_instance_valid(_ant.colony) else global_position
var colony_radius: float:
	get: return _ant.colony.radius if is_instance_valid(_ant.colony) else 0.0

func is_colony_in_range() -> bool:
	return _perception.is_colony_in_range()

func is_colony_in_sight() -> bool:
	return _perception.is_colony_in_sight()
#endregion


#region Food senses
var food_in_view_count: int:
	get: return _perception.get_food_in_view().size()
var food_in_reach_count: int:
	get: return _perception.get_food_in_reach().size()
var nearest_food_in_view_position: Vector2:
	get: return _nearest_position(_perception.get_food_in_view())
var nearest_food_in_reach_position: Vector2:
	get: return _nearest_position(_perception.get_food_in_reach())
#endregion


#region Other ants
var ants_in_view_count: int:
	get: return _perception.get_ants_in_view().size()
var allies_in_view_count: int:
	get: return _perception.filter_friendly_ants(_perception.get_ants_in_view(), true).size()
var enemies_in_view_count: int:
	get: return _perception.filter_friendly_ants(_perception.get_ants_in_view(), false).size()
var nearest_enemy_position: Vector2:
	get: return _nearest_position(_perception.filter_friendly_ants(_perception.get_ants_in_view(), false))
var nearest_ally_position: Vector2:
	get: return _nearest_position(_perception.filter_friendly_ants(_perception.get_ants_in_view(), true))
#endregion


#region Pheromones
func pheromone_direction(pheromone_name: String, follow_concentration: bool = true) -> Vector2:
	return _perception.get_pheromone_direction(pheromone_name, follow_concentration)

func pheromone_concentration(pheromone_name: String) -> float:
	return _perception.get_pheromone_concentration(pheromone_name)
#endregion

#region Helpers
## Nearest item's position by distance to this ant, or Vector2.INF when the
## list is empty. INF makes distance comparisons fail naturally ("< 50" is
## false), so conditions degrade safely without a separate null check.
func _nearest_position(items: Array) -> Vector2:
	var nearest: Node2D = _perception.get_nearest_item(items)
	return nearest.global_position if is_instance_valid(nearest) else Vector2.INF
#endregion


#region Editor reflection
## Identifier list for the expression editor: reflection joined with VOCAB
## metadata. Deprecated symbols are skipped; any public symbol missing a
## VOCAB entry triggers a loud warning so drift can't be silent.
static func get_vocabulary() -> Array[Dictionary]:
	var vocab: Array[Dictionary] = []
	var script: Script = AntSenses

	for const_name: String in script.get_script_constant_map():
		if const_name in ["VOCAB", "DEPRECATED"] or const_name.begins_with("CAT_"):
			continue
		vocab.append(_entry(const_name, "const", ""))

	for prop: Dictionary in script.get_script_property_list():
		if prop.name.begins_with("_") or prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		vocab.append(_entry(prop.name, "property", ""))

	for method: Dictionary in script.get_script_method_list():
		if method.name.begins_with("_") or method.name == "get_vocabulary":
			continue
		if method.name in DEPRECATED:
			continue
		var arg_names := PackedStringArray()
		for arg: Dictionary in method.args:
			arg_names.append(arg.name)
		vocab.append(_entry(method.name, "method",
			"%s(%s)" % [method.name, ", ".join(arg_names)]))

	vocab.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.category < b.category if a.category != b.category else a.name < b.name)
	return vocab


static func _entry(p_name: String, kind: String, signature: String) -> Dictionary:
	var meta: Dictionary = VOCAB.get(p_name, {})
	if meta.is_empty():
		push_warning("AntSenses: public symbol '%s' has no VOCAB metadata — add it or prefix with _." % p_name)
	return {
		"name": p_name,
		"kind": kind,
		"signature": signature if not signature.is_empty() else p_name,
		"category": meta.get("category", "Uncategorized"),
		"returns": meta.get("returns", "?"),
		"doc": meta.get("doc", ""),
	}
#endregion
