class_name NavigationUtils

## Utility functions for handling positions and movement
class PositionUtils:
	## Sorts positions by distance from a reference point
	static func sort_positions_by_distance(
		positions: Array[Vector2],
		reference_point: Vector2
	) -> Array[Vector2]:
		var sorted = positions.duplicate()
		sorted.sort_custom(
			func(a: Vector2, b: Vector2) -> bool:
				return reference_point.distance_squared_to(a) < reference_point.distance_squared_to(b)
		)
		return sorted
	
	## Checks if a point is within range of a target
	static func is_point_in_range(
		point: Vector2, 
		target: Vector2, 
		range: float
	) -> bool:
		return point.distance_to(target) <= range
		
	## Gets nearest point from an array of positions
	static func get_nearest_point(
		reference: Vector2, 
		points: Array[Vector2]
	) -> Vector2:
		var nearest = reference
		var min_distance = INF
		
		for point in points:
			var distance = reference.distance_to(point)
			if distance < min_distance:
				min_distance = distance
				nearest = point
				
		return nearest

## Grid-based navigation utilities
class GridUtils:
	## Convert world position to grid cell
	static func world_to_cell(world_pos: Vector2, cell_size: float) -> Vector2i:
		return Vector2i(world_pos / cell_size)
		
	## Convert grid cell to world position
	static func cell_to_world(cell: Vector2i, cell_size: float) -> Vector2:
		return Vector2(cell * cell_size)

	## Convert world cell to chunk position
	static func world_to_chunk(world_cell: Vector2i, chunk_size: int) -> Vector2i:
		var x = world_cell.x
		var y = world_cell.y
		if x < 0:
			x = x - chunk_size + 1
		if y < 0:
			y = y - chunk_size + 1
		@warning_ignore("integer_division")
		return Vector2i(x / chunk_size, y / chunk_size)

	## Convert world cell to local cell within chunk
	static func world_to_local_cell(world_cell: Vector2i, chunk_size: int) -> Vector2i:
		var x = world_cell.x
		var y = world_cell.y
		if x < 0:
			x = chunk_size + (x % chunk_size)
		if y < 0:
			y = chunk_size + (y % chunk_size)
		@warning_ignore("integer_division")
		return Vector2i(x % chunk_size, y % chunk_size)

	## Convert chunk and local position to world cell
	static func chunk_to_world_cell(
		chunk_pos: Vector2i, 
		local_pos: Vector2i, 
		chunk_size: int
	) -> Vector2i:
		return Vector2i(
			chunk_pos.x * chunk_size + local_pos.x,
			chunk_pos.y * chunk_size + local_pos.y
		)

	## Convert chunk position to world position
	static func chunk_to_world(
		chunk_pos: Vector2i, 
		chunk_size: int, 
		cell_size: float
	) -> Vector2:
		return Vector2(chunk_pos * chunk_size * cell_size)

	## Get cells within radius of a position
	static func get_cells_in_radius(
		center_pos: Vector2,
		radius: float,
		cell_size: float
	) -> Array[Vector2i]:
		var center_cell := world_to_cell(center_pos, cell_size)
		var cells_radius := ceili(radius / cell_size)
		var cells: Array[Vector2i] = []
		
		for dx in range(-cells_radius, cells_radius + 1):
			for dy in range(-cells_radius, cells_radius + 1):
				var check_cell := center_cell + Vector2i(dx, dy)
				var cell_pos := cell_to_world(check_cell, cell_size)
				
				if center_pos.distance_to(cell_pos) <= radius:
					cells.append(check_cell)
					
		return cells
