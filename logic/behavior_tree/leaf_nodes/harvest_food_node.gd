class_name HarvestFoodNode
extends BehaviorNode

@export var harvest_time: float = 1.0
var timer: float = 0.0
var target_food: Food = null

func tick(delta: float) -> Status:
    if not is_instance_valid(ant):
        return Status.FAILURE
    
    # If we don't have a target food yet, find the nearest one
    if not is_instance_valid(target_food):
        var foods = ant.get_visible_food()
        if foods.size() > 0:
            target_food = foods[0]
        else:
            return Status.FAILURE
    
    # Check if we're close enough to harvest
    var distance = ant.global_position.distance_to(target_food.global_position)
    if distance > ant.interaction_radius:
        return Status.FAILURE
    
    # Harvest process
    timer += delta
    if timer >= harvest_time:
        # Harvest complete
        if ant.pick_up_food(target_food):
            timer = 0.0
            target_food = null
            return Status.SUCCESS
        else:
            timer = 0.0
            target_food = null
            return Status.FAILURE
    
    return Status.RUNNING

func reset() -> void:
    super.reset()
    timer = 0.0
    target_food = null