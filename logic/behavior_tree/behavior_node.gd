class_name BehaviorNode
extends Resource

enum Status { RUNNING, SUCCESS, FAILURE }

var status: Status = Status.FAILURE
var ant: Ant

func initialize(p_ant: Ant) -> void:
	ant = p_ant

func tick(delta: float) -> Status:
	return Status.FAILURE

func reset() -> void:
	status = Status.FAILURE
