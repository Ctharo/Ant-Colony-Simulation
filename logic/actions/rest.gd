class_name Rest
extends Action

## Rate at which health regenerates per second
@export var health_regen_rate: float = 10.0

## Rate at which energy regenerates per second
@export var energy_regen_rate: float = 15.0

func execute_tick(entity: Node, _state: ActionState, delta: float) -> void:
	var current_health: float = entity.health_level
	var max_health: float = entity.health_max
	var current_energy: float = entity.energy_level
	var max_energy: float = entity.energy_max

	# Calculate health regeneration
	if current_health < max_health:
		var health_increase = health_regen_rate * delta
		entity.health_level = min(current_health + health_increase, max_health)

	# Calculate energy regeneration
	if current_energy < max_energy:
		var energy_increase = energy_regen_rate * delta
		entity.energy_level = min(current_energy + energy_increase, max_energy)
