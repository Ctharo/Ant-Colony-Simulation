class_name Action
extends RefCounted
## Interface between [class Behavior]s and [class Ant] action methods

## Signal emitted when action starts
signal started

## Signal emitted when action completes
signal completed

## Signal emitted when action is interrupted
signal interrupted

## Reference to the ant performing the action
var ant: Ant:
	get:
		return ant
	set(value):
		ant = value

## Cooldown time for the action (in seconds)
var cooldown: float = 0.0:
	get:
		return cooldown
	set(value):
		cooldown = value

## Current cooldown timer
var current_cooldown: float = 0.0:
	get:
		return current_cooldown
	set(value):
		current_cooldown = value

## Parameters passed to the action
var params: Dictionary = {}:
	get:
		return params
	set(value):
		params = value

## Builder class for constructing actions
class ActionBuilder:
	## The action being built
	var action: Action
	var ant: Ant
	## Parameters to be passed to the action
	var params: Dictionary = {}
	
	## Initialize the builder with an action class
	## @param action_class The class of action to build
	func _init(action_class: GDScript):
		action = action_class.new()
	
	## Add a parameter to the action
	## @param key The parameter key
	## @param value The parameter value
	## @return The builder for method chaining
	func with_param(key: String, value: Variant) -> ActionBuilder:
		params[key] = value
		return self
	
	## Set the cooldown time for the action
	## @param time The cooldown time in seconds
	## @return The builder for method chaining
	func with_cooldown(time: float) -> ActionBuilder:
		action.cooldown = time
		return self
	
	## Build and return the configured action
	## @return The configured action
	func build() -> Action:
		action.params = params
		return action

## Create a new action builder
## @param action_class The class of action to build
## @return A new action builder
static func create(action_class: GDScript) -> ActionBuilder:
	return ActionBuilder.new(action_class)


## Start the action for the given ant
## @param _ant The ant performing the action
func start(_ant: Ant) -> void:
	ant = _ant
	current_cooldown = cooldown
	started.emit()

## Update the action
## @param delta Time elapsed since the last update
func update(delta: float) -> void:
	if current_cooldown > 0:
		current_cooldown -= delta
	_update_action(delta)

## Internal update logic for the specific action (to be overridden)
## @param delta Time elapsed since the last update
func _update_action(_delta: float) -> void:
	pass

## Check if the action is completed
## @return True if the action is completed, false otherwise
func is_completed() -> bool:
	return true

## Cancel the action
func cancel() -> void:
	pass

## Interrupt the action
func interrupt() -> void:
	cancel()
	current_cooldown = cooldown
	interrupted.emit()

## Reset the action to its initial state
func reset() -> void:
	current_cooldown = 0.0

## Check if the action is ready (not on cooldown)
## @return True if the action is ready, false otherwise
func is_ready() -> bool:
	return current_cooldown <= 0

## Serialize the action to a dictionary
func to_dict() -> Dictionary:
	return {
		"type": get_script().resource_path,
		"cooldown": cooldown,
		"params": params
	}

## Create an action from a dictionary
static func from_dict(data: Dictionary) -> Action:
	var action = load(data["type"]).new()
	action.cooldown = data["cooldown"]
	action.params = data["params"]
	return action

## Action for moving the ant
class Move extends Action:
		
	## Update the movement
	func _update_action(delta: float) -> void:
		if not "target_position" in params:
			push_error("Move action requires target_position")
			return
			
		var target_position = params["target_position"]
		var movement_rate_modifier = params.get("rate_modifier", 1.0)
		var direction = ant.global_position.direction_to(target_position)
		ant.velocity = direction * movement_rate_modifier * ant.speed.movement_rate
		ant.energy.deplete(delta * movement_rate_modifier * 0.1)
	
	## Check if we've reached the target
	func is_completed() -> bool:
		if not "target_position" in params:
			return true
		return ant.global_position.distance_to(params["target_position"]) < 1.0
	
	## Static creator method
	static func create(_action_class: GDScript) -> ActionBuilder:
		return Action.create(Move)  # Fixed to not pass unnecessary parameter


## Action for harvesting food
class Harvest extends Action:
	var current_food_source: Food
	
	## Update the harvest action
	func _update_action(delta: float) -> void:
		if not "target_food" in params:
			push_error("Harvest action requires target_food parameter")
			return
			
		current_food_source = params["target_food"]
		if current_food_source and not current_food_source.is_depleted():
			var harvest_rate_modifier = params.get("harvest_rate_modifier", 1.0)
			var amount_harvested = ant.harvest_food(
				current_food_source, 
				delta * harvest_rate_modifier * ant.speed.harvesting_rate
			)
			if amount_harvested > 0:
				if params.get("debug_harvest", false):
					print("Harvested %f amount of food" % amount_harvested)
		else:
			push_error("No valid food source to harvest")
	
	## Check if harvesting is completed
	func is_completed() -> bool:
		if not current_food_source:
			return true
		return not ant.can_carry_more() or current_food_source.is_depleted()
	
	## Static creator method
	static func create(_action_class: GDScript = null) -> ActionBuilder:
		return Action.create(Harvest)

## Action for following pheromones
class FollowPheromone extends Action:
	func _update_action(delta: float) -> void:
		if not "pheromone_type" in params:
			push_error("FollowPheromone action requires pheromone_type parameter")
			return
			
		var pheromone_type = params["pheromone_type"]
		
		var pheromone_direction = ant.get_strongest_pheromone_direction(pheromone_type)
		
		ant.move(pheromone_direction, delta)
		
	func is_completed() -> bool:
		return false
	
	## Static creator method
	static func create(_action_class: GDScript = null) -> ActionBuilder:
		return Action.create(FollowPheromone)

## Action for random movement
class RandomMove extends Action:
	var current_time: float = 0.0
	var current_direction: Vector2 = Vector2.ZERO
	
	func _update_action(delta: float) -> void:
		current_time += delta
		
		var move_duration = params.get("move_duration", 2.0)
		if current_time >= move_duration or current_direction == Vector2.ZERO:
			current_time = 0
			current_direction = Vector2(randf() * 2 - 1, randf() * 2 - 1).normalized()
		
		var movement_rate_modifier = params.get("movement_rate_modifier", 1.0) 
		ant.move(current_direction, delta)
	
	func is_completed() -> bool:
		return false
	
	## Static creator method
	static func create(_action_class: GDScript = null) -> ActionBuilder:
		return Action.create(RandomMove)
		
## Action for storing food in the colony
class Store extends Action:
	func _update_action(delta: float) -> void:
		var store_rate_modifier = params.get("store_rate_modifier", 1.0)
		ant.store_food(ant.colony, delta * store_rate_modifier * ant.speed.storing_rate)
	
	func is_completed() -> bool:
		return ant.foods.is_empty()
	
	## Static creator method
	static func create(_action_class: GDScript = null) -> ActionBuilder:
		return Action.create(Store)

## Action for attacking another ant or entity
class Attack extends Action:
	var current_target_entity: Node2D
	var current_target_location: Vector2
	
	func _update_action(delta: float) -> void:
		if not ("target_entity" in params or "target_location" in params):
			push_error("Attack action requires either target_entity or target_location")
			return
			
		if not is_ready():
			return
		
		current_target_entity = params.get("target_entity")
		current_target_location = params.get("target_location", Vector2.ZERO)
		var attack_range_modifier = params.get("attack_range_modifier", 1.0)
		var attack_range = attack_range_modifier * ant.reach.distance
		if current_target_entity and is_instance_valid(current_target_entity):
			if ant.global_position.distance_to(current_target_entity.global_position) <= attack_range:
				ant.attack(current_target_entity, delta)
			else:
				ant.move_to(current_target_location, delta)
		elif current_target_location != Vector2.ZERO:
			if ant.global_position.distance_to(current_target_location) <= attack_range:
				ant.attack(current_target_entity, delta)
			else:
				ant.move_to(current_target_location, delta)
	
		current_cooldown = params.get("attack_cooldown", 1.0)
		
	## Check if attack is completed
	func is_completed() -> bool:
		if current_target_entity and not is_instance_valid(current_target_entity):
			return true
		return ant.energy.is_depleted()
	
	## Static creator method
	static func create(_action_class: GDScript = null) -> ActionBuilder:
		return Action.create(Attack)

## Action for moving to food
class MoveToFood extends Action:
	var current_target_food: Food = null
	
	func _update_action(delta: float) -> void:
		if not "target_food" in params:
			push_error("MoveToFood action requires target_food parameter")
			return
			
		current_target_food = params["target_food"]
		if not current_target_food:
			push_error("No target food to move to")
			return
			
		var movement_rate_modifier = params.get("rate_modifier", 1.0)
		var direction = ant.global_position.direction_to(current_target_food.global_position)
		ant.global_position += direction * movement_rate_modifier * ant.speed.movement_rate * delta 
	
	func is_completed() -> bool:
		return not is_instance_valid(current_target_food) or\
			   ant.global_position.distance_to(current_target_food.global_position) < 1.0
	
	## Static creator method
	static func create(_action_class: GDScript = null) -> ActionBuilder:
		return Action.create(MoveToFood)

## Action for emitting pheromones
class EmitPheromone extends Action:
	var current_time: float = 0.0
	
	func _update_action(delta: float) -> void:
		if not "pheromone_type" in params:
			push_error("EmitPheromone action requires pheromone_type parameter")
			return
			
		if not "emission_duration" in params:
			push_error("EmitPheromone action requires emission_duration parameter")
			return
		
		var pheromone_type = params["pheromone_type"]
		var pheromone_strength = params.get("pheromone_strength", 1.0)
		
		ant.emit_pheromone(pheromone_type, pheromone_strength)
		current_time += delta
	
	func is_completed() -> bool:
		return current_time >= params.get("emission_duration", 0.0)
	
	## Static creator method
	static func create(_action_class: GDScript = null) -> ActionBuilder:
		return Action.create(EmitPheromone)

## Action for resting to regain energy
class Rest extends Action:
	func _update_action(delta: float) -> void:
		var energy_gain_rate = params.get("energy_gain_rate", 10.0)
		ant.energy.replenish(energy_gain_rate * delta)
	
	func is_completed() -> bool:
		return ant.energy.is_full()
	
	## Static creator method
	static func create(_action_class: GDScript = null) -> ActionBuilder:
		return Action.create(Rest)
