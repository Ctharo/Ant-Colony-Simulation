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

var duration: float = 1.0

var current_cooldown: float = 0.0:
	set(value):
		current_cooldown = value

var params: Dictionary = {}:
	set(value):
		params = value

var name: String

var logger: Logger

var arguments: Dictionary = {}

## Whether the action is currently executing
var _is_executing: bool = false

## Builder class for constructing actions
class Builder:
	var action: Action
	var ant: Ant
	var params: Dictionary = {}
	var duration: float

	func _init(action_class: GDScript):
		action = action_class.new()

	func with_param(key: String, value: Variant) -> Builder:
		params[key] = value
		return self
		
	func with_duration(time: float) -> Builder:
		duration = time
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
	_is_executing = true
	
	# Connect to ant's action completion signal
	if not ant.action_completed.is_connected(_on_ant_action_completed):
		ant.action_completed.connect(_on_ant_action_completed)
	
	started.emit()

func update(delta: float) -> void:
	if current_cooldown > 0:
		current_cooldown -= delta
	if _is_executing and current_cooldown <= 0:
		_update_action(delta)

func _update_action(_delta: float) -> void:
	pass

func is_completed() -> bool:
	return not _is_executing

func cancel() -> void:
	_is_executing = false
	if ant and ant.action_completed.is_connected(_on_ant_action_completed):
		ant.action_completed.disconnect(_on_ant_action_completed)

func interrupt() -> void:
	cancel()
	current_cooldown = cooldown
	interrupted.emit()

func reset() -> void:
	current_cooldown = 0.0
	_is_executing = false
	if ant and ant.action_completed.is_connected(_on_ant_action_completed):
		ant.action_completed.disconnect(_on_ant_action_completed)

func is_ready() -> bool:
	return current_cooldown <= 0

## Called when the ant completes the action
func _on_ant_action_completed() -> void:
	_is_executing = false
	completed.emit()
	# Disconnect from signal to prevent multiple completions
	if ant and ant.action_completed.is_connected(_on_ant_action_completed):
		ant.action_completed.disconnect(_on_ant_action_completed)

## Action Classes
class Move extends Action:
	func _init():
		name = "move"
		logger = Logger.new("Action: move", DebugLogger.Category.ACTION)
		arguments = {
			description = "moving toward a target",
			args = [
				"toward position %s",
				"with velocity of %s"
			]
		}
		
	static func create() -> Builder:
		return Builder.new(Move)

	func _update_action(delta: float) -> void:
		ant.perform_action(self, arguments)

class Harvest extends Action:
	func _init():
		name = "harvest"
		logger = Logger.new("Action: harvest", DebugLogger.Category.ACTION)
		arguments = {
			description = "harvesting resources",
			args = [
				"harvesting from %s",
				"at rate %.2f/s",
				"current capacity: %.2f/%.2f"
			]
		}
		
	static func create() -> Builder:
		return Builder.new(Harvest)

	func _update_action(delta: float) -> void:
		ant.perform_action(self, arguments)

		
class FollowPheromone extends Action:
	func _init():
		name = "follow_pheromone"
		logger = Logger.new("Action: follow_pheromone", DebugLogger.Category.ACTION)
		arguments = {
			description = "following pheromone trail",
			args = [
				"following %s pheromone",
				"concentration: %.2f",
				"direction: %s"
			]
		}
		
	static func create() -> Builder:
		return Builder.new(FollowPheromone)

	func _update_action(delta: float) -> void:
		ant.perform_action(self, arguments)


class RandomMove extends Action:
	func _init():
		name = "random_move"
		logger = Logger.new("Action: random_move", DebugLogger.Category.ACTION)
		arguments = {
			description = "moving randomly",
			args = [
				"direction: %s",
				"duration: %.1f/%.1f"
			]
		}
		
	static func create() -> Builder:
		return Builder.new(RandomMove)

	func _update_action(delta: float) -> void:
		ant.perform_action(self, arguments)

class Store extends Action:
	func _init():
		name = "store"
		logger = Logger.new("Action: store", DebugLogger.Category.ACTION)
		arguments = {
			description = "storing resources",
			args = [
				"storing food in colony",
				"at rate %.2f/s",
				"remaining to store: %.2f"
			]
		}
	
	static func create() -> Builder:
		return Builder.new(Store)

	func _update_action(delta: float) -> void:
		ant.perform_action(self, arguments)

class Attack extends Action:
	func _init():
		name = "attack"
		logger = Logger.new("Action: attack", DebugLogger.Category.ACTION)
		arguments = {
			description = "engaging in combat",
			args = [
				"attacking %s",
				"at range %.1f",
				"cooldown: %.1f",
				"attack range: %.1f"
			]
		}

	static func create() -> Builder:
		return Builder.new(Attack)

	func _update_action(delta: float) -> void:
		ant.perform_action(self, arguments)


class EmitPheromone extends Action:
	func _init():
		name = "emit_pheromone"
		logger = Logger.new("Action: emit_pheromone", DebugLogger.Category.ACTION)
		arguments = {
			description = "emitting pheromone signal",
			args = [
				"emitting %s pheromone",
				"strength: %.2f",
				"duration: %.1f/%.1f"
			]
		}

	static func create() -> Builder:
		return Builder.new(EmitPheromone)

	func _update_action(delta: float) -> void:
		ant.perform_action(self, arguments)


class Rest extends Action:
	func _init():
		name = "rest"
		logger = Logger.new("Action: rest", DebugLogger.Category.ACTION)
		arguments = {
			description = "resting to recover energy",
			args = [
				"gain rate: %.2f/s",
				"current energy: %.1f/%.1f"
			]
		}
		
	static func create() -> Builder:
		return Builder.new(Rest)

	func _update_action(delta: float) -> void:
		ant.perform_action(self, arguments)
