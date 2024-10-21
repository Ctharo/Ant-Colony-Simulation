class_name Behavior
extends RefCounted

## Enum to represent the current state of a behavior
enum BehaviorState {
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
var state: BehaviorState = BehaviorState.INACTIVE

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
	state = BehaviorState.ACTIVE
	current_action_index = 0
	for sub_behavior in sub_behaviors:
		sub_behavior.start(ant)

## Update the behavior, returns true if the behavior is complete or inactive
func update(delta: float, params: Dictionary) -> bool:
	if state != BehaviorState.ACTIVE:
		return true

	if not should_execute(params):
		state = BehaviorState.INACTIVE
		return true

	if current_sub_behavior:
		if current_sub_behavior.update(delta, params):
			current_sub_behavior = null
			return false
		elif current_sub_behavior.state == BehaviorState.FAILED:
			state = BehaviorState.FAILED
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
		state = BehaviorState.COMPLETED
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
	state = BehaviorState.INACTIVE
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
		add_sub_behavior(WanderForFoodBehavior.new())
		add_sub_behavior(FollowPheromonesBehavior.new())
		add_sub_behavior(HarvestFoodBehavior.new())
		add_sub_behavior(ReturnHomeBehavior.new())
		add_sub_behavior(StoreFoodBehavior.new())

## Behavior for wandering when searching for food
class WanderForFoodBehavior extends Behavior:
	func _init():
		name = "Wander for Food"
		conditions.append(Condition.NoFoodPheromoneSensedCondition.new())
		conditions.append(Condition.NotCondition.new(Condition.CarryingFoodCondition.new()))
		actions.append(Action.RandomMoveAction.new())

## Behavior for following food pheromones
class FollowPheromonesBehavior extends Behavior:
	func _init():
		name = "Follow Pheromones"
		conditions.append(Condition.FoodPheromoneNearbyCondition.new())
		conditions.append(Condition.NotCondition.new(Condition.CarryingFoodCondition.new()))
		actions.append(Action.FollowPheromoneAction.new())

## Behavior for harvesting food
class HarvestFoodBehavior extends Behavior:
	func _init():
		name = "Harvest Food"
		conditions.append(Condition.FoodInViewCondition.new())
		conditions.append(Condition.NotCondition.new(Condition.OverloadedWithFoodCondition.new()))
		actions.append(Action.MoveToFoodAction.new())
		actions.append(Action.HarvestAction.new())

## Behavior for returning to the colony
class ReturnHomeBehavior extends Behavior:
	func _init():
		name = "Return Home"
		conditions.append(Condition.CarryingFoodCondition.new())
		add_sub_behavior(FollowHomePheromonesBehavior.new())
		add_sub_behavior(WanderForHomeBehavior.new())

## Behavior for storing food in the colony
class StoreFoodBehavior extends Behavior:
	func _init():
		name = "Store Food"
		conditions.append(Condition.AtHomeCondition.new())
		conditions.append(Condition.CarryingFoodCondition.new())
		actions.append(Action.StoreAction.new())

## Behavior for following home pheromones
class FollowHomePheromonesBehavior extends Behavior:
	func _init():
		name = "Follow Home Pheromones"
		conditions.append(Condition.HomePheromoneNearbyCondition.new())
		conditions.append(Condition.CarryingFoodCondition.new())
		actions.append(Action.FollowPheromoneAction.new())

## Behavior for wandering when searching for home
class WanderForHomeBehavior extends Behavior:
	func _init():
		name = "Wander for Home"
		conditions.append(Condition.NotCondition.new(Condition.HomePheromoneNearbyCondition.new()))
		conditions.append(Condition.CarryingFoodCondition.new())
		actions.append(Action.RandomMoveAction.new())

## Behavior for emitting food pheromones
class EmitFoodPheromonesBehavior extends Behavior:
	func _init():
		name = "Emit Food Pheromones"
		conditions.append(Condition.CarryingFoodCondition.new())
		actions.append(Action.EmitPheromoneAction.new())

## Behavior for resting when energy is low
class RestBehavior extends Behavior:
	func _init():
		name = "Rest"
		conditions.append(Condition.LowEnergyCondition.new())
		conditions.append(Condition.AtHomeCondition.new())
		actions.append(Action.RestAction.new())
