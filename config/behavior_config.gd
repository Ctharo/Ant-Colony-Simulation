class_name BehaviorConfig
extends Logic

@export var priority: String = "MEDIUM"
@export var action: ActionConfig

func should_activate() -> bool:
	assert(false)
	return true
