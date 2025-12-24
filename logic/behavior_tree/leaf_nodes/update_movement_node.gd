class_name UpdateMovementNode
extends BehaviorNode

func tick(_delta: float) -> Status:
    if not is_instance_valid(ant) or not is_instance_valid(ant.influence_manager):
        return Status.FAILURE
        
    if ant.influence_manager.should_recalculate_target():
        ant.influence_manager.update_movement_target()
        
    return Status.RUNNING # Keep running to continue movement