class_name Action
extends RefCounted

signal started
signal completed
signal interrupted

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

var params: Array = []:
	set(value):
		params = value
		_apply_params()

var name: String
var base_name: String
var description: String

var logger: Logger
var _is_executing: bool = false

#region Builder
class Builder:
	var action_class: GDScript
	var name: String
	var ant: Ant
	var params: Array = []
	var duration: float
	var cooldown: float
	var description: String

	func _init(_action_class: GDScript):
		action_class = _action_class

	func with_name(_name: String) -> Builder:
		name = _name
		return self

	func with_params(parameters: Array) -> Builder:
		params = parameters
		return self

	func with_description(_description: String) -> Builder:
		description = _description
		return self
		
	func with_duration(time: float) -> Builder:
		duration = time
		return self

	func with_ant(_ant: Ant) -> Builder:
		ant = _ant
		return self

	func with_cooldown(time: float) -> Builder:
		cooldown = time
		return self
	
	func build() -> Action:
		var action: Action = action_class.new()
		action.name = name
		action.description = description
		action.cooldown = cooldown
		action.duration = duration
		action.ant = ant
		action.params = params
		return action

func _init():
	logger = Logger.new("action", DebugLogger.Category.ACTION)

#region Params
func _apply_params() -> void:
	if not ant:
		logger.error("Cannot apply params: no ant reference")
		return
		
	if params.is_empty():
		return

	for param in params:
		if not _apply_single_param(param):
			logger.error("Failed to apply param: %s" % param)
			return

func _apply_single_param(param: Dictionary) -> bool:
	if not param.has_all(["type", "property", "property_value"]):
		logger.error("Param missing required fields: %s" % param)
		return false

	var param_type = param.get("type")
	var property = param.get("property")
	var property_value = param.get("property_value")
	
	match param_type:
		"target_position":
			return _handle_target_position(property, property_value)
		"speed":
			return _handle_speed(property, property_value)
		"pheromone":
			return _handle_pheromone(property, property_value)
		"none":
			return true
		_:
			logger.error("Unknown param type: %s" % param_type)
			return false

func _handle_target_position(property: String, value: Variant) -> bool:
	if value == "random":
		var random_offset = Vector2(
			randf_range(-50, 50),
			randf_range(-50, 50)
		)
		var target = ant.global_position + random_offset
		return ant.set_property_value(property, target).success()
		
	if value is String and value.contains("."):
		var pos = ant.get_property_value(value)
		if pos == null:
			logger.error("Failed to get position from path: %s" % value)
			return false
		return ant.set_property_value(property, pos).success()
		
	return ant.set_property_value(property, value).success()

func _handle_speed(property: String, value: Variant) -> bool:
	return ant.set_property_value(property, value).success()

func _handle_pheromone(property: String, value: Variant) -> bool:
	return ant.set_property_value(property, value).success()

#region Core Action Methods
func start(_ant: Ant) -> void:
	ant = _ant
	current_cooldown = cooldown
	_is_executing = true
	
	if not ant.action_completed.is_connected(_on_ant_action_completed):
		ant.action_completed.connect(_on_ant_action_completed)
	
	started.emit()

func update(delta: float) -> void:
	if is_completed():
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

func _on_ant_action_completed() -> void:
	_is_executing = false
	completed.emit()
	if ant and ant.action_completed.is_connected(_on_ant_action_completed):
		ant.action_completed.disconnect(_on_ant_action_completed)

#region Action Classes
class Move extends Action:
	func _init():
		super()
		base_name = "move"
		logger = Logger.new("Action: move", DebugLogger.Category.ACTION)

	static func create() -> Builder:
		return Builder.new(Move)

	func _update_action(delta: float) -> void:
		ant.perform_action(self, params)

class Harvest extends Action:
	func _init():
		super()
		base_name = "harvest"
		logger = Logger.new("Action: harvest", DebugLogger.Category.ACTION)
		
	static func create() -> Builder:
		return Builder.new(Harvest)

	func _update_action(delta: float) -> void:
		ant.perform_action(self, params)

class FollowPheromone extends Action:
	func _init():
		super()
		base_name = "follow_pheromone"
		logger = Logger.new("Action: follow_pheromone", DebugLogger.Category.ACTION)
		
	static func create() -> Builder:
		return Builder.new(FollowPheromone)

	func _update_action(delta: float) -> void:
		ant.perform_action(self, params)

class RandomMove extends Action:
	func _init():
		super()
		base_name = "random_move"
		logger = Logger.new("Action: random_move", DebugLogger.Category.ACTION)
		
	static func create() -> Builder:
		return Builder.new(RandomMove)

	func _update_action(delta: float) -> void:
		ant.perform_action(self, params)

class Store extends Action:
	func _init():
		super()
		base_name = "store"
		logger = Logger.new("Action: store", DebugLogger.Category.ACTION)
	
	static func create() -> Builder:
		return Builder.new(Store)

	func _update_action(delta: float) -> void:
		ant.perform_action(self, params)

class Rest extends Action:
	func _init():
		super()
		base_name = "rest"
		logger = Logger.new("Action: rest", DebugLogger.Category.ACTION)
		
	static func create() -> Builder:
		return Builder.new(Rest)

	func _update_action(delta: float) -> void:
		ant.perform_action(self, params)
