class_name AntSenses
extends RefCounted
## The complete, read-only vocabulary available to Logic expressions.
## EvaluationSystem executes expressions against this object instead of the
## Ant, so UI-authored expressions cannot reach mutating methods like
## suicide() or store_food(). Every identifier a leaf expression may use
## must exist here — this class IS the expression language's symbol table,
## and the editor builds its vocabulary list from it via reflection.

var _ant: Ant

func _init(p_ant: Ant) -> void:
	_ant = p_ant

#region Constants
const ENERGY_MAX := Ant.ENERGY_MAX
const HEALTH_MAX := Ant.HEALTH_MAX
const CARRY_MAX := Ant.CARRY_MAX
const ENERGY_DRAIN_FACTOR := Ant.ENERGY_DRAIN_FACTOR
#endregion

#region Vital stats
var energy_level: float :
	get: return _ant.energy_level
var health_level: float :
	get: return _ant.health_level
var is_carrying_food: bool :
	get: return _ant.is_carrying_food
var is_resting: bool :
	get: return _ant.is_resting
var is_dead: bool :
	get: return _ant.is_dead
#endregion

#region Body & movement
var movement_rate: float :
	get: return _ant.movement_rate
var vision_range: float :
	get: return _ant.vision_range
var velocity: Vector2 :
	get: return _ant.velocity
var global_position: Vector2 :
	get: return _ant.global_position
var global_rotation: float :
	get: return _ant.global_rotation
var role: String :
	get: return _ant.role
#endregion

#region Colony (flattened — never expose the Colony object itself)
var has_colony: bool :
	get: return is_instance_valid(_ant.colony)
var colony_position: Vector2 :
	get: return _ant.colony.global_position if is_instance_valid(_ant.colony) else global_position
var colony_radius: float :
	get: return _ant.colony.radius if is_instance_valid(_ant.colony) else 0.0
#endregion

#region Sensing methods (pure reads, delegated to the ant)
func get_food_in_view() -> Array:
	return _ant.get_food_in_view()

func get_food_in_reach() -> Array:
	return _ant.get_food_in_reach()

func get_ants_in_view() -> Array:
	return _ant.get_ants_in_view()

func get_colonies_in_view() -> Array:
	return _ant.get_colonies_in_view()

func get_colonies_in_reach() -> Array:
	return _ant.get_colonies_in_reach()

func get_nearest_item(list: Array) -> Variant:
	return _ant.get_nearest_item(list)

func get_nearest_food_in_reach() -> Food:
	return _ant.get_nearest_food_in_reach()

func filter_friendly_ants(ants_arr: Array, friendly: bool = true) -> Array:
	return _ant.filter_friendly_ants(ants_arr, friendly)

func is_colony_in_range() -> bool:
	return _ant.is_colony_in_range()

func is_colony_in_sight() -> bool:
	return _ant.is_colony_in_sight()

## Note: reads the heatmap but also updates the ant's pheromone sample
## memory — sensor-internal state, not world mutation, so it's allowed.
func get_pheromone_direction(pheromone_name: String, follow_concentration: bool = true) -> Vector2:
	return _ant.get_pheromone_direction(pheromone_name, follow_concentration)

func get_pheromone_concentration(pheromone_name: String) -> float:
	return _ant.get_pheromone_concentration(pheromone_name)
#endregion

#region Editor reflection
## Identifier list for the expression editor: constants, properties, and
## methods, kept in sync automatically because it reflects this script.
static func get_vocabulary() -> Array[Dictionary]:
	var vocab: Array[Dictionary] = []
	var script: Script = AntSenses

	for const_name: String in script.get_script_constant_map():
		vocab.append({ "name": const_name, "kind": "const" })

	for prop: Dictionary in script.get_script_property_list():
		if prop.name.begins_with("_") or prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		vocab.append({ "name": prop.name, "kind": "property" })

	for method: Dictionary in script.get_script_method_list():
		if method.name.begins_with("_") or method.name == "get_vocabulary":
			continue
		var arg_names := PackedStringArray()
		for arg: Dictionary in method.args:
			arg_names.append(arg.name)
		vocab.append({
			"name": method.name,
			"kind": "method",
			"signature": "%s(%s)" % [method.name, ", ".join(arg_names)]
		})

	vocab.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.name < b.name)
	return vocab
#endregion
