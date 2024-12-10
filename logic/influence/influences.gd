extends Node
class_name EnhancedInfluences

#region Properties
## Current goal/state of the ant
var current_goal: String = "explore"

## Environmental conditions
var environment: EnvironmentalInfluence

## Memory system
var memory: MemoryInfluence

## Base influence weights
const BASE_WEIGHTS = {
	"pheromone": 2.0,
	"exploration": 1.5,
	"colony": 1.0,
	"random": 0.5
}

## Goal-specific weight modifiers
const GOAL_MODIFIERS = {
	"explore": {
		"exploration": 2.0,
		"random": 1.5,
		"colony": 0.5
	},
	"forage": {
		"pheromone": 2.0,
		"exploration": 1.5,
		"colony": 0.7
	},
	"return": {
		"colony": 3.0,
		"pheromone": 1.5,
		"exploration": 0.5
	}
}

## Dynamic influence storage
var influences: Array[Influence] = []

## Reference to parent ant
var ant: Ant

func _init(ant_instance: Ant) -> void:
	ant = ant_instance
	environment = EnvironmentalInfluence.new()
	memory = MemoryInfluence.new()

func update_influences() -> void:
	influences.clear()
	
	# Get base influences
	var base_influences = _calculate_base_influences()
	
	# Apply goal modifiers
	for influence in base_influences:
		var final_weight = influence.weight
		if current_goal in GOAL_MODIFIERS:
			var modifier = GOAL_MODIFIERS[current_goal].get(influence.name, 1.0)
			final_weight *= modifier
		influence.weight = final_weight
		influences.append(influence)
	
	# Add environmental influences
	var env_vector = environment.calculate_comfort_vector(ant.global_position)
	if env_vector != Vector2.ZERO:
		influences.append(Influence.new(env_vector, 1.0, "environment"))
	
	# Add memory-based influences
	var memory_vector = memory.calculate_memory_vector(ant.global_position)
	if memory_vector != Vector2.ZERO:
		influences.append(Influence.new(memory_vector, 1.5, "memory"))

func get_final_direction() -> Vector2:
	var final_vector = Vector2.ZERO
	var total_weight = 0.0
	
	for influence in influences:
		final_vector += influence.direction * influence.weight
		total_weight += influence.weight
	
	if total_weight > 0:
		return (final_vector / total_weight).normalized()
	return Vector2.ZERO

func set_goal(new_goal: String) -> void:
	if new_goal in GOAL_MODIFIERS:
		current_goal = new_goal
		update_influences()

class Influence:
	var direction: Vector2
	var weight: float
	var name: String
	
	func _init(dir: Vector2, w: float, n: String) -> void:
		direction = dir.normalized()
		weight = w
		name = n

func _calculate_base_influences() -> Array:
	var base = []
	
	# Add pheromone influence
	var pheromone_dir = _calculate_pheromone_direction()
	if pheromone_dir != Vector2.ZERO:
		base.append(Influence.new(pheromone_dir, BASE_WEIGHTS.pheromone, "pheromone"))
	
	# Add exploration influence
	var explore_dir = _calculate_exploration_direction()
	if explore_dir != Vector2.ZERO:
		base.append(Influence.new(explore_dir, BASE_WEIGHTS.exploration, "exploration"))
	
	# Add colony influence
	var colony_dir = ant.global_position.direction_to(ant.colony.global_position)
	base.append(Influence.new(colony_dir, BASE_WEIGHTS.colony, "colony"))
	
	# Add random influence
	var random_dir = Vector2.RIGHT.rotated(randf() * TAU)
	base.append(Influence.new(random_dir, BASE_WEIGHTS.random, "random"))
	
	return base

func _calculate_pheromone_direction() -> Vector2:
	var pheromones = ant.get_pheromones_sensed()
	var direction = Vector2.ZERO
	for pheromone in pheromones:
		direction += ant.global_position.direction_to(pheromone.global_position)
	return direction.normalized() if direction != Vector2.ZERO else Vector2.ZERO

func _calculate_exploration_direction() -> Vector2:
	# Use the heat map system for exploration
	return ant.heat_map.get_repulsion_vector(ant.global_position)

class EnvironmentalInfluence:
	var temperature: float
	var humidity: float
	var light_level: float
	
	func calculate_comfort_vector(current_pos: Vector2) -> Vector2:
		# Calculate direction toward more comfortable conditions
		var comfort_direction = Vector2.ZERO
		# Add environmental factors...
		return comfort_direction.normalized()
		
class MemoryInfluence:
	var recent_food_locations: Array[Vector2]
	var danger_zones: Array[Vector2]
	
	func calculate_memory_vector(current_pos: Vector2) -> Vector2:
		var memory_direction = Vector2.ZERO
		# Weight memories by recency and importance
		# Return normalized direction
		return memory_direction.normalized()

class Priorities:
	var current_task: String
	var task_weights: Dictionary = {
		"forage": {
			"pheromone": 2.0,
			"exploration": 1.5
		},
		"defend": {
			"territory": 3.0,
			"colony": 2.0
		},
		"maintain": {
			"colony": 2.5,
			"pheromone": 0.5
		}
	}
	
	func get_weight_multiplier(influence_type: String) -> float:
		return task_weights.get(current_task, {}).get(influence_type, 1.0)
