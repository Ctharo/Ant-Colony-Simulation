class_name Action
extends Resource

#region Properties
var id: String
@export var name: String :
	set(value):
		name = value
		id = name.to_snake_case()

## Priority level - higher numbers mean higher priority
@export_range(0, 100) var priority: int = 0

## Description of what this action does
@export var description: String

## Time before action can be used again
@export var cooldown: float = 0.0

## How long the action takes to complete
@export var duration: float = 0.0

## How much energy does this action cost per second
@export var energy_coefficient: float

## Parameters required for this action
@export var params: Dictionary = {}

#region Protected
@export var start_condition: Logic
@export var stop_condition: Logic
@export var interrupt_condition: Logic
#endregion

#region Signals
signal action_interrupted(action: Action, entity: Node)
#endregion

## Get whether conditions are met to start this action
func can_start(entity: Node) -> bool:
	if not start_condition:
		return false
	return start_condition.get_value(entity.action_manager.evaluation_system)

## Get whether the action should be stopped
func should_stop(entity: Node) -> bool:
	if not stop_condition:
		return false
	return stop_condition.get_value(entity.action_manager.evaluation_system)

## Check if the action should be interrupted
func should_interrupt(entity: Node) -> bool:
	if not interrupt_condition:
		return false
	return interrupt_condition.get_value(entity.action_manager.evaluation_system)

## Check if the action can be executed
func can_execute(entity: Node) -> bool:
	return can_start(entity)

func execute_tick(entity: Node, state: ActionState, delta: float) -> void:
	# Check for interrupts first
	if should_interrupt(entity):
		if not state.is_interrupted:  # Only emit signal on initial interrupt
			action_interrupted.emit(self, entity)
		state.is_interrupted = true
		return

	# Clear interrupt state if conditions no longer met
	if state.is_interrupted:
		state.is_interrupted = false

	energy_loss(entity, energy_coefficient * delta)
	_update_execution(entity, state, delta)

#region Protected Methods
## Validate action parameters (override in subclasses)
func _validate_params() -> bool:
	return true

## Update the action execution (override in subclasses)
func _update_execution(_entity: Node, _state: ActionState, _delta: float) -> void:
	pass

func energy_loss(entity: Node, amount: float) -> void:
	entity.energy_level -= amount
#endregion
