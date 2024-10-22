class_name Behavior
extends RefCounted

## Enum to represent the current state of a behavior
enum State {
	INACTIVE,
	ACTIVE,
	COMPLETED,
	FAILED
}

## Unique identifier for this behavior
var id: String

## Name of the behavior
var name: String

## Priority of the behavior (higher values indicate higher priority)
var priority: int = 0

## List of conditions that must be met for this behavior to execute
var conditions: Array[Condition] = []

## List of sub-behaviors that this behavior may execute
var sub_behaviors: Array[Behavior] = []

## List of actions that this behavior will perform
var actions: Array[Action] = []

## Reference to the ant executing this behavior
var ant: Ant

## Current state of the behavior
var state: State = State.INACTIVE

## Currently executing sub-behavior, if any
var current_sub_behavior: Behavior = null

## Index of the current action being executed
var current_action_index: int = 0

## Cache for condition results during a single update cycle
var condition_cache: Dictionary

## Start the behavior for the given ant
func start(_ant: Ant) -> void:
	ant = _ant
	condition_cache.clear()
	state = State.ACTIVE
	current_action_index = 0
	for sub_behavior in sub_behaviors:
		sub_behavior.start(ant)

## Update the behavior, returns true if the behavior is complete or inactive
func update(delta: float, params: Dictionary) -> bool:
	if state != State.ACTIVE:
		return true

	if not should_execute(params):
		state = State.INACTIVE
		return true

	if current_sub_behavior:
		if current_sub_behavior.update(delta, params):
			current_sub_behavior = null
			return false
		elif current_sub_behavior.state == State.FAILED:
			state = State.FAILED
			return true
		else:
			return false

	if current_action_index < actions.size():
		var action = actions[current_action_index]
		if action.is_completed():
			current_action_index += 1
			return false
		else:
			action.update(delta, params)
			return false
	else:
		state = State.COMPLETED
		return true

## Check if all conditions for this behavior are met
func should_execute(params: Dictionary) -> bool:
	for condition in conditions:
		if not condition.is_met(ant, condition_cache, params):
			return false
	return true

## Add a sub-behavior to this behavior
func add_sub_behavior(behavior: Behavior) -> void:
	sub_behaviors.append(behavior)

## Add an action to this behavior
func add_action(action: Action) -> void:
	actions.append(action)

## Clear the condition cache at the end of each update cycle
func clear_condition_cache() -> void:
	condition_cache.clear()

## Reset the behavior to its initial state
func reset() -> void:
	state = State.INACTIVE
	current_sub_behavior = null
	current_action_index = 0
	condition_cache.clear()
	
	for sub_behavior in sub_behaviors:
		sub_behavior.reset()
	
	for action in actions:
		action.reset()


## Base class for food collection behaviors
class CollectFoodBehavior extends Behavior:
	func _init():
		name = "Collect Food"
		add_sub_behavior(WanderForFood.new())
		add_sub_behavior(FollowPheromones.new())
		add_sub_behavior(HarvestFood.new())
		add_sub_behavior(ReturnHome.new())
		add_sub_behavior(StoreFood.new())

## Behavior for wandering when searching for food
class WanderForFood extends Behavior:
	func _init():
		name = "Wander for Food"
		conditions.append(Operator.Not.new(Condition.FoodPheromoneSensed.new()))
		conditions.append(Operator.Not.new(Condition.CarryingFood.new()))
		actions.append(Action.RandomMove.new())

## Behavior for following food pheromones
class FollowPheromones extends Behavior:
	func _init():
		name = "Follow Pheromones"
		conditions.append(Condition.FoodPheromoneSensed.new())
		conditions.append(Operator.Not.new(Condition.CarryingFood.new()))
		actions.append(Action.FollowPheromone.new())

## Behavior for harvesting food
class HarvestFood extends Behavior:
	func _init():
		name = "Harvest Food"
		conditions.append(Condition.FoodInView.new())
		conditions.append(Operator.Not.new(Condition.OverloadedWithFood.new()))
		actions.append(Action.MoveToFood.new())
		actions.append(Action.Harvest.new())

## Behavior for returning to the colony
class ReturnHome extends Behavior:
	func _init():
		name = "Return Home"
		conditions.append(Condition.CarryingFood.new())
		add_sub_behavior(FollowHomePheromones.new())
		add_sub_behavior(WanderForHome.new())

## Behavior for storing food in the colony
class StoreFood extends Behavior:
	func _init():
		name = "Store Food"
		conditions.append(Condition.AtHome.new())
		conditions.append(Condition.CarryingFood.new())
		actions.append(Action.Store.new())

## Behavior for following home pheromones
class FollowHomePheromones extends Behavior:
	func _init():
		name = "Follow Home Pheromones"
		conditions.append(Condition.HomePheromoneSensed.new())
		conditions.append(Condition.CarryingFood.new())
		actions.append(Action.FollowPheromone.new())

## Behavior for wandering when searching for home
class WanderForHome extends Behavior:
	func _init():
		name = "Wander for Home"
		conditions.append(Operator.Not.new(Condition.HomePheromoneSensed.new()))
		conditions.append(Condition.CarryingFood.new())
		actions.append(Action.RandomMove.new())

## Behavior for emitting food pheromones
class EmitFoodPheromonesBehavior extends Behavior:
	func _init():
		name = "Emit Food Pheromones"
		conditions.append(Condition.CarryingFood.new())
		actions.append(Action.EmitPheromone.new())

## Behavior for resting when energy is low
class Rest extends Behavior:
	func _init():
		name = "Rest"
		conditions.append(Condition.LowEnergy.new())
		conditions.append(Condition.AtHome.new())
		actions.append(Action.Rest.new())
