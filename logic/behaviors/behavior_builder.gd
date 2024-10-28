class_name BehaviorBuilder
extends RefCounted
## Builder class for constructing behaviors

## The behavior being built
var behavior: Behavior

## The behavior class to instantiate
var behavior_class: GDScript

## Priority level for the behavior
var _priority: Behavior.Priority

## Conditions that must be met for the behavior to activate
var _conditions: Array[Condition] = []

## Actions this behavior will perform
var _actions: Array[Action] = []

## Initialize the builder with a behavior class and priority
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
