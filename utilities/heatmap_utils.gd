class_name HeatmapUtils

## Heat calculation utilities
class HeatCalculator:
	## Calculate heat value for a cell based on distance from source
	static func calculate_cell_heat(
		base_heat: float,
		distance: float,
		max_heat: float
	) -> float:
		var heat = base_heat / (1 + distance * distance)
		return minf(heat, max_heat)
	
	## Calculate total heat for a collection of sources
	static func calculate_total_heat(source_values: Array[float]) -> float:
		var total: float = 0.0
		for value in source_values:
			total += value
		return total
	
	## Apply decay to a heat value
	static func apply_decay(
		current_heat: float,
		decay_rate: float,
		delta: float
	) -> float:
		return maxf(0.0, current_heat - decay_rate * delta)

## Color utilities for heat visualization
class ColorUtils:
	## Interpolate between two colors based on heat value
	static func get_heat_color(
		start_color: Color,
		end_color: Color,
		heat: float,
		max_heat: float
	) -> Color:
		var t = clampf(heat / max_heat, 0.0, 1.0)
		return start_color.lerp(end_color, t)

## Cell and chunk state calculations
class StateUtils:
	## Check if a chunk is active (has any cells with heat)
	static func is_chunk_active(cell_heats: Array[float]) -> bool:
		for heat in cell_heats:
			if heat > 0:
				return true
		return false
	
	## Get cells that need updating based on radius
	static func get_cells_to_update(
		center_cell: Vector2i,
		radius: int
	) -> Array[Vector2i]:
		var cells: Array[Vector2i] = []
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var cell = center_cell + Vector2i(dx, dy)
				var distance = center_cell.distance_to(cell)
				if distance <= radius:
					cells.append(cell)
		return cells
