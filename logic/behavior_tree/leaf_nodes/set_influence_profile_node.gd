class_name SetInfluenceProfileNode
extends BehaviorNode

@export var influence_profile: Resource # InfluenceProfile

func tick(_delta: float) -> Status:
    if not is_instance_valid(ant) or not is_instance_valid(ant.influence_manager):
        return Status.FAILURE
        
    ant.influence_manager.active_profile = influence_profile
    return Status.SUCCESS