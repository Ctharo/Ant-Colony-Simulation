class_name SelectorNode
extends BehaviorNode

@export var children: Array[BehaviorNode] = []

# Runs children in order until one succeeds
func tick(delta: float) -> Status:
    for child in children:
        status = child.tick(delta)
        if status != Status.FAILURE:
            return status
    
    return Status.FAILURE

func reset() -> void:
    super.reset()
    for child in children:
        child.reset()