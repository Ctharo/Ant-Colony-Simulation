class_name Move
extends Action

#region Properties
## Movement configuration
@export_group("Movement Settings")
## Target position to move towards
@export var target_position: Vector2
## Movement speed in pixels per second
@export var speed: float = 100.0
## Distance threshold to consider target reached
@export var arrival_threshold: float = 5.0
## Optional movement constraints
@export_group("Movement Constraints")
## Maximum distance from start position
@export var max_radius: float = -1.0
## Movement update interval (-1 for continuous)
@export var update_interval: float = -1.0
## Movement pattern type
@export_enum("Direct", "Random", "Patrol") var movement_type: int = 0
## Current entity position (updated externally)
var current_position: Vector2
## Internal timer for interval-based movement
var _interval_timer: float = 0.0
#endregion

func execute(delta: float) -> bool:
	if update_interval > 0:
		_interval_timer += delta
		if _interval_timer >= update_interval:
			_interval_timer = 0
			_update_target()
	
	var direction = (target_position - current_position).normalized()
	var distance = current_position.distance_to(target_position)
	
	if distance <= arrival_threshold:
		return true
		
	var movement = direction * speed * delta
	
	if movement.length() > distance:
		current_position = current_position.move_toward(target_position, delta)
	else:
		current_position += movement
		
	return false

func _update_target() -> void:
	match movement_type:
		1: # Random
			if max_radius > 0:
				var random_angle = randf() * TAU
				var random_distance = randf() * max_radius
				target_position = current_position + Vector2(
					cos(random_angle) * random_distance,
					sin(random_angle) * random_distance
				)
