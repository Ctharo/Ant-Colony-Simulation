class_name Action
extends BaseRefCounted
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
	log_category = DebugLogger.Category.ACTION
	log_from = "action"

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
		super._init()
		log_from = "action: move"
		
	static func create() -> Builder:
		return Builder.new(Move)

	func _update_action(delta: float) -> void:
		if not "target_position" in params:
			_error("Move action requires target_position")
			return

		var target_position = params["target_position"]
		var movement_rate_modifier = params.get("rate_modifier", 1.0)
		var direction = ant.global_position.direction_to(target_position)
		ant.velocity = direction * movement_rate_modifier * ant.speed.movement_rate
		ant.perform_action(self, ["toward position %s" % target_position, "with velocity of %s" % ant.velocity.length()])


	func is_completed() -> bool:
		if not "target_position" in params:
			return true
		assert(false, "Is target_position ever in params?")
		return ant.global_position.distance_to(params["target_position"]) < 1.0

class Harvest extends Action:
	var current_food_source: Food
	
	func _init():
		super._init()
		log_from = "action: harvest"
		
	static func create() -> Builder:
		return Builder.new(Harvest)

	func _update_action(delta: float) -> void:
		if not "target_food" in params:
			_error("Harvest action requires target_food parameter")
			return

		current_food_source = params["target_food"]
		if current_food_source and not current_food_source.is_depleted():
			var harvest_rate_modifier = params.get("harvest_rate_modifier", 1.0)
			var amount_harvested = ant.harvest_food(
				current_food_source,
				delta * harvest_rate_modifier * ant.speed.harvesting_rate
			)
			if amount_harvested > 0 and params.get("debug_harvest", false):
				_info("Harvested %f amount of food" % amount_harvested)
		else:
			_error("No valid food source to harvest")

	func is_completed() -> bool:
		if not current_food_source:
			return true
		return not ant.can_carry_more() or current_food_source.is_depleted()

class FollowPheromone extends Action:
	func _init():
		super._init()
		log_from = "action: follow_pheromone"
		
	static func create() -> Builder:
		return Builder.new(FollowPheromone)

	func _update_action(delta: float) -> void:
		if not "pheromone_type" in params:
			_error("FollowPheromone action requires pheromone_type parameter")
			return

		_info("Ant now moving towards higher pheromone concentration")

	func is_completed() -> bool:
		return false

class RandomMove extends Action:
	var current_time: float = 0.0
	var current_direction: Vector2 = Vector2.ZERO
	
	func _init():
		super._init()
		log_from = "action: random_move"
		
	static func create() -> Builder:
		return Builder.new(RandomMove)

	func _update_action(delta: float) -> void:
		current_time += delta
		var move_duration = params.get("move_duration", 2.0)
		
		if current_time >= move_duration or current_direction == Vector2.ZERO:
			current_time = 0
			current_direction = Vector2(randf() * 2 - 1, randf() * 2 - 1).normalized()

		ant.move(current_direction, delta)

	func is_completed() -> bool:
		return false

class Store extends Action:

	func _init():
		super._init()
		log_from = "action: store"
	
	static func create() -> Builder:
		return Builder.new(Store)

	func _update_action(delta: float) -> void:
		var store_rate_modifier = params.get("store_rate_modifier", 1.0)
		ant.store_food(ant.colony, delta * store_rate_modifier * ant.speed.storing_rate)

	func is_completed() -> bool:
		return ant.foods.is_empty()

class Attack extends Action:
	var current_target_entity: Node2D
	var current_target_location: Vector2
	
	func _init():
		super._init()
		log_from = "action: attack"
		
	static func create() -> Builder:
		return Builder.new(Attack)

	func _update_action(delta: float) -> void:
		if not ("target_entity" in params or "target_location" in params):
			_error("Attack action requires either target_entity or target_location")
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

	func is_completed() -> bool:
		if current_target_entity and not is_instance_valid(current_target_entity):
			return true
		return ant.energy.is_depleted()

class EmitPheromone extends Action:
	var current_time: float = 0.0

	func _init():
		super._init()
		log_from = "action: emit_pheromone"

	static func create() -> Builder:
		return Builder.new(EmitPheromone)

	func _update_action(delta: float) -> void:
		if not "pheromone_type" in params:
			_error("EmitPheromone action requires pheromone_type parameter")
			return

		if not "emission_duration" in params:
			_error("EmitPheromone action requires emission_duration parameter")
			return

		var pheromone_type = params["pheromone_type"]
		var pheromone_strength = params.get("pheromone_strength", 1.0)

		ant.perform_action(self, [pheromone_type, pheromone_strength])
		current_time += delta

	func is_completed() -> bool:
		return current_time >= params.get("emission_duration", 0.0)

class Rest extends Action:
	
	func _init():
		super._init()
		log_from = "action: rest"
		
	static func create() -> Builder:
		return Builder.new(Rest)

	func _update_action(delta: float) -> void:
		var energy_gain_rate = params.get("energy_gain_rate", 10.0)
		ant.energy.replenish(energy_gain_rate * delta)

	func is_completed() -> bool:
		return ant.energy.is_full()
