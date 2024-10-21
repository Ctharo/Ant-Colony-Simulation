class_name AntBehavior
extends RefCounted

enum BehaviorState {
	INACTIVE,
	ACTIVE,
	COMPLETED,
	FAILED
}

var id: String
var name: String
var conditions: Array[Condition] = []
var sub_behaviors: Array[AntBehavior] = []
var actions: Array[AntAction] = []
var ant: Ant
var state: BehaviorState = BehaviorState.INACTIVE
var current_sub_behavior: AntBehavior = null
var current_action_index: int = 0
## Cache for condition results during a single update cycle
var condition_cache: Dictionary

func start(_ant: Ant) -> void:
	ant = _ant
	condition_cache.clear()
	state = BehaviorState.ACTIVE
	current_action_index = 0
	for sub_behavior in sub_behaviors:
		sub_behavior.start(ant)

func update(delta: float) -> bool:
	if state != BehaviorState.ACTIVE:
		return true  # Changed: return true if inactive, completed, or failed
	
	if not should_execute():
		state = BehaviorState.INACTIVE
		return true  # Changed: return true when becoming inactive
	
	if current_sub_behavior:
		if current_sub_behavior.update(delta):
			current_sub_behavior = null
			return false  # Sub-behavior completed, but this behavior isn't done yet
		elif current_sub_behavior.state == BehaviorState.FAILED:
			state = BehaviorState.FAILED
			return true  # Return true when failed
		else:
			return false
	
	if current_action_index < actions.size():
		var action = actions[current_action_index]
		if action.is_completed():
			current_action_index += 1
			return false  # Action completed, but behavior isn't done yet
		else:
			action.update(delta)
			return false
	else:
		state = BehaviorState.COMPLETED
		return true  # Behavior is completed
	
	return false  # This line should never be reached

func should_execute() -> bool:
	for condition in conditions:
		if not condition.is_met(ant, condition_cache):
			return false
	return true

func add_sub_behavior(behavior: AntBehavior) -> void:
	sub_behaviors.append(behavior)

func add_action(action: AntAction) -> void:
	actions.append(action)

## Clear the condition cache at the end of each update cycle
func clear_condition_cache() -> void:
	condition_cache.clear()
