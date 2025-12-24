extends Node2D

#region Constants and Types
const STYLE = {
	"CELL_SIZE": 50,
	"CHUNK_SIZE": 16,
	"MAX_HEAT": 100.0
}

## Custom types for better data organization
const CellData = {
	"heat": 0.0,
	"sources": {}  # Dictionary[int, float]
}

const ChunkData = {
	"cells": {},  # Dictionary[Vector2i, CellData]
	"active_cells": 0,
	"last_update_time": 0
}

const HeatmapData = {
	"chunks": {},  # Dictionary[Vector2i, ChunkData]
	"config": null  # Pheromone
}
#endregion

#region Member Variables
var map_size: Vector2
var update_thread: Thread
var update_lock: Mutex
var _nav_map: RID
var camera: Camera2D
var _heatmaps: Dictionary = {}  # Dictionary[String, HeatmapData]
var _debug_settings: Dictionary = {}
var update_timer: float = 0.0
var update_interval: float = 1.0
var logger: iLogger
var _is_quitting: bool = false
var _last_decay_time: int = 0
#endregion

#region Pure Functions - Cell Operations
static func create_cell_data() -> Dictionary:
	return CellData.duplicate(true)

static func add_heat_to_cell(cell_data: Dictionary, entity_id: int, amount: float, max_heat: float) -> Dictionary:
	var new_cell = cell_data.duplicate(true)
	if not new_cell.sources.has(entity_id):
		new_cell.sources[entity_id] = 0.0
	new_cell.sources[entity_id] = minf(new_cell.sources[entity_id] + amount, max_heat)
	new_cell.heat = calculate_total_heat(new_cell.sources)
	return new_cell

static func calculate_total_heat(sources: Dictionary) -> float:
	return sources.values().reduce(func(acc, val): return acc + val, 0.0)

static func decay_cell(cell_data: Dictionary, delta: float, decay_rate: float) -> Dictionary:
	var new_cell = cell_data.duplicate(true)
	var any_active = false

	for entity_id in new_cell.sources:
		new_cell.sources[entity_id] = maxf(0.0, new_cell.sources[entity_id] - decay_rate * delta)
		if new_cell.sources[entity_id] > 0:
			any_active = true

	new_cell.heat = calculate_total_heat(new_cell.sources)
	return {"cell": new_cell, "active": any_active}

static func get_colony_heat(cell_data: Dictionary, colony_id: int) -> float:
	var total: float = 0.0
	for source_id in cell_data.sources:
		var source: Node2D = instance_from_id(source_id)
		if is_instance_valid(source):
			var source_colony_id: int = source.colony.get_instance_id() if source is Ant else source.get_instance_id()
			if source_colony_id == colony_id:
				total += cell_data.sources[source_id]
	return total
#endregion

#region Pure Functions - Chunk Operations
static func create_chunk_data() -> Dictionary:
	return ChunkData.duplicate(true)

static func update_chunk(chunk_data: Dictionary, delta: float, decay_rate: float) -> Dictionary:
	var new_chunk = chunk_data.duplicate(true)
	var active_cells = 0
	var cells_to_keep = {}

	for pos in new_chunk.cells:
		var decay_result = decay_cell(new_chunk.cells[pos], delta, decay_rate)
		if decay_result.active:
			cells_to_keep[pos] = decay_result.cell
			active_cells += 1

	new_chunk.cells = cells_to_keep
	new_chunk.active_cells = active_cells
	new_chunk.last_update_time = Time.get_ticks_msec()

	return {"chunk": new_chunk, "active": active_cells > 0}
#endregion

#region Pure Functions - Coordinate Transformations
func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(world_pos / STYLE.CELL_SIZE)

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell * STYLE.CELL_SIZE)

func world_to_chunk(world_cell: Vector2i) -> Vector2i:
	var x = world_cell.x
	var y = world_cell.y
	if x < 0:
		x = x - STYLE.CHUNK_SIZE + 1
	if y < 0:
		y = y - STYLE.CHUNK_SIZE + 1
	@warning_ignore("integer_division")
	return Vector2i(x / STYLE.CHUNK_SIZE, y / STYLE.CHUNK_SIZE)

func world_to_local_cell(world_cell: Vector2i) -> Vector2i:
	var x = world_cell.x
	var y = world_cell.y
	if x < 0:
		x = STYLE.CHUNK_SIZE + (x % STYLE.CHUNK_SIZE)
	if y < 0:
		y = STYLE.CHUNK_SIZE + (y % STYLE.CHUNK_SIZE)
	return Vector2i(x % STYLE.CHUNK_SIZE, y % STYLE.CHUNK_SIZE)

func chunk_to_world_cell(chunk_pos: Vector2i, local_pos: Vector2i) -> Vector2i:
	return Vector2i(
		chunk_pos.x * STYLE.CHUNK_SIZE + local_pos.x,
		chunk_pos.y * STYLE.CHUNK_SIZE + local_pos.y
	)
#endregion

#region Pure Functions - Heat Management
func calculate_heat_updates(entity_pos: Vector2, base_heat: float, radius: int) -> Array[Dictionary]:
	var center_cell = world_to_cell(entity_pos)
	var updates: Array[Dictionary] = []

	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var cell = center_cell + Vector2i(dx, dy)
			var distance = center_cell.distance_to(cell)

			if distance <= radius:
				updates.append({
					"cell": cell,
					"heat": base_heat / (1 + distance * distance)
				})

	return updates

func calculate_cell_influence(cell_data: Dictionary, query_entity_id: int) -> float:
	var total_heat: float = 0.0
	for source_id in cell_data.sources:
		if source_id != query_entity_id:  # Don't be influenced by own heat
			total_heat += cell_data.sources[source_id]
	return total_heat

func get_cells_in_radius_data(world_pos: Vector2, radius: float, heatmap_data: Dictionary) -> Array[Dictionary]:
	var center_cell = world_to_cell(world_pos)
	var cells_radius = ceili(radius / STYLE.CELL_SIZE)
	var found_cells: Array[Dictionary] = []
	var chunk_radius = ceili(float(cells_radius) / STYLE.CHUNK_SIZE)
	var center_chunk = world_to_chunk(center_cell)

	for dx in range(-chunk_radius, chunk_radius + 1):
		for dy in range(-chunk_radius, chunk_radius + 1):
			var check_chunk = center_chunk + Vector2i(dx, dy)
			if not heatmap_data.chunks.has(check_chunk):
				continue

			var chunk = heatmap_data.chunks[check_chunk]
			for local_pos in chunk.cells:
				var cell = chunk.cells[local_pos]
				var world_cell = chunk_to_world_cell(check_chunk, local_pos)
				var cell_pos = cell_to_world(world_cell)

				if cell.heat > 0 and world_pos.distance_to(cell_pos) <= radius:
					found_cells.append({
						"position": cell_pos,
						"chunk_pos": check_chunk,
						"local_pos": local_pos,
						"heat": cell.heat,
						"sources": cell.sources
					})

	return found_cells
#endregion

#region Pure Functions - Visualization
static func calculate_visible_heat(cell_data: Dictionary, debug_settings: Dictionary) -> float:
	var visible_heat: float = 0.0
	for source_id in cell_data.sources:
		var entity: Node2D = instance_from_id(source_id)
		if not is_instance_valid(entity):
			continue

		if entity is Ant:
			var colony: Node2D = entity.colony
			if colony and (debug_settings.get(source_id, false) or debug_settings.get(colony.get_instance_id(), false)):
				visible_heat += cell_data.sources[source_id]
	return visible_heat

static func get_cell_color(t: float, config: Pheromone) -> Color:
	return config.start_color.lerp(config.end_color, t)
#endregion

#region Instance Management
func _init() -> void:
	logger = iLogger.new("heatmap_manager", DebugLogger.Category.MOVEMENT)
	update_lock = Mutex.new()
	top_level = true
	_last_decay_time = Time.get_ticks_msec()

func _ready() -> void:
	_start_update_thread()

func create_heatmap_type(pheromone: Pheromone) -> void:
	var heatmap_name = pheromone.name.to_lower()
	if not _heatmaps.has(heatmap_name):
		_heatmaps[heatmap_name] = {
			"chunks": {},
			"config": pheromone
		}

func setup_navigation() -> void:
	_nav_map = get_world_2d().get_navigation_map()

func setup_camera(p_camera: Camera2D) -> void:
	camera = p_camera
#endregion

#region Thread Management
func _start_update_thread() -> void:
	update_thread = Thread.new()
	update_thread.start(_update_heatmap_thread)

func _update_heatmap_thread() -> void:
	while not _is_quitting:
		var current_time: int = Time.get_ticks_msec()
		var time_since_decay: float = (current_time - _last_decay_time) / 1000.0

		if time_since_decay >= update_interval:
			if update_lock.try_lock():
				_process_decay(time_since_decay)
				update_lock.unlock()
				_last_decay_time = current_time

		call_thread_safe("queue_redraw")
		OS.delay_msec(int(update_interval * 100))

func _process_decay(delta: float) -> void:
	for heat_type in _heatmaps:
		var heatmap = _heatmaps[heat_type]
		var chunks_to_remove = []

		for chunk_pos in heatmap.chunks:
			var update_result = update_chunk(heatmap.chunks[chunk_pos], delta, heatmap.config.decay_rate)
			if update_result.active:
				heatmap.chunks[chunk_pos] = update_result.chunk
			else:
				chunks_to_remove.append(chunk_pos)

		for chunk_pos in chunks_to_remove:
			heatmap.chunks.erase(chunk_pos)

func _cleanup_thread() -> void:
	if update_thread and update_thread.is_started():
		_is_quitting = true
		update_thread.wait_to_finish()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_cleanup_thread()
#endregion

#region Entity Management
func register_entity(entity: Node2D) -> void:
	var entity_id: int = entity.get_instance_id()
	if not _debug_settings.has(entity_id):
		_debug_settings[entity_id] = false
		logger.debug("Registered entity %s" % entity.name)

func unregister_entity(entity: Node2D) -> void:
	var entity_id: int = entity.get_instance_id()
	update_lock.lock()
	_debug_settings.erase(entity_id)
	for heatmap in _heatmaps.values():
		for chunk in heatmap.chunks.values():
			for cell_pos in chunk.cells:
				var cell = chunk.cells[cell_pos]
				chunk.cells[cell_pos] = cell.duplicate()
				chunk.cells[cell_pos].sources.erase(entity_id)
	update_lock.unlock()

	logger.debug("Unregistered entity %s" % entity.name)

func debug_draw(entity: Node2D, enabled: bool) -> void:
	_debug_settings[entity.get_instance_id()] = enabled
	queue_redraw()
#endregion

#region Heat Management
func update_entity_heat(entity: Node2D, delta: float, heat_type: String, factor: float = 1.0) -> void:
	if not _heatmaps.has(heat_type):
		return

	var entity_id = entity.get_instance_id()
	var base_heat = _heatmaps[heat_type].config.generating_rate * delta * factor
	var updates = calculate_heat_updates(
		entity.global_position,
		base_heat,
		_heatmaps[heat_type].config.heat_radius
	)

	update_lock.lock()
	for update in updates:
		_apply_heat_update(entity_id, update, heat_type)
	update_lock.unlock()

func _apply_heat_update(entity_id: int, update: Dictionary, heat_type: String) -> void:
	var chunk_pos = world_to_chunk(update.cell)
	var local_pos = world_to_local_cell(update.cell)

	if not _heatmaps[heat_type].chunks.has(chunk_pos):
		_heatmaps[heat_type].chunks[chunk_pos] = create_chunk_data()

	var chunk = _heatmaps[heat_type].chunks[chunk_pos]
	if not chunk.cells.has(local_pos):
		chunk.cells[local_pos] = create_cell_data()

	chunk.cells[local_pos] = add_heat_to_cell(
		chunk.cells[local_pos],
		entity_id,
		update.heat,
		STYLE.MAX_HEAT
	)

func get_heat_at_position(entity: Node2D, heat_type: String) -> float:
	if not _heatmaps.has(heat_type):
		return 0.0

	var query_data = {
		"colony_id": entity.colony.get_instance_id() if entity is Ant else entity.get_instance_id(),
		"world_cell": world_to_cell(entity.global_position)
	}

	var chunk_pos = world_to_chunk(query_data.world_cell)
	var local_pos = world_to_local_cell(query_data.world_cell)

	update_lock.lock()
	var result = 0.0

	if _heatmaps[heat_type].chunks.has(chunk_pos):
		var chunk = _heatmaps[heat_type].chunks[chunk_pos]
		if chunk.cells.has(local_pos):
			result = get_colony_heat(chunk.cells[local_pos], query_data.colony_id)

	update_lock.unlock()
	return result

func get_cells_in_radius(world_pos: Vector2, radius: float, heat_type: String) -> Array[Dictionary]:
	if not _heatmaps.has(heat_type):
		return []

	update_lock.lock()
	var cells = get_cells_in_radius_data(world_pos, radius, _heatmaps[heat_type])
	update_lock.unlock()

	return cells

#region Drawing and Visualization
func _draw() -> void:
	if not camera:
		return

	update_lock.lock()
	for heat_type in _heatmaps:
		var heatmap = _heatmaps[heat_type]
		_draw_heatmap(heatmap)
	update_lock.unlock()

func _draw_heatmap(heatmap: Dictionary) -> void:
	for chunk_pos in heatmap.chunks:
		var chunk = heatmap.chunks[chunk_pos]
		for local_pos in chunk.cells:
			var cell = chunk.cells[local_pos]
			var world_cell = chunk_to_world_cell(chunk_pos, local_pos)
			var visible_heat = calculate_visible_heat(cell, _debug_settings)

			if visible_heat <= 0:
				continue

			var world_pos = cell_to_world(world_cell)
			var rect = Rect2(
				world_pos,
				Vector2.ONE * STYLE.CELL_SIZE
			)

			var t = visible_heat / STYLE.MAX_HEAT
			var color = get_cell_color(t, heatmap.config)
			draw_rect(rect, color)

#region Navigation
func is_cell_navigable(pos: Vector2) -> bool:
	if _nav_map == RID() or _nav_map == null or not NavigationServer2D.map_is_active(_nav_map):
		return true

	var regions: Array[RID] = NavigationServer2D.map_get_regions(_nav_map)
	if regions.is_empty():
		return true

	for region in regions:
		if region and NavigationServer2D.region_owns_point(region, pos):
			return true

	return false
#region Tooltip Support
## Returns all visible heat values at a specific cell position for tooltip display
func get_all_heat_at_cell(world_cell: Vector2i) -> Dictionary:
	var heat_values: Dictionary = {}
	var chunk_pos := world_to_chunk(world_cell)
	var local_pos := world_to_local_cell(world_cell)

	update_lock.lock()

	for heat_type in _heatmaps:
		var heatmap = _heatmaps[heat_type]
		if heatmap.chunks.has(chunk_pos):
			var chunk = heatmap.chunks[chunk_pos]
			if chunk.cells.has(local_pos):
				var cell = chunk.cells[local_pos]
				var visible_heat := calculate_visible_heat(cell, _debug_settings)
				if visible_heat > 0:
					heat_values[heat_type] = visible_heat

	update_lock.unlock()
	return heat_values

## Check if any heatmap visualization is currently enabled
func is_any_heatmap_visible() -> bool:
	for key in _debug_settings:
		if _debug_settings[key]:
			return true
	return false
#endregion
