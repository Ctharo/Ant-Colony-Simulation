class_name ConditionNode
extends BehaviorNode

@export var condition: Logic
@export var child: BehaviorNode

func initialize(p_ant: Ant) -> void:
    super.initialize(p_ant)
    if child:
        child.initialize(p_ant)

func tick(delta: float) -> Status:
    if EvaluationSystem.get_value(condition, ant):
        return child.tick(delta)
    return Status.FAILURE

func reset() -> void:
    super.reset()
    if child:
        child.reset()