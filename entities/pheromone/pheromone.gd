class_name Pheromone
extends Resource


#region Export Properties
## Name of the pheromone type
@export var name: String

## Rate at which pheromone decays over time
@export var decay_rate: float

## Rate at which pheromone is generated
@export var generating_rate: float

## Maximum radius of effect for the pheromone (cells from center)
@export var heat_radius: int = 1

## How quickly pheromone spreads outward (0.0 to 1.0)
## Higher values = faster spreading, lower = more concentrated trails
@export_range(0.0, 1.0, 0.05) var diffusion_rate: float = 0.15

## Starting color for the pheromone visualization
@export var start_color: Color = Color.WHITE

## Ending color for the pheromone visualization
@export var end_color: Color = Color(1, 1, 1, 0)

## If present, denotes condition that must be true to emit this pheromone
@export var condition: Logic
#endregion


## Check condition and emit pheromone if appropriate
func check_and_emit(ant: Ant, delta: float) -> void:
	if _should_emit(ant):
		_update_heat(ant, delta)


## Update heat in the heatmap
func _update_heat(ant: Ant, delta: float) -> void:
	HeatmapManager.update_entity_heat(ant, delta, name)


## Check if pheromone should be emitted
func _should_emit(ant: Ant) -> bool:
	if not condition:
		return true
	return _evaluate_condition(ant)


## Evaluate the condition logic
func _evaluate_condition(ant: Ant) -> bool:
	return EvaluationSystem.get_value(condition, ant)
