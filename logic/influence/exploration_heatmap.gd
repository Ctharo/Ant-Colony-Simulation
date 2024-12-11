class_name ExplorationHeatMap
extends Resource

## Dictionary storing position visits: key = grid_position, value = visit_data
var heat_map: Dictionary = {}
## Size of each grid cell for position tracking
const GRID_SIZE: float = 32.0
## Maximum time to remember visited positions (seconds)
const MEMORY_DURATION: float = 10.0

## Adds a visit to the heat map
func add_visit(position: Vector2) -> void:
	var grid_pos := _world_to_grid(position)
	var current_time := Time.get_unix_time_from_system()
	
	if grid_pos in heat_map:
		heat_map[grid_pos].count += 1
		heat_map[grid_pos].last_visit = current_time
	else:
		heat_map[grid_pos] = {
			"count": 1,
			"last_visit": current_time
		}

## Calculates repulsion vector from heavily visited areas
func get_repulsion_vector(current_pos: Vector2) -> Vector2:
	var repulsion := Vector2.ZERO
	var current_time := Time.get_unix_time_from_system()
	var grid_pos := _world_to_grid(current_pos)
	
	for x in range(-1, 2):
		for y in range(-1, 2):
			var check_pos := Vector2i(grid_pos.x + x, grid_pos.y + y)
			if check_pos in heat_map:
				var visit_data: Dictionary = heat_map[check_pos]
				var time_factor := _calculate_time_factor(current_time, visit_data.last_visit)
				if time_factor > 0:
					var direction := _grid_to_world(check_pos).direction_to(current_pos)
					repulsion += direction * visit_data.count * time_factor
	
	return repulsion.normalized()

func _world_to_grid(pos: Vector2) -> Vector2i:
	return Vector2i(floor(pos.x / GRID_SIZE), floor(pos.y / GRID_SIZE))

func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * GRID_SIZE + GRID_SIZE/2,
		grid_pos.y * GRID_SIZE + GRID_SIZE/2
	)

func _calculate_time_factor(current_time: float, visit_time: float) -> float:
	var age := current_time - visit_time
	return 0.0 if age > MEMORY_DURATION else 1.0 - (age / MEMORY_DURATION)
