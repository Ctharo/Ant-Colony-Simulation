extends Node

signal food_updated(location, quantity)
signal ant_moved(ant_id, new_position)

var ants: Dictionary = {}
var food_sources: Dictionary = {}
var pheromone_trails: Dictionary = {}
var colonies: Dictionary = {}

func get_ant_position(ant_id: String) -> Vector2:
	return ants[ant_id].position

func set_ant_position(ant_id: String, new_position: Vector2) -> void:
	ants[ant_id].position = new_position
	emit_signal("ant_moved", ant_id, new_position)

func get_food_at_location(location: Vector2) -> float:
	return food_sources.get(location, 0.0)

func update_food_at_location(location: Vector2, quantity: float) -> void:
	food_sources[location] = quantity
	emit_signal("food_updated", location, quantity)

func get_pheromone_strength(location: Vector2, pheromone_type: String) -> float:
	return pheromone_trails.get(location, {}).get(pheromone_type, 0.0)

func update_pheromone_strength(location: Vector2, pheromone_type: String, strength: float) -> void:
	if location not in pheromone_trails:
		pheromone_trails[location] = {}
	pheromone_trails[location][pheromone_type] = strength

func get_colony_food_store(colony_id: String) -> float:
	return colonies[colony_id].food_store

func update_colony_food_store(colony_id: String, amount: float) -> void:
	colonies[colony_id].food_store += amount

# ... Additional methods for other state properties ...

func save_state() -> Dictionary:
	# Serialize the current state to a dictionary
	return {}

func load_state(state_data: Dictionary) -> void:
	# Deserialize and apply the provided state data
	return
