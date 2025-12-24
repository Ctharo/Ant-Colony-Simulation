class_name SequenceNode
extends BehaviorNode

@export var children: Array[BehaviorNode] = []

# Runs children in order until one fails
func tick(delta: float) -> Status:
    for child in children:
        status = child.tick(delta)
        if status != Status.SUCCESS:
            return status
    
    return Status.SUCCESS

func reset() -> void:
    super.reset()
    for child in children:
        child.reset()