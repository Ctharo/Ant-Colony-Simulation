class_name AntUtils

## Energy calculation utilities
class EnergyCalculator:
	const ENERGY_DRAIN_FACTOR = 0.000015
	
	## Calculates base energy drain rate based on movement and carrying status
	## All inputs are primitives with no class dependencies
	static func calculate_energy_drain(
		movement_rate: float, 
		carrying_weight: float
	) -> float:
		return ENERGY_DRAIN_FACTOR * (carrying_weight + 1) * pow(movement_rate, 1.2)
	
	## Calculates energy cost for movement based on current velocity
	static func calculate_movement_energy_cost(
		base_drain: float, 
		velocity_length: float,
		delta: float
	) -> float:
		return base_drain * velocity_length * delta

## Health and status calculations
class StatusUtils:
	## Check if rest is needed based on current levels
	static func should_rest(
		current_health: float,
		max_health: float,
		current_energy: float, 
		max_energy: float,
		threshold: float = 0.9
	) -> bool:
		return current_health < threshold * max_health or current_energy < threshold * max_energy
	
	## Check if fully rested based on current levels
	static func is_fully_rested(
		current_health: float,
		max_health: float,
		current_energy: float,
		max_energy: float
	) -> bool:
		return current_health >= max_health and current_energy >= max_energy

## Pheromone calculation utilities
class PheromoneUtils:
	## Represents a single concentration sample with only primitive types
	class Sample:
		var position: Vector2
		var concentration: float
		var timestamp: int
		
		func _init(
			p_position: Vector2,
			p_concentration: float,
			p_timestamp: int
		) -> void:
			position = p_position
			concentration = p_concentration
			timestamp = p_timestamp
	
	## Calculates concentration vector from primitive sample data
	static func calculate_concentration_vector(
		sample_positions: Array[Vector2],
		sample_concentrations: Array[float],
		sample_timestamps: Array[int],
		current_time: int,
		memory_duration: int
	) -> Vector2:
		if sample_positions.size() < 2:
			return Vector2.ZERO
			
		var direction := Vector2.ZERO
		var total_weight := 0.0
		
		for i in range(sample_positions.size() - 1):
			for j in range(i + 1, sample_positions.size()):
				var concentration_diff := sample_concentrations[j] - sample_concentrations[i]
				if concentration_diff == 0:
					continue
					
				var time_factor := 1.0 - float(current_time - sample_timestamps[j]) / memory_duration
				var weight := time_factor * absf(concentration_diff)
				
				var sample_direction := (sample_positions[j] - sample_positions[i]).normalized()
				direction += sample_direction * weight * signf(concentration_diff)
				total_weight += weight
		
		return direction.normalized() if total_weight > 0 else Vector2.ZERO
