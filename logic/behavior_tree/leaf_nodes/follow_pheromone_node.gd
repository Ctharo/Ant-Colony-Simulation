class_name FollowPheromoneNode
extends BehaviorNode

@export var pheromone_type: String
@export var follow_increasing: bool = true
@export var influence_weight: float = 2.5

func tick(_delta: float) -> Status:
    if not is_instance_valid(ant):
        return Status.FAILURE
        
    var direction = ant.get_pheromone_direction(pheromone_type)
    
    # If no pheromone detected or direction is zero
    if direction.length_squared() < 0.01:
        return Status.FAILURE
        
    # Invert direction if following decreasing concentration
    if not follow_increasing:
        direction = -direction
        
    # Apply influence directly
    var normalized_direction = direction.normalized() * influence_weight
    
    # Store this as a temporary influence in the ant
    ant.temp_influences["pheromone_" + pheromone_type] = normalized_direction
    
    return Status.SUCCESS