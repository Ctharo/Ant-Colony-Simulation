class_name BehaviorBuilder
## Builder class for constructing behaviors

var behavior: Behavior
var behavior_class: GDScript
var _priority: Behavior.Priority
var _conditions: Array[Condition] = []
var _actions: Array[Action] = []
var _sub_behaviors: Array[Dictionary] = []  # Array of {behavior: Behavior, priority: Priority}

func _init(b_class: GDScript, p: Behavior.Priority) -> void:
	behavior_class = b_class
	_priority = p

## Add a condition to the behavior
func with_condition(condition: Condition) -> BehaviorBuilder:
	_conditions.append(condition)
	return self

## Add an action to the behavior
func with_action(action: Action) -> BehaviorBuilder:
	_actions.append(action)
	return self

## Add a sub-behavior with custom priority
func with_sub_behavior(sub_behavior: Behavior, priority: Behavior.Priority = Behavior.Priority.MEDIUM) -> BehaviorBuilder:
	_sub_behaviors.append({"behavior": sub_behavior, "priority": priority})
	return self

## Build and return the configured behavior
func build() -> Behavior:
	behavior = behavior_class.new(_priority)
	
	# Add conditions
	for condition in _conditions:
		behavior.add_condition(condition)
	
	# Add actions
	for action in _actions:
		behavior.add_action(action)
			
	return behavior
