class_name Pheromone
extends Resource


#region Export Properties
## Name of the pheromone type
@export var name: String

## Rate at which pheromone decays over time
@export var decay_rate: float

## Rate at which pheromone is generated
@export var generating_rate: float

## Radius of effect for the pheromone
@export var heat_radius: int = 1

## Starting color for the pheromone visualization
@export var start_color: Color = Color.WHITE

## Ending color for the pheromone visualization
@export var end_color: Color = Color(1, 1, 1, 0)

## If present, denotes condition that must be true to emit this pheromone
@export var condition: Logic
#endregion

func check_and_emit(ant: Ant, delta: float):
	if _should_emit(ant):
		_update_heat(ant, delta)

func _update_heat(ant: Ant, delta: float):
	HeatmapManager.update_entity_heat(ant, delta, name)

func _should_emit(ant: Ant) -> bool:
	if not condition:
		return true
	return _evaluate_condition(ant)

	
func _evaluate_condition(ant: Ant):
	return EvaluationSystem.get_value(condition, ant)
