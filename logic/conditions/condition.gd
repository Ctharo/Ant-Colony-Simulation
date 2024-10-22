class_name Condition
extends RefCounted

## Signal emitted when condition evaluation changes
signal evaluation_changed(is_met: bool)

## Previous evaluation result for change detection
var _previous_result: bool = false

## Parameters for the condition
var params: Dictionary = {}

## Builder class for constructing conditions
class ConditionBuilder:
	## The condition being built
	var condition: Condition
	
	## Parameters to be passed to the condition
	var params: Dictionary = {}
	
	## Initialize the builder with a condition class
	## @param condition_class The class of condition to build
	func _init(condition_class: GDScript):
		condition = condition_class.new()
	
	## Add a parameter to the condition
	## @param key The parameter key
	## @param value The parameter value
	## @return The builder for method chaining
	func with_param(key: String, value: Variant) -> ConditionBuilder:
		params[key] = value
		return self
	
	## Build and return the configured condition
	## @return The configured condition
	func build() -> Condition:
		condition.params = params
		return condition

## Create a new condition builder
## @param condition_class The class of condition to build
## @return A new condition builder
static func create(condition_class: GDScript) -> ConditionBuilder:
	return ConditionBuilder.new(condition_class)

## Check if the condition is met for the given ant
## @param ant The ant to check the condition for
## @param cache Dictionary to cache condition results
## @param context Dictionary containing context parameters
## @return True if the condition is met, false otherwise
func is_met(ant: Ant, cache: Dictionary, context: Dictionary) -> bool:
	var result := _evaluate(ant, cache, context)
	if result != _previous_result:
		_previous_result = result
		evaluation_changed.emit(result)
	return result

## Internal evaluation logic (to be overridden by specific conditions)
## @param ant The ant to evaluate the condition for
## @param cache Dictionary to cache condition results
## @param context Dictionary containing context parameters
## @return True if the condition is met, false otherwise
func _evaluate(_ant: Ant, _cache: Dictionary, _context: Dictionary) -> bool:
	return false

## Serialize the condition to a dictionary
func to_dict() -> Dictionary:
	return {
		"type": get_script().resource_path,
		"params": params
	}

## Create a condition from a dictionary
static func from_dict(data: Dictionary) -> Condition:
	var condition = load(data["type"]).new()
	condition.params = data.get("params", {})
	return condition

## Condition to check if food is in view
class FoodInView extends Condition:
	func _evaluate(_ant: Ant, _cache: Dictionary, context: Dictionary) -> bool:
		var is_food_visible: bool = not context.get("food_in_view", []).is_empty()
		return is_food_visible
	
	static func create(_condition_class: GDScript = null) -> ConditionBuilder:
		return Condition.create(FoodInView)

## Condition to check if the ant is carrying food
class CarryingFood extends Condition:
	func _evaluate(_ant: Ant, _cache: Dictionary, context: Dictionary) -> bool:
		var carried_food = context.get("carried_food", 0)
		return carried_food > 0
	
	static func create(_condition_class: GDScript = null) -> ConditionBuilder:
		return Condition.create(CarryingFood)

## Condition to check if the ant is at the colony
class AtHome extends Condition:
	func _evaluate(_ant: Ant, _cache: Dictionary, context: Dictionary) -> bool:
		var distance_to_home = context.get("distance_to_home", float('inf'))
		var threshold = params.get("home_threshold", context.get("home_threshold", 10.0))
		return distance_to_home <= threshold
	
	static func create(_condition_class: GDScript = null) -> ConditionBuilder:
		return Condition.create(AtHome)

## Condition to check if there are food pheromones nearby
class FoodPheromoneSensed extends Condition:
	func _evaluate(_ant: Ant, _cache: Dictionary, context: Dictionary) -> bool:
		var food_pheromones = context.get("food_pheromones", [])
		return not food_pheromones.is_empty()
	
	static func create(_condition_class: GDScript = null) -> ConditionBuilder:
		return Condition.create(FoodPheromoneSensed)

## Condition to check if there are home pheromones nearby
class HomePheromoneSensed extends Condition:
	func _evaluate(ant: Ant, _cache: Dictionary, _context: Dictionary) -> bool:
		return ant.is_pheromone_sensed("home")
	
	static func create(_condition_class: GDScript = null) -> ConditionBuilder:
		return Condition.create(HomePheromoneSensed)

## Condition to check if ant's energy is low
class LowEnergy extends Condition:
	func _evaluate(ant: Ant, _cache: Dictionary, context: Dictionary) -> bool:
		var threshold = params.get("threshold", context.get("low_energy_threshold", 20.0))
		return ant.energy.percentage < threshold
	
	static func create(_condition_class: GDScript = null) -> ConditionBuilder:
		return Condition.create(LowEnergy)\
			.with_param("threshold", 20.0)

## Condition to check if ant is carrying maximum food
class OverloadedWithFood extends Condition:
	func _evaluate(_ant: Ant, _cache: Dictionary, context: Dictionary) -> bool:
		var carried_food = context.get("carried_food", 0)
		var max_carry_capacity = context.get("max_carry_capacity", 0.0)
		var threshold = params.get("threshold", context.get("overload_threshold", 0.9))
		return carried_food >= (max_carry_capacity * threshold)
	
	static func create(_condition_class: GDScript = null) -> ConditionBuilder:
		return Condition.create(OverloadedWithFood)\
			.with_param("threshold", 0.9)
