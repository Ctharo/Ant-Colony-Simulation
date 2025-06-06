class_name StoreFoodNode
extends BehaviorNode

@export var store_time: float = 1.0
var timer: float = 0.0

func tick(delta: float) -> Status:
    if not is_instance_valid(ant) or not ant.is_carrying_food:
        return Status.FAILURE
    
    # Check if we're at a colony
    if not ant.is_in_colony():
        return Status.FAILURE
    
    # Store process
    timer += delta
    if timer >= store_time:
        # Store complete
        ant.store_food()
        timer = 0.0
        return Status.SUCCESS
    
    return Status.RUNNING

func reset() -> void:
    super.reset()
    timer = 0.0