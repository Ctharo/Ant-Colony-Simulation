class_name Action
extends RefCounted

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
	return Action.create(action_class)

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
## Movement action for moving to a specific position
class Move extends Action:
	## Get movement parameters from params
	func _init() -> void:
		assert("target_position" in params, "Move action requires target_position")
	
	## Update the movement
	func _update_action(delta: float) -> void:
		var target_position = params["target_position"]
		var movement_rate = params.get("movement_rate", ant.speed.movement_rate)
		var direction = ant.global_position.direction_to(target_position)
		ant.velocity = direction * movement_rate
		ant.energy.deplete(delta * movement_rate * 0.1)
	
	## Check if we've reached the target
	func is_completed() -> bool:
		return ant.global_position.distance_to(params["target_position"]) < 1.0
	
	## Static creator method
	static func create(_action_class: GDScript) -> ActionBuilder:
		return Action.create(Move)

## Action for harvesting food
class Harvest extends Action:
	var current_food_source: Food
	
	func _init() -> void:
		assert("target_food" in params, "Harvest action requires target_food parameter")
		current_food_source = params["target_food"]
	
	## Start the harvest action
	func start(_ant: Ant) -> void:
		super.start(_ant)
		params["harvest_rate"] = params.get("harvest_rate", ant.speed.harvesting_rate)
	
	## Update the harvest action
	func _update_action(delta: float) -> void:
		if current_food_source and not current_food_source.is_depleted():
			var amount_harvested = ant.harvest_food(
				current_food_source, 
				delta * params["harvest_rate"]
			)
			if amount_harvested > 0:
				if params.get("debug_harvest", false):
					print("Harvested %f amount of food" % amount_harvested)
				ant.energy.deplete(delta * 0.2)  # Energy cost for harvesting
		else:
			push_error("No valid food source to harvest")
	
	## Check if harvesting is completed
	func is_completed() -> bool:
		return not ant.can_carry_more() or current_food_source.is_depleted()
	
	## Static creator method
	static func create(_action_class: GDScript) -> ActionBuilder:
		return Action.create(Harvest)

## Action for storing food in the colony
class Store extends Action:
	func _init() -> void:
		params["store_rate"] = params.get("store_rate", 1.0)
	
	## Update the store action
	func _update_action(delta: float) -> void:
		var colony = ant.colony
		var store_rate = params["store_rate"]
		ant.store_food(colony, delta * store_rate)
	
	## Check if storing is completed
	func is_completed() -> bool:
		return ant.foods.is_empty()
	
	## Static creator method
	static func create(_action_class: GDScript) -> ActionBuilder:
		return Action.create(Store)

## Action for attacking another ant or entity
class Attack extends Action:
	var current_target_entity: Node2D
	var current_target_location: Vector2
	
	func _init() -> void:
		assert("target_entity" in params or "target_location" in params,
			   "Attack action requires either target_entity or target_location")
		
		# Set up attack parameters with defaults
		params["attack_range"] = params.get("attack_range", 10.0)
		params["attack_damage"] = params.get("attack_damage", 1.0)
		params["attack_cooldown"] = params.get("attack_cooldown", 1.0)
		
		current_target_entity = params.get("target_entity")
		current_target_location = params.get("target_location", Vector2.ZERO)
	
	## Update the attack action
	func _update_action(delta: float) -> void:
		if not is_ready():
			return
		
		var attack_range = params["attack_range"]
		
		if current_target_entity and is_instance_valid(current_target_entity):
			if ant.global_position.distance_to(current_target_entity.global_position) <= attack_range:
				_perform_attack()
			else:
				_move_towards_target(delta)
		elif current_target_location != Vector2.ZERO:
			if ant.global_position.distance_to(current_target_location) <= attack_range:
				_perform_attack()
			else:
				_move_towards_target(delta)
	
	## Perform the actual attack
	func _perform_attack() -> void:
		if current_target_entity and current_target_entity.has_method("take_damage"):
			current_target_entity.take_damage(params["attack_damage"])
		
		current_cooldown = params["attack_cooldown"]
		ant.energy.deplete(0.5)  # Energy cost for attacking
	
	## Move towards the current target
	func _move_towards_target(delta: float) -> void:
		var target_pos = current_target_entity.global_position if current_target_entity\
						else current_target_location
		var direction = ant.global_position.direction_to(target_pos)
		ant.velocity = direction * ant.speed.movement_rate
		ant.energy.deplete(delta * ant.speed.movement_rate * 0.1)
	
	## Check if attack is completed
	func is_completed() -> bool:
		if current_target_entity and not is_instance_valid(current_target_entity):
			return true
		return ant.energy.is_depleted()
	
	## Static creator method
	static func create(_action_class: GDScript) -> ActionBuilder:
		return Action.create(Attack)

## Action for moving to food
class MoveToFood extends Action:
	var current_target_food: Food = null
	
	func _init() -> void:
		assert("target_food" in params, "MoveToFood action requires target_food parameter")
		current_target_food = params["target_food"]
	
	func _update_action(delta: float) -> void:
		if not current_target_food:
			push_error("No target food to move to")
			return
			
		var movement_rate = params.get("movement_rate", ant.speed.movement_rate)
		var direction = (current_target_food.global_position - ant.global_position).normalized()
		ant.global_position += direction * movement_rate * delta
		ant.energy.deplete(delta * movement_rate * 0.1)
	
	func is_completed() -> bool:
		return not is_instance_valid(current_target_food) or\
			   ant.global_position.distance_to(current_target_food.global_position) < 1.0
	
	## Static creator method
	static func create(_action_class: GDScript) -> ActionBuilder:
		return Action.create(MoveToFood)

## Action for random movement
class RandomMove extends Action:
	var current_time: float = 0.0
	var current_direction: Vector2 = Vector2.ZERO
	
	func _init() -> void:
		params["move_duration"] = params.get("move_duration", 2.0)
		params["movement_rate"] = params.get("movement_rate", 1.0)
	
	func _update_action(delta: float) -> void:
		current_time += delta
		
		if current_time >= params["move_duration"] or current_direction == Vector2.ZERO:
			current_time = 0
			current_direction = Vector2(randf() * 2 - 1, randf() * 2 - 1).normalized()
		
		var movement_rate = params["movement_rate"] * ant.speed.movement_rate
		ant.velocity = current_direction * movement_rate
		ant.energy.deplete(delta * movement_rate * 0.1)
	
	func is_completed() -> bool:
		return false
	
	## Static creator method
	static func create(_action_class: GDScript) -> ActionBuilder:
		return Action.create(RandomMove)

## Action for following pheromones
class FollowPheromone extends Action:
	func _init() -> void:
		assert("pheromone_type" in params, "FollowPheromone action requires pheromone_type parameter")
		params["follow_speed"] = params.get("follow_speed", 1.0)
	
	func _update_action(delta: float) -> void:
		var pheromone_type = params["pheromone_type"]
		var follow_speed = params["follow_speed"]
		
		var pheromone_direction = ant.get_strongest_pheromone_direction(pheromone_type)
		var movement_rate = follow_speed * ant.speed.movement_rate
		
		ant.velocity = pheromone_direction * movement_rate
		ant.energy.deplete(delta * movement_rate * 0.1)
	
	func is_completed() -> bool:
		return false
	
	## Static creator method
	static func create(_action_class: GDScript) -> ActionBuilder:
		return Action.create(FollowPheromone)

## Action for emitting pheromones
class EmitPheromone extends Action:
	var current_time: float = 0.0
	
	func _init() -> void:
		assert("pheromone_type" in params, "EmitPheromone action requires pheromone_type parameter")
		assert("emission_duration" in params, "EmitPheromone action requires emission_duration parameter")
		
		params["pheromone_strength"] = params.get("pheromone_strength", 1.0)
	
	func _update_action(delta: float) -> void:
		var pheromone_type = params["pheromone_type"]
		var pheromone_strength = params["pheromone_strength"]
		
		ant.emit_pheromone(pheromone_type, pheromone_strength)
		current_time += delta
		ant.energy.deplete(delta * 0.1)
	
	func is_completed() -> bool:
		return current_time >= params["emission_duration"]
	
	## Static creator method
	static func create(_action_class: GDScript) -> ActionBuilder:
		return Action.create(EmitPheromone)

## Action for resting to regain energy
class Rest extends Action:
	func _init() -> void:
		params["energy_gain_rate"] = params.get("energy_gain_rate", 10.0)
	
	func _update_action(delta: float) -> void:
		var energy_gain_rate = params["energy_gain_rate"]
		ant.energy.replenish(energy_gain_rate * delta)
	
	func is_completed() -> bool:
		return ant.energy.is_full()
	
	## Static creator method
	static func create(_action_class: GDScript) -> ActionBuilder:
		return Action.create(Rest)
