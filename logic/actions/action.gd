class_name Action
extends Resource

#region Constants
const State = {
	INACTIVE = "INACTIVE",
	ACTIVE = "ACTIVE",
	COMPLETED = "COMPLETED",
	INTERRUPTED = "INTERRUPTED"
}

const Priority = {
	"LOWEST": 0,
	"LOW": 25,
	"MEDIUM": 50,
	"HIGH": 75,
	"HIGHEST": 100
}
#endregion

#region Properties
## Unique identifier for this action
@export var id: String
## Priority level for action execution
@export_enum("LOWEST", "LOW", "MEDIUM", "HIGH", "HIGHEST") var priority: int
## Current state of the action
@export_enum(State.INACTIVE, State.ACTIVE, State.COMPLETED, State.INTERRUPTED) var state: String = State.INACTIVE
## Array of condition IDs that must be met
@export var conditions: Array[String] = []

var ant: Ant
var logger: Logger
#endregion

func _init() -> void:
	logger = Logger.new("action", DebugLogger.Category.LOGIC)

func initialize(p_ant: Ant) -> void:
	ant = p_ant

## Called when action becomes active
func enter() -> void:
	state = State.ACTIVE
	_on_enter()

## Called when action stops being active
func exit() -> void:
	state = State.INACTIVE
	_on_exit()

## Update loop for active actions
func update(delta: float) -> void:
	if state != State.ACTIVE:
		return
	
	if _update(delta):
		state = State.COMPLETED
		exit()

## Override in child classes
func _on_enter() -> void:
	pass

## Override in child classes
func _update(delta: float) -> bool:
	return true

## Override in child classes 
func _on_exit() -> void:
	pass
