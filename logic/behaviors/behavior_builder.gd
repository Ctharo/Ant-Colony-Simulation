class_name BehaviorBuilder
extends RefCounted
## Builder class for constructing complex behaviors with fluent interface

## The behavior being constructed
var behavior: Behavior

## The behavior class to instantiate
var behavior_class: GDScript

## Priority level for the behavior
var _priority: int

## Name for the behavior (optional)
var _name: String = ""

## Actions this behavior will perform
var _actions: Array[Action] = []

## Conditions that must be met for the behavior to be active
var _conditions: Array[Dictionary] = []

## Reference to the ant that will perform this behavior
var _ant: Ant

## Initialize the builder with behavior class and priority
## @param b_class The behavior class to instantiate
## @param priority The priority level for this behavior
func _init(b_class: GDScript, priority: int = Behavior.Priority.MEDIUM) -> void:
	behavior_class = b_class
	_priority = priority

## Set a name for the behavior
## @param name The name to give this behavior
## @return The builder for method chaining
func with_name(name: String) -> BehaviorBuilder:
	_name = name
	return self

## Add an action to the behavior
## @param action The action to add
## @return The builder for method chaining
func with_action(action: Action) -> BehaviorBuilder:
	_actions.append(action)
	return self

## Add multiple actions to the behavior
## @param actions Array of actions to add
## @return The builder for method chaining
func with_actions(actions: Array[Action]) -> BehaviorBuilder:
	_actions.append_array(actions)
	return self

## Add a condition to the behavior
## @param condition The condition configuration to add
## @return The builder for method chaining
func with_condition(condition: Dictionary) -> BehaviorBuilder:
	_conditions.append(condition)
	return self

## Set the ant that will perform this behavior
## @param ant The ant instance
## @return The builder for method chaining
func with_ant(ant: Ant) -> BehaviorBuilder:
	_ant = ant
	return self

## Set the priority level for this behavior
## @param priority The priority level to set
## @return The builder for method chaining
func with_priority(priority: int) -> BehaviorBuilder:
	_priority = priority
	return self

## Build and return the configured behavior
## @return The constructed Behavior instance
func build() -> Behavior:
	# Create new behavior instance
	behavior = behavior_class.new(_priority)
	
	# Set optional name if provided
	if not _name.is_empty():
		behavior.name = _name
	
	# Add ant reference if provided
	if _ant:
		behavior.ant = _ant
	
	# Add all conditions
	for condition in _conditions:
		behavior.add_condition_config(condition)
	
	# Add all actions
	for action in _actions:
		if _ant and not action.ant:
			action.ant = _ant
		behavior.actions.append(action)
	
	return behavior

## Create a new behavior builder
## @param behavior_class The behavior class to build
## @param priority Optional priority level
## @return A new BehaviorBuilder instance
static func create(behavior_class: GDScript, priority: int = Behavior.Priority.MEDIUM) -> BehaviorBuilder:
	return BehaviorBuilder.new(behavior_class, priority)
