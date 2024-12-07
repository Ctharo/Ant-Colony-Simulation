class_name Action
extends RefCounted

#region Signals
signal started
signal completed
signal interrupted
#endregion

#region Properties
var cooldown: float = 0.0
var duration: float
var current_cooldown: float = 0.0
var params: Dictionary = {}:
	set(value):
		params = value

var name: String
var base_name: String
var description: String

var logger: Logger
var _is_executing: bool = false
var _elapsed_time: float = 0.0
#endregion

#region Builder
class Builder:
	var action_class: GDScript
	var name: String
	var params: Dictionary = {}
	var duration: float
	var cooldown: float
	var description: String

	func _init(_action_class: GDScript):
		action_class = _action_class

	func with_name(_name: String) -> Builder:
		name = _name
		return self

	func with_params(parameters: Dictionary) -> Builder:
		params = parameters
		return self

	func with_description(_description: String) -> Builder:
		description = _description
		return self

	func with_duration(time: float) -> Builder:
		duration = time
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
		action.params = params
		return action
#endregion

func _init():
	logger = Logger.new("action", DebugLogger.Category.ACTION)

#region Core Action Methods
func can_execute(ant: Ant) -> bool:
	return is_ready() and _validate_params(ant)

func execute(delta: float, ant: Ant) -> void:
	if not _is_executing:
		_start_execution(ant)
		return
		
	_update_execution(delta, ant)

func stop() -> void:
	_is_executing = false
	interrupted.emit()

func reset() -> void:
	current_cooldown = 0.0
	_is_executing = false
	_elapsed_time = 0.0

func is_ready() -> bool:
	return current_cooldown <= 0

func is_completed() -> bool:
	return not _is_executing
#endregion

#region Protected Methods - Override in subclasses
func _validate_params(ant: Ant) -> bool:
	return true

func _start_execution(ant: Ant) -> void:
	_is_executing = true
	current_cooldown = cooldown
	started.emit()

func _update_execution(delta: float, ant: Ant) -> void:
	pass

func _complete_execution() -> void:
	if _is_executing:
		_is_executing = false
		_elapsed_time = 0.0
		completed.emit()
#endregion

#region Action Classes
#region Action Classes
class Move extends Action:
	const LOOK_AHEAD_DISTANCE = 50.0
	const INTERMEDIATE_TARGET_THRESHOLD = 5.0

	var _ultimate_target: Vector2
	var _current_intermediate_target: Vector2

	func _init():
		super()
		base_name = "move"
		logger = Logger.new("Action: move", DebugLogger.Category.ACTION)

	static func create() -> Builder:
		return Builder.new(Move)

	func _validate_params(ant: Ant) -> bool:
		var target = ant.get_property_value("proprioception.base.target_position")
		return target != null

	func _start_execution(ant: Ant) -> void:
		super._start_execution(ant)
		
		_ultimate_target = ant.get_property_value("proprioception.base.target_position")
		_set_next_intermediate_target(ant)

	func _update_execution(delta: float, ant: Ant) -> void:
		if not ant.nav_agent:
			_complete_execution()
			return

		if ant.global_position.distance_to(_current_intermediate_target) <= INTERMEDIATE_TARGET_THRESHOLD:
			if ant.global_position.distance_to(_ultimate_target) <= INTERMEDIATE_TARGET_THRESHOLD:
				ant.set_property_value("proprioception.status.at_target", true)
				_complete_execution()
				return
			_set_next_intermediate_target(ant)

		var next_path_position: Vector2 = ant.nav_agent.get_next_path_position()
		var direction = ant.global_position.direction_to(next_path_position)
		ant.velocity = direction * ant.get_property_value("speed.base.value")

	func _set_next_intermediate_target(ant: Ant) -> void:
		if not ant.nav_agent:
			return

		var direction = ant.global_position.direction_to(_ultimate_target)

		if ant.global_position.distance_to(_ultimate_target) <= LOOK_AHEAD_DISTANCE:
			_current_intermediate_target = _ultimate_target
		else:
			_current_intermediate_target = ant.global_position + direction * LOOK_AHEAD_DISTANCE

		ant.nav_agent.target_position = _current_intermediate_target
		logger.trace("Set new intermediate target: %s" % _current_intermediate_target)

class Harvest extends Action:
	func _init():
		super()
		base_name = "harvest"
		logger = Logger.new("Action: harvest", DebugLogger.Category.ACTION)

	static func create() -> Builder:
		return Builder.new(Harvest)

	func _validate_params(ant: Ant) -> bool:
		return ant.can_perform_action("harvest", params)

	func _update_execution(delta: float, ant: Ant) -> void:
		var result: Result = await ant.perform_action(self, params)
		if result.success():
			_complete_execution()

class FollowPheromone extends Action:
	func _init():
		super()
		base_name = "follow_pheromone"
		logger = Logger.new("Action: follow_pheromone", DebugLogger.Category.ACTION)

	static func create() -> Builder:
		return Builder.new(FollowPheromone)

	func _validate_params(ant: Ant) -> bool:
		return ant.can_perform_action("follow_pheromone", params)

	func _update_execution(delta: float, ant: Ant) -> void:
		var result: Result = await ant.perform_action(self, params)
		if result.success():
			_complete_execution()

class RandomMove extends Action:
	func _init():
		super()
		base_name = "random_move"
		logger = Logger.new("Action: random_move", DebugLogger.Category.ACTION)

	static func create() -> Builder:
		return Builder.new(RandomMove)

	func _validate_params(ant: Ant) -> bool:
		return ant.can_perform_action("random_move", params)

	func _update_execution(delta: float, ant: Ant) -> void:
		var result: Result = await ant.perform_action(self, params)
		if result.success():
			_complete_execution()

class Store extends Action:
	func _init():
		super()
		base_name = "store"
		logger = Logger.new("Action: store", DebugLogger.Category.ACTION)

	static func create() -> Builder:
		return Builder.new(Store)

	func _validate_params(ant: Ant) -> bool:
		return ant.can_perform_action("store", params)

	func _update_execution(delta: float, ant: Ant) -> void:
		var result: Result = await ant.perform_action(self, params)
		if result.success():
			_complete_execution()

class Rest extends Action:
	func _init():
		super()
		base_name = "rest"
		logger = Logger.new("Action: rest", DebugLogger.Category.ACTION)

	static func create() -> Builder:
		return Builder.new(Rest)

	func _validate_params(ant: Ant) -> bool:
		return ant.can_perform_action("rest", params)

	func _update_execution(delta: float, ant: Ant) -> void:
		var result: Result = await ant.perform_action(self, params)
		if result.success():
			_complete_execution()
#endregion
