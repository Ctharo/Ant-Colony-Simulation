class_name Action
extends RefCounted

## Reference to the ant performing the action
var ant: Ant

## Cooldown time for the action (in seconds)
var cooldown: float = 0.0

## Current cooldown timer
var current_cooldown: float = 0.0

## Start the action for the given ant
## @param _ant The ant performing the action
## @param params Dictionary of parameters for the action
func start(_ant: Ant, params: Dictionary = {}) -> void:
	ant = _ant
	current_cooldown = cooldown
	_init_action(params)

## Initialize the action with given parameters
## @param params Dictionary of parameters for the action
func _init_action(_params: Dictionary) -> void:
	pass  # Override in subclasses if needed

## Update the action
## @param delta Time elapsed since the last update
## @param params Dictionary of parameters for the action
func update(delta: float, params: Dictionary = {}) -> void:
	if current_cooldown > 0:
		current_cooldown -= delta
	_update_action(delta, params)

## Update logic for the specific action
## @param delta Time elapsed since the last update
## @param params Dictionary of parameters for the action
func _update_action(_delta: float, _params: Dictionary) -> void:
	pass  # Override in subclasses

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

## Reset the action
func reset() -> void:
	current_cooldown = 0.0

## Check if the action is ready (not on cooldown)
## @return True if the action is ready, false otherwise
func is_ready() -> bool:
	return current_cooldown <= 0

## Action for moving the ant
class Move extends Action:
	## Target position to move to
	var target_position: Vector2
	## Movement rate of the ant
	var movement_rate: float
	
	## Initialize the MoveAction
	## @param _target_position The position to move to
	func _init_action(params: Dictionary) -> void:
		if "target_position" in params:
			target_position = params["target_position"]
		if target_position == Vector2.ZERO:
			push_warning("Target position is ZERO vector")
	
	## Start the move action
	## @param _ant The ant performing the action
	func start(_ant: Ant, params: Dictionary = {}) -> void:
		super.start(_ant, params)
		movement_rate = ant.speed.movement_rate
	
	## Update the move action
	## @param delta Time elapsed since the last update
	func _update_action(delta: float, params: Dictionary = {}) -> void:
		var direction = ant.global_position.direction_to(target_position)
		ant.velocity = direction * movement_rate
		ant.energy.deplete(delta * movement_rate * 0.1)  # Energy cost based on movement_rate
	
	## Check if the move action is completed
	## @return True if the ant has reached the target position, false otherwise
	func is_completed() -> bool:
		return ant.global_position.distance_to(target_position) < 1.0

## Action for harvesting food
class Harvest extends Action:
	## The food source to harvest from
	var food_source: Food
	## Harvesting rate of the ant
	var harvest_rate: float
	
	## Initialize the HarvestAction
	## @param _food_source The food source to harvest from
	func _init_action(params: Dictionary) -> void:
		if "food_source" in params:
			food_source = params["food_source"]
	
	## Start the harvest action
	## @param _ant The ant performing the action
	func start(_ant: Ant, params: Dictionary = {}) -> void:
		super.start(_ant)
		harvest_rate = ant.speed.harvesting_rate
	
	## Update the harvest action
	## @param delta Time elapsed since the last update
	func _update_action(delta: float, params: Dictionary = {}) -> void:
		var food_source = params.get("target_food")
		if food_source:
			var amount_harvested = ant.harvest_food(food_source, delta)
			print("Harvested %f amount of food" % amount_harvested)
		else:
			push_error("No food source to harvest")
	
	## Check if the harvest action is completed
	## @return True if the ant is full or the food source is depleted, false otherwise
	func is_completed() -> bool:
		return not ant.can_carry_more() or food_source.is_depleted()

## Action for storing food in the colony
class Store extends Action:
	## The location where food should be stored
	var storage_location: Vector2
	## The amount of food stored per update
	var store_rate: float = 1.0  # Food units per second
	
	## Initialize the StoreAction
	## @param _storage_location The location to store food
	func _init_action(params: Dictionary = {}):
		if "storage_location" in params:
			storage_location = params["storage_location"]
	
	## Update the store action
	## @param delta Time elapsed since the last update
	func _update_action(delta: float, params = {}) -> void:
		var colony = ant.colony
		ant.store_food(colony, delta)
	
	## Check if the store action is completed
	## @return True if the ant has no more food to store, false otherwise
	func is_completed() -> bool:
		return ant.foods.is_empty()

## Action for attacking another ant or entity
class Attack extends Action:
	## The target location of the attack
	var target_location: Vector2
	## The target entity to attack
	var target_entity: Node2D
	## The attack range of the ant
	var attack_range: float = 10.0
	## The attack damage of the ant
	var attack_damage: float = 1.0
	## The time between attacks
	var attack_cooldown: float = 1.0

	
	## Initialize the AttackAction
	## @param _target_location The location to attack
	## @param _target_entity The entity to attack (optional)
	func _init_action(params: Dictionary) -> void:
		if "target_location" in params:
			target_location = params["target_location"]
		if "target_entity" in params:
			target_entity = params["target_entity"]
	
	## Update the attack action
	## @param delta Time elapsed since the last update
	func update(delta: float, params: Dictionary = {}) -> void:
		if current_cooldown > 0:
			current_cooldown -= delta
			return
		
		if target_entity and ant.global_position.distance_to(target_entity.global_position) <= attack_range:
			perform_attack()
		elif ant.global_position.distance_to(target_location) <= attack_range:
			perform_attack()
		else:
			move_towards_target(delta)
	
	## Perform the attack
	func perform_attack() -> void:
		if target_entity and target_entity.has_method("take_damage"):
			target_entity.take_damage(attack_damage)
		current_cooldown = attack_cooldown
		ant.energy.deplete(0.5)  # Energy cost for attacking
	
	## Move towards the target
	## @param delta Time elapsed since the last update
	func move_towards_target(delta: float) -> void:
		var direction
		if target_entity:
			direction = ant.global_position.direction_to(target_entity.global_position)
		else:
			direction = ant.global_position.direction_to(target_location)
		ant.velocity = direction * ant.speed.movement_rate
		ant.energy.deplete(delta * ant.speed.movement_rate * 0.1)
	
	## Check if the attack action is completed
	## @return True if the target is destroyed or the ant is out of energy, false otherwise
	func is_completed() -> bool:
		if target_entity and not is_instance_valid(target_entity):
			return true
		return ant.energy.is_depleted()

## Action for emitting pheromones
class EmitPheromone extends Action:
	## The type of pheromone to emit
	var pheromone_type: String
	## The strength of the pheromone
	var pheromone_strength: float
	## The duration of the pheromone emission
	var emission_duration: float
	## The current emission timer
	var current_time: float = 0.0
	
	## Initialize the EmitPheromoneAction
	## @param _pheromone_type The type of pheromone to emit
	## @param _pheromone_strength The strength of the pheromone
	## @param _emission_duration The duration of the pheromone emission
	func _init_action(params: Dictionary = {}):
		if "pheromone_type" in params:
			pheromone_type = params["pheromone_type"]
		if "pheromone_strength" in params:
			pheromone_strength = params["pheromone_strength"]
		if "emission_duration" in params:
			emission_duration = params["emission_duration"]
	
	## Update the pheromone emission action
	## @param delta Time elapsed since the last update
	func update(delta: float, params: Dictionary = {}) -> void:
		ant.emit_pheromone(pheromone_type, pheromone_strength)
		current_time += delta
		ant.energy.deplete(delta * 0.1)  # Small energy cost for emitting pheromones
	
	## Check if the pheromone emission action is completed
	## @return True if the emission duration has elapsed, false otherwise
	func is_completed() -> bool:
		return current_time >= emission_duration
		
## Action for following pheromones
class FollowPheromone extends Action:
	## The type of pheromone to follow
	var pheromone_type: String
	## The movement speed while following pheromones
	var follow_speed: float = 1.0

	## Initialize the FollowPheromoneAction
	## @param _pheromone_type The type of pheromone to follow
	func _init_action(params: Dictionary = {}):
		if "pheromone_type" in params:
			pheromone_type = params["pheromone_type"]

	## Update the follow pheromone action
	## @param delta Time elapsed since the last update
	func update(delta: float, params: Dictionary = {}) -> void:
		var pheromone_direction = ant.get_strongest_pheromone_direction(pheromone_type)
		ant.velocity = pheromone_direction * follow_speed * ant.speed.movement_rate
		ant.energy.deplete(delta * follow_speed * 0.1)

	## Check if the follow pheromone action is completed
	## @return Always false, as this action continues until interrupted
	func is_completed() -> bool:
		return false

## Action for moving to food
class MoveToFood extends Action:
	var target_food: Food = null
	
	func _init_action(params: Dictionary) -> void:
		if "target_food" in params:
			target_food = params["target_food"]
	
	func _update_action(delta: float, params: Dictionary) -> void:
		if target_food == null and "target_food" in params:
			target_food = params["target_food"]
		
		if target_food:
			var direction = (target_food.global_position - ant.global_position).normalized()
			ant.global_position += direction * ant.speed.movement_rate * delta
	
	func is_completed() -> bool:
		return target_food == null or ant.global_position.distance_to(target_food.global_position) < 1.0

## Action for moving randomly
class RandomMove extends Action:
	## The duration of the random movement
	var move_duration: float = 2.0
	## The current movement timer
	var current_time: float = 0.0
	## The current random direction
	var current_direction: Vector2 = Vector2.ZERO

	## Update the random move action
	## @param delta Time elapsed since the last update
	func update(delta: float, params: Dictionary = {}) -> void:
		current_time += delta
		if current_time >= move_duration or current_direction == Vector2.ZERO:
			current_time = 0
			current_direction = Vector2(randf() * 2 - 1, randf() * 2 - 1).normalized()
		
		ant.velocity = current_direction * ant.speed.movement_rate
		ant.energy.deplete(delta * ant.speed.movement_rate * 0.1)

	## Check if the random move action is completed
	## @return Always false, as this action continues until interrupted
	func is_completed() -> bool:
		return false

## Action for resting to regain energy
class Rest extends Action:
	## The rate at which energy is regained while resting
	var energy_gain_rate: float = 10.0  # Energy units per second

	## Update the rest action
	## @param delta Time elapsed since the last update
	func update(delta: float, params: Dictionary = {}) -> void:
		ant.energy.replenish(energy_gain_rate * delta)

	## Check if the rest action is completed
	## @return True if the ant's energy is full, false otherwise
	func is_completed() -> bool:
		return ant.energy.is_full()
