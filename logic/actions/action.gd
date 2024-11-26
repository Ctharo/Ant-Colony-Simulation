class_name Action
extends RefCounted
## Interface between [class Behavior]s and [class Ant] action methods

## Signals
signal started
signal completed
signal interrupted

## Properties
var ant: Ant:
	set(value):
		ant = value

var cooldown: float = 0.0:
	set(value):
		cooldown = value

var current_cooldown: float = 0.0:
	set(value):
		current_cooldown = value

var params: Dictionary = {}:
	set(value):
		params = value

var name: String

var logger: Logger

var arguments: Dictionary = {}

## Builder class for constructing actions
class Builder:
	var action: Action
	var ant: Ant
	var params: Dictionary = {}

	func _init(action_class: GDScript):
		action = action_class.new()

	func with_param(key: String, value: Variant) -> Builder:
		params[key] = value
		return self

	func with_ant(_ant: Ant) -> Builder:
		ant = _ant
		action.ant = ant
		return self

	func with_cooldown(time: float) -> Builder:
		action.cooldown = time
		return self

	func build() -> Action:
		action.params = params
		return action

func _init():
	logger = Logger.new("action", DebugLogger.Category.ACTION)

## Core Action Methods
func start(_ant: Ant) -> void:
	ant = _ant
	current_cooldown = cooldown
	started.emit()

func update(delta: float) -> void:
	if current_cooldown > 0:
		current_cooldown -= delta
	_update_action(delta)

func _update_action(_delta: float) -> void:
	pass

func is_completed() -> bool:
	return true

func cancel() -> void:
	pass

func interrupt() -> void:
	cancel()
	current_cooldown = cooldown
	interrupted.emit()

func reset() -> void:
	current_cooldown = 0.0

func is_ready() -> bool:
	return current_cooldown <= 0

## Action Classes
class Move extends Action:
	func _init():
		name = "move"
		logger = Logger.new("Action: move", DebugLogger.Category.ACTION)
		arguments = {
			description = "moving toward a target",
			target = "position %s",
			velocity = "with velocity of %.2f",
			direction = "in direction %s"
		}
		
	static func create() -> Builder:
		return Builder.new(Move)

	func _update_action(delta: float) -> void:
		if not "target_position" in params:
			logger.error("Move action requires target_position")
			return

		var target_position = params["target_position"]
		var movement_rate_modifier = params.get("rate_modifier", 1.0)
		var direction = ant.global_position.direction_to(target_position)
		ant.velocity = direction * movement_rate_modifier * ant.speed.movement_rate
		ant.perform_action(self, arguments)

	func is_completed() -> bool:
		if not "target_position" in params:
			return true
		return ant.global_position.distance_to(params["target_position"]) < 1.0

class Harvest extends Action:
	var current_food_source: Food
	
	func _init():
		name = "harvest"

		logger = Logger.new("Action: harvest", DebugLogger.Category.ACTION)
		arguments = {
			description = "harvesting resources",
			source = "from %s",
			rate = "at rate %.2f/s",
			capacity = "storage: %.2f/%.2f",
			remaining = "food remaining: %.2f"
		}
		
	static func create() -> Builder:
		return Builder.new(Harvest)

	func _update_action(delta: float) -> void:
		if not "target_food" in params:
			logger.error("Harvest action requires target_food parameter")
			return

		current_food_source = params["target_food"]
		if current_food_source and not current_food_source.is_depleted():
			var harvest_rate_modifier = params.get("harvest_rate_modifier", 1.0)
			var harvest_rate = delta * harvest_rate_modifier * ant.speed.harvesting_rate
			ant.perform_action(self, arguments)
		else:
			logger.error("No valid food source to harvest")

	func is_completed() -> bool:
		if not current_food_source:
			return true
		return not ant.can_carry_more() or current_food_source.is_depleted()

class FollowPheromone extends Action:
	func _init():
		name = "follow_pheromone"
		arguments = {
				description = "following pheromone trail",
				type = "type: %s",
				concentration = "concentration: %.2f",
				direction = "direction: %s",
				strength = "signal strength: %.2f"
		}
		logger = Logger.new("Action: follow_pheromone", DebugLogger.Category.ACTION)
 
		
	static func create() -> Builder:
		return Builder.new(FollowPheromone)

	func _update_action(delta: float) -> void:
		if not "pheromone_type" in params:
			logger.error("FollowPheromone action requires pheromone_type parameter")
			return
			
		var pheromone_type = params["pheromone_type"]
		var concentration = params.get("concentration", 0.0)
		var direction = params.get("direction", Vector2.ZERO)
		
		ant.perform_action(self, arguments)

	func is_completed() -> bool:
		return false

class RandomMove extends Action:
	var current_time: float = 0.0
	var current_direction: Vector2 = Vector2.ZERO
	
	func _init():
		name = "random_move"
		arguments = {
			description = "moving randomly",
			direction = "direction: %s",
			duration = "duration: %.1f/%.1f",
			distance = "distance traveled: %.2f",
			speed = "current speed: %.2f"
		}
		logger = Logger.new("Action: random_move", DebugLogger.Category.ACTION)

		
	static func create() -> Builder:
		return Builder.new(RandomMove)

	func _update_action(delta: float) -> void:
		current_time += delta
		var move_duration = params.get("move_duration", 2.0)
		
		if current_time >= move_duration or current_direction == Vector2.ZERO:
			current_time = 0
			current_direction = Vector2(randf() * 2 - 1, randf() * 2 - 1).normalized()

		ant.perform_action(self, arguments)

	func is_completed() -> bool:
		return false

class Store extends Action:
	func _init():
		name = "store"
		arguments = {
			description = "storing resources in colony",
			rate = "at rate %.2f/s",
			remaining = "remaining to store: %.2f",
			total_stored = "total stored: %.2f",
			efficiency = "storage efficiency: %.2f%%"
		}
		logger = Logger.new("Action: store", DebugLogger.Category.ACTION)

	
	static func create() -> Builder:
		return Builder.new(Store)

	func _update_action(delta: float) -> void:
		var store_rate_modifier = params.get("store_rate_modifier", 1.0)
		var store_rate = delta * store_rate_modifier * ant.speed.storing_rate
		var food_mass = ant.foods.mass()
		
		ant.perform_action(self, arguments)

	func is_completed() -> bool:
		return ant.foods.is_empty()

class Attack extends Action:
	var current_target_entity: Node2D
	var current_target_location: Vector2
	
	func _init():
		name = "attack"
		arguments = {
			description = "engaging in combat",
			target = "target: %s",
			distance = "at range %.1f",
			cooldown = "cooldown: %.1f",
			damage = "damage: %.1f",
			attack_range = "attack range: %.1f",
			status = "status: %s"  # For "moving to range" or "attacking"
		}
		logger = Logger.new("Action: attack", DebugLogger.Category.ACTION)

		
	static func create() -> Builder:
		return Builder.new(Attack)

	func _update_action(delta: float) -> void:
		if not ("target_entity" in params or "target_location" in params):
			logger.error("Attack action requires either target_entity or target_location")
			return

		if not is_ready():
			return

		current_target_entity = params.get("target_entity")
		current_target_location = params.get("target_location", Vector2.ZERO)
		var attack_range_modifier = params.get("attack_range_modifier", 1.0)
		var attack_range = attack_range_modifier * ant.reach.distance

		if current_target_entity and is_instance_valid(current_target_entity):
			var distance = ant.global_position.distance_to(current_target_entity.global_position)
			ant.perform_action(self, arguments)
			
		elif current_target_location != Vector2.ZERO:
			var distance = ant.global_position.distance_to(current_target_location)
			if distance <= attack_range:
				ant.perform_action(self, arguments)
		current_cooldown = params.get("attack_cooldown", 1.0)

	func is_completed() -> bool:
		if current_target_entity and not is_instance_valid(current_target_entity):
			return true
		return ant.energy.is_depleted()

class EmitPheromone extends Action:
	var current_time: float = 0.0

	func _init():
		name = "emit_pheromone"
		arguments = {
			description = "emitting pheromone signal",
			type = "type: %s",
			strength = "strength: %.2f",
			duration = "duration: %.1f/%.1f",
			radius = "radius: %.2f",
			concentration = "concentration: %.2f"
		}
		logger = Logger.new("Action: emit_pheromone", DebugLogger.Category.ACTION)



	static func create() -> Builder:
		return Builder.new(EmitPheromone)

	func _update_action(delta: float) -> void:
		if not "pheromone_type" in params:
			logger.error("EmitPheromone action requires pheromone_type parameter")
			return

		if not "emission_duration" in params:
			logger.error("EmitPheromone action requires emission_duration parameter")
			return

		var pheromone_type = params["pheromone_type"]
		var pheromone_strength = params.get("pheromone_strength", 1.0)
		current_time += delta
		
		ant.perform_action(self, arguments)
		ant.emit_pheromone(pheromone_type, pheromone_strength)

	func is_completed() -> bool:
		return current_time >= params.get("emission_duration", 0.0)

class Rest extends Action:
	func _init():
		name = "rest"
		logger = Logger.new("Action: rest", DebugLogger.Category.ACTION)
		arguments = {
			description = "resting to recover",
			gain_rate = "energy gain: %.2f/s",
			current = "current energy: %.1f",
			maximum = "maximum energy: %.1f",
			recovery = "recovery progress: %.1f%%",
			duration = "rest duration: %.1f"
		}
		
	static func create() -> Builder:
		return Builder.new(Rest)

	func _update_action(delta: float) -> void:
		var energy_gain_rate = params.get("energy_gain_rate", 10.0)
		var energy_gain = energy_gain_rate * delta
		
		ant.perform_action(self, arguments)
		ant.energy.replenish(energy_gain)

	func is_completed() -> bool:
		return ant.energy.is_full()
