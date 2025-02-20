class_name HeatmapUtils

#region Pure Functions for Heat Calculations
## Calculate heat value for a cell based on distance from source
static func calculate_cell_heat(base_heat: float, distance: float, max_heat: float) -> float:
	return minf(base_heat / (1 + distance * distance), max_heat)

## Calculate total heat from an array of source values
static func calculate_total_heat(source_values: Array[float]) -> float:
	return source_values.reduce(func(acc: float, val: float) -> float: return acc + val, 0.0)

## Apply decay to a heat value over time
static func apply_decay(current_heat: float, decay_rate: float, delta: float) -> float:
	return maxf(0.0, current_heat - decay_rate * delta)

## Calculate heat distribution for multiple sources
static func calculate_multi_source_heat(
	sources: Array[Dictionary],  # Array of {position: Vector2, heat: float}
	target_pos: Vector2,
	max_heat: float
) -> float:
	var total_heat := sources.map(
		func(source: Dictionary) -> float:
			var distance: float = source.position.distance_to(target_pos)
			return calculate_cell_heat(source.heat, distance, max_heat)
	)
	return calculate_total_heat(total_heat)

## Get heat value for specific colony
static func get_colony_heat(
	sources: Dictionary,  # entity_id -> heat_value
	entities: Dictionary,  # entity_id -> {colony_id: int}
	colony_id: int
) -> float:
	var colony_sources := sources.keys().filter(
		func(entity_id: int) -> bool:
			return entities.has(entity_id) and entities[entity_id].colony_id == colony_id
	).map(
		func(entity_id: int) -> float:
			return sources[entity_id]
	)
	return calculate_total_heat(colony_sources)
#endregion

#region Pure Functions for Grid Operations
## Convert world position to grid coordinates
static func world_to_grid(pos: Vector2, cell_size: float) -> Vector2i:
	return Vector2i(floorf(pos.x / cell_size), floorf(pos.y / cell_size))

## Convert grid coordinates to world position
static func grid_to_world(grid_pos: Vector2i, cell_size: float) -> Vector2:
	return Vector2(grid_pos) * cell_size

## Get cells within a radius
static func get_cells_in_radius(
	center: Vector2i,
	radius: int
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var cell := Vector2i(x, y) + center
			if center.distance_to(cell) <= radius:
				cells.append(cell)
	return cells

## Convert between world and chunk coordinates
static func world_to_chunk_coords(
	world_pos: Vector2i,
	chunk_size: int
) -> Dictionary:
	var chunk_x := floori(float(world_pos.x) / chunk_size)
	var chunk_y := floori(float(world_pos.y) / chunk_size)
	var local_x := world_pos.x - (chunk_x * chunk_size)
	var local_y := world_pos.y - (chunk_y * chunk_size)
	
	return {
		"chunk": Vector2i(chunk_x, chunk_y),
		"local": Vector2i(local_x, local_y)
	}

## Convert chunk coordinates back to world coordinates
static func chunk_to_world_coords(
	chunk_pos: Vector2i,
	local_pos: Vector2i,
	chunk_size: int
) -> Vector2i:
	return Vector2i(
		chunk_pos.x * chunk_size + local_pos.x,
		chunk_pos.y * chunk_size + local_pos.y
	)
#endregion

#region Pure Functions for Heat Visualization
## Calculate color based on heat value
static func calculate_heat_color(
	start_color: Color,
	end_color: Color,
	current_heat: float,
	max_heat: float
) -> Color:
	var t := clampf(current_heat / max_heat, 0.0, 1.0)
	return start_color.lerp(end_color, t)

## Filter visible heat sources
static func filter_visible_sources(
	sources: Dictionary,  # entity_id -> heat_value
	debug_settings: Dictionary,  # entity_id -> bool
	entities: Dictionary  # entity_id -> {type: String, colony_id: int}
) -> float:
	return sources.keys().filter(
		func(entity_id: int) -> bool:
			if not entities.has(entity_id):
				return false
			var entity = entities[entity_id]
			return debug_settings.get(entity_id, false) or (
				entity.type == "ant" and 
				debug_settings.get(entity.colony_id, false)
			)
	).map(
		func(entity_id: int) -> float:
			return sources[entity_id]
	).reduce(
		func(acc: float, val: float) -> float: return acc + val,
		0.0
	)
#endregion

#region Pure Functions for State Management
## Update heat sources with decay
static func update_heat_sources(
	sources: Dictionary,  # entity_id -> heat_value
	decay_rate: float,
	delta: float
) -> Dictionary:
	var updated_sources := {}
	for entity_id in sources:
		var new_heat := apply_decay(sources[entity_id], decay_rate, delta)
		if new_heat > 0:
			updated_sources[entity_id] = new_heat
	return updated_sources

## Add or update heat source
static func add_heat_source(
	sources: Dictionary,  # entity_id -> heat_value
	entity_id: int,
	heat_amount: float,
	max_heat: float
) -> Dictionary:
	var updated_sources := sources.duplicate()
	updated_sources[entity_id] = minf(
		sources.get(entity_id, 0.0) + heat_amount,
		max_heat
	)
	return updated_sources
#endregion
