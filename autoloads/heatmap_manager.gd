extends Node2D

#region Constants and Types
const STYLE: Dictionary = {
	"CELL_SIZE": 50,
	"CHUNK_SIZE": 16,
	"MAX_HEAT": 100.0
}

## Diffusion constants
const DIFFUSION: Dictionary = {
	"SPREAD_INTERVAL": 0.1,  ## How often diffusion spreads (seconds)
	"SPREAD_RATIO": 0.15,    ## How much heat spreads to neighbors per tick
	"MIN_SPREAD_HEAT": 0.5,  ## Minimum heat to spread
	"MAX_SPREAD_RADIUS": 8   ## Maximum cells from origin that diffusion can reach
}

## Custom types for better data organization
const CellData: Dictionary = {
	"heat": 0.0,
	"sources": {},  ## Dictionary[int, float]
	"diffusion_heat": 0.0,  ## Heat from diffusion (not from direct entity emission)
	"origin_distance": 0  ## Distance from emission origin for diffusion limiting
}

const ChunkData: Dictionary = {
	"cells": {},  ## Dictionary[Vector2i, CellData]
	"active_cells": 0,
	"last_update_time": 0
}

const HeatmapData: Dictionary = {
	"chunks": {},  ## Dictionary[Vector2i, ChunkData]
	"config": null  ## Pheromone
}

## Pending diffusion updates to process
const DiffusionUpdate: Dictionary = {
	"cell": Vector2i.ZERO,
	"heat": 0.0,
	"source_id": 0,
	"spread_distance": 0
}
#endregion

#region Member Variables
var map_size: Vector2
var update_thread: Thread
var update_lock: Mutex
var _nav_map: RID
var camera: Camera2D
var _heatmaps: Dictionary = {}  ## Dictionary[String, HeatmapData]
var _debug_settings: Dictionary = {}
var update_timer: float = 0.0
var update_interval: float = 1.0
var logger: iLogger
var _is_quitting: bool = false
var _last_decay_time: int = 0
var _last_diffusion_time: int = 0

## Pending diffusion updates queue
var _pending_diffusion: Dictionary = {}  ## Dictionary[String, Array[DiffusionUpdate]]
#endregion

#region Pure Functions - Cell Operations
static func create_cell_data() -> Dictionary:
	return CellData.duplicate(true)

static func add_heat_to_cell(cell_data: Dictionary, entity_id: int, amount: float, max_heat: float) -> Dictionary:
	var new_cell: Dictionary = cell_data.duplicate(true)
	if not new_cell.sources.has(entity_id):
		new_cell.sources[entity_id] = 0.0
	new_cell.sources[entity_id] = minf(new_cell.sources[entity_id] + amount, max_heat)
	new_cell.heat = calculate_total_heat(new_cell.sources) + new_cell.diffusion_heat
	return new_cell

static func add_diffusion_heat_to_cell(cell_data: Dictionary, amount: float, max_heat: float, distance: int) -> Dictionary:
	var new_cell: Dictionary = cell_data.duplicate(true)
	new_cell.diffusion_heat = minf(new_cell.diffusion_heat + amount, max_heat)
	new_cell.origin_distance = maxi(new_cell.origin_distance, distance)
	new_cell.heat = calculate_total_heat(new_cell.sources) + new_cell.diffusion_heat
	return new_cell

static func calculate_total_heat(sources: Dictionary) -> float:
	return sources.values().reduce(func(acc: float, val: float) -> float: return acc + val, 0.0)

static func decay_cell(cell_data: Dictionary, delta: float, decay_rate: float) -> Dictionary:
	var new_cell: Dictionary = cell_data.duplicate(true)
	var any_active: bool = false

	for entity_id: int in new_cell.sources:
		new_cell.sources[entity_id] = maxf(0.0, new_cell.sources[entity_id] - decay_rate * delta)
		if new_cell.sources[entity_id] > 0:
			any_active = true

	## Also decay diffusion heat
	new_cell.diffusion_heat = maxf(0.0, new_cell.diffusion_heat - decay_rate * delta)
	if new_cell.diffusion_heat > 0:
		any_active = true

	new_cell.heat = calculate_total_heat(new_cell.sources) + new_cell.diffusion_heat
	return {"cell": new_cell, "active": any_active}

static func get_colony_heat(cell_data: Dictionary, colony_id: int) -> float:
	var total: float = 0.0
	for source_id: int in cell_data.sources:
		var source: Node2D = instance_from_id(source_id)
		if is_instance_valid(source):
			var source_colony_id: int = source.colony.get_instance_id() if source is Ant else source.get_instance_id()
			if source_colony_id == colony_id:
				total += cell_data.sources[source_id]
	## Include diffusion heat in colony total
	total += cell_data.diffusion_heat
	return total
#endregion

#region Pure Functions - Chunk Operations
static func create_chunk_data() -> Dictionary:
	return ChunkData.duplicate(true)

static func update_chunk(chunk_data: Dictionary, delta: float, decay_rate: float) -> Dictionary:
	var new_chunk: Dictionary = chunk_data.duplicate(true)
	var active_cells: int = 0
	var cells_to_keep: Dictionary = {}

	for pos: Vector2i in new_chunk.cells:
		var decay_result: Dictionary = decay_cell(new_chunk.cells[pos], delta, decay_rate)
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
	var x: int = world_cell.x
	var y: int = world_cell.y
	if x < 0:
		x = x - STYLE.CHUNK_SIZE + 1
	if y < 0:
		y = y - STYLE.CHUNK_SIZE + 1
	@warning_ignore("integer_division")
	return Vector2i(x / STYLE.CHUNK_SIZE, y / STYLE.CHUNK_SIZE)

func world_to_local_cell(world_cell: Vector2i) -> Vector2i:
	var x: int = world_cell.x
	var y: int = world_cell.y
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
## Calculate heat for the center cell only (no radius spreading)
func calculate_center_heat_update(entity_pos: Vector2, base_heat: float) -> Dictionary:
	var center_cell: Vector2i = world_to_cell(entity_pos)
	return {
		"cell": center_cell,
		"heat": base_heat
	}

## Legacy function for immediate radius-based heat (kept for compatibility)
func calculate_heat_updates(entity_pos: Vector2, base_heat: float, radius: int) -> Array[Dictionary]:
	var center_cell: Vector2i = world_to_cell(entity_pos)
	var updates: Array[Dictionary] = [] as Array[Dictionary]

	for dx: int in range(-radius, radius + 1):
		for dy: int in range(-radius, radius + 1):
			var cell: Vector2i = center_cell + Vector2i(dx, dy)
			var distance: float = center_cell.distance_to(cell)

			if distance <= radius:
				updates.append({
					"cell": cell,
					"heat": base_heat / (1 + distance * distance)
				})

	return updates

func calculate_cell_influence(cell_data: Dictionary, query_entity_id: int) -> float:
	var total_heat: float = 0.0
	for source_id: int in cell_data.sources:
		if source_id != query_entity_id:  ## Don't be influenced by own heat
			total_heat += cell_data.sources[source_id]
	## Include diffusion heat
	total_heat += cell_data.diffusion_heat
	return total_heat

func get_cells_in_radius_data(world_pos: Vector2, radius: float, heatmap_data: Dictionary) -> Array[Dictionary]:
	var center_cell: Vector2i = world_to_cell(world_pos)
	var cells_radius: int = ceili(radius / STYLE.CELL_SIZE)
	var found_cells: Array[Dictionary] = [] as Array[Dictionary]
	var chunk_radius: int = ceili(float(cells_radius) / STYLE.CHUNK_SIZE)
	var center_chunk: Vector2i = world_to_chunk(center_cell)

	for dx: int in range(-chunk_radius, chunk_radius + 1):
		for dy: int in range(-chunk_radius, chunk_radius + 1):
			var check_chunk: Vector2i = center_chunk + Vector2i(dx, dy)
			if not heatmap_data.chunks.has(check_chunk):
				continue

			var chunk: Dictionary = heatmap_data.chunks[check_chunk]
			for local_pos: Vector2i in chunk.cells:
				var cell: Dictionary = chunk.cells[local_pos]
				var world_cell: Vector2i = chunk_to_world_cell(check_chunk, local_pos)
				var cell_pos: Vector2 = cell_to_world(world_cell)

				if cell.heat > 0 and world_pos.distance_to(cell_pos) <= radius:
					found_cells.append({
						"position": cell_pos,
						"chunk_pos": check_chunk,
						"local_pos": local_pos,
						"heat": cell.heat,
						"sources": cell.sources,
						"diffusion_heat": cell.diffusion_heat
					})

	return found_cells
#endregion

#region Pure Functions - Visualization
static func calculate_visible_heat(cell_data: Dictionary, debug_settings: Dictionary) -> float:
	var visible_heat: float = 0.0
	for source_id: int in cell_data.sources:
		var entity: Node2D = instance_from_id(source_id)
		if not is_instance_valid(entity):
			continue

		if entity is Ant:
			var colony: Node2D = entity.colony
			if colony and (debug_settings.get(source_id, false) or debug_settings.get(colony.get_instance_id(), false)):
				visible_heat += cell_data.sources[source_id]
	## Add diffusion heat to visible heat if any sources are visible
	if visible_heat > 0:
		visible_heat += cell_data.get("diffusion_heat", 0.0)
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
	_last_diffusion_time = Time.get_ticks_msec()

func _ready() -> void:
	_start_update_thread()

func create_heatmap_type(pheromone: Pheromone) -> void:
	var heatmap_name: String = pheromone.name.to_lower()
	if not _heatmaps.has(heatmap_name):
		_heatmaps[heatmap_name] = {
			"chunks": {},
			"config": pheromone
		}
		_pending_diffusion[heatmap_name] = [] as Array[Dictionary]

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
		var time_since_diffusion: float = (current_time - _last_diffusion_time) / 1000.0

		if time_since_decay >= update_interval:
			if update_lock.try_lock():
				_process_decay(time_since_decay)
				update_lock.unlock()
				_last_decay_time = current_time

		## Process diffusion spreading
		if time_since_diffusion >= DIFFUSION.SPREAD_INTERVAL:
			if update_lock.try_lock():
				_process_diffusion()
				update_lock.unlock()
				_last_diffusion_time = current_time

		call_thread_safe("queue_redraw")
		OS.delay_msec(int(update_interval * 100))

func _process_decay(delta: float) -> void:
	for heat_type: String in _heatmaps:
		var heatmap: Dictionary = _heatmaps[heat_type]
		var chunks_to_remove: Array[Vector2i] = [] as Array[Vector2i]

		for chunk_pos: Vector2i in heatmap.chunks:
			var update_result: Dictionary = update_chunk(heatmap.chunks[chunk_pos], delta, heatmap.config.decay_rate)
			if update_result.active:
				heatmap.chunks[chunk_pos] = update_result.chunk
			else:
				chunks_to_remove.append(chunk_pos)

		for chunk_pos: Vector2i in chunks_to_remove:
			heatmap.chunks.erase(chunk_pos)

func _process_diffusion() -> void:
	## Process heat spreading from high concentration cells to neighbors
	for heat_type: String in _heatmaps:
		var heatmap: Dictionary = _heatmaps[heat_type]
		var config: Pheromone = heatmap.config
		var max_radius: int = config.heat_radius if config else DIFFUSION.MAX_SPREAD_RADIUS
		var new_diffusion_updates: Array[Dictionary] = [] as Array[Dictionary]

		for chunk_pos: Vector2i in heatmap.chunks:
			var chunk: Dictionary = heatmap.chunks[chunk_pos]

			for local_pos: Vector2i in chunk.cells:
				var cell: Dictionary = chunk.cells[local_pos]
				var cell_heat: float = cell.heat
				var cell_distance: int = cell.get("origin_distance", 0)

				## Only spread if there's enough heat and we haven't reached max radius
				if cell_heat < DIFFUSION.MIN_SPREAD_HEAT:
					continue
				if cell_distance >= max_radius:
					continue

				## Calculate spread amount
				var spread_amount: float = cell_heat * DIFFUSION.SPREAD_RATIO

				## Get world cell position
				var world_cell: Vector2i = chunk_to_world_cell(chunk_pos, local_pos)

				## Spread to 4-connected neighbors (cardinal directions)
				var neighbors: Array[Vector2i] = [
					world_cell + Vector2i(1, 0),
					world_cell + Vector2i(-1, 0),
					world_cell + Vector2i(0, 1),
					world_cell + Vector2i(0, -1)
				] as Array[Vector2i]

				for neighbor: Vector2i in neighbors:
					## Check if neighbor cell would exceed max radius
					var neighbor_chunk: Vector2i = world_to_chunk(neighbor)
					var neighbor_local: Vector2i = world_to_local_cell(neighbor)
					var neighbor_distance: int = cell_distance + 1

					if neighbor_distance > max_radius:
						continue

					## Check current neighbor heat to avoid over-spreading
					var neighbor_heat: float = 0.0
					if heatmap.chunks.has(neighbor_chunk):
						var n_chunk: Dictionary = heatmap.chunks[neighbor_chunk]
						if n_chunk.cells.has(neighbor_local):
							neighbor_heat = n_chunk.cells[neighbor_local].heat

					## Only spread if target has less heat (downhill flow)
					if neighbor_heat < cell_heat - spread_amount:
						new_diffusion_updates.append({
							"cell": neighbor,
							"heat": spread_amount * 0.25,  ## Split among 4 neighbors
							"distance": neighbor_distance
						})

		## Apply diffusion updates
		for update: Dictionary in new_diffusion_updates:
			_apply_diffusion_update(update, heat_type)

func _apply_diffusion_update(update: Dictionary, heat_type: String) -> void:
	var chunk_pos: Vector2i = world_to_chunk(update.cell)
	var local_pos: Vector2i = world_to_local_cell(update.cell)

	if not _heatmaps[heat_type].chunks.has(chunk_pos):
		_heatmaps[heat_type].chunks[chunk_pos] = create_chunk_data()

	var chunk: Dictionary = _heatmaps[heat_type].chunks[chunk_pos]
	if not chunk.cells.has(local_pos):
		chunk.cells[local_pos] = create_cell_data()

	chunk.cells[local_pos] = add_diffusion_heat_to_cell(
		chunk.cells[local_pos],
		update.heat,
		STYLE.MAX_HEAT,
		update.distance
	)

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
	for heatmap: Dictionary in _heatmaps.values():
		for chunk: Dictionary in heatmap.chunks.values():
			for cell_pos: Vector2i in chunk.cells:
				var cell: Dictionary = chunk.cells[cell_pos]
				chunk.cells[cell_pos] = cell.duplicate()
				chunk.cells[cell_pos].sources.erase(entity_id)
	update_lock.unlock()

	logger.debug("Unregistered entity %s" % entity.name)

func debug_draw(entity: Node2D, enabled: bool) -> void:
	_debug_settings[entity.get_instance_id()] = enabled
	queue_redraw()
#endregion

#region Heat Management
## Update entity heat - now deposits at center and lets diffusion spread it
func update_entity_heat(entity: Node2D, delta: float, heat_type: String, factor: float = 1.0) -> void:
	if not _heatmaps.has(heat_type):
		return

	var entity_id: int = entity.get_instance_id()
	var config: Pheromone = _heatmaps[heat_type].config
	var base_heat: float = config.generating_rate * delta * factor

	## Only deposit at center cell - diffusion will spread it
	var center_update: Dictionary = calculate_center_heat_update(entity.global_position, base_heat)

	update_lock.lock()
	_apply_heat_update(entity_id, center_update, heat_type)
	update_lock.unlock()

## Legacy method for immediate spread (can be called directly if needed)
func update_entity_heat_immediate(entity: Node2D, delta: float, heat_type: String, factor: float = 1.0) -> void:
	if not _heatmaps.has(heat_type):
		return

	var entity_id: int = entity.get_instance_id()
	var base_heat: float = _heatmaps[heat_type].config.generating_rate * delta * factor
	var updates: Array[Dictionary] = calculate_heat_updates(
		entity.global_position,
		base_heat,
		_heatmaps[heat_type].config.heat_radius
	)

	update_lock.lock()
	for update: Dictionary in updates:
		_apply_heat_update(entity_id, update, heat_type)
	update_lock.unlock()

func _apply_heat_update(entity_id: int, update: Dictionary, heat_type: String) -> void:
	var chunk_pos: Vector2i = world_to_chunk(update.cell)
	var local_pos: Vector2i = world_to_local_cell(update.cell)

	if not _heatmaps[heat_type].chunks.has(chunk_pos):
		_heatmaps[heat_type].chunks[chunk_pos] = create_chunk_data()

	var chunk: Dictionary = _heatmaps[heat_type].chunks[chunk_pos]
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

	var query_data: Dictionary = {
		"colony_id": entity.colony.get_instance_id() if entity is Ant else entity.get_instance_id(),
		"world_cell": world_to_cell(entity.global_position)
	}

	var chunk_pos: Vector2i = world_to_chunk(query_data.world_cell)
	var local_pos: Vector2i = world_to_local_cell(query_data.world_cell)

	update_lock.lock()
	var result: float = 0.0

	if _heatmaps[heat_type].chunks.has(chunk_pos):
		var chunk: Dictionary = _heatmaps[heat_type].chunks[chunk_pos]
		if chunk.cells.has(local_pos):
			result = get_colony_heat(chunk.cells[local_pos], query_data.colony_id)

	update_lock.unlock()
	return result

func get_cells_in_radius(world_pos: Vector2, radius: float, heat_type: String) -> Array[Dictionary]:
	if not _heatmaps.has(heat_type):
		return [] as Array[Dictionary]

	update_lock.lock()
	var cells: Array[Dictionary] = get_cells_in_radius_data(world_pos, radius, _heatmaps[heat_type])
	update_lock.unlock()

	return cells
#endregion

#region Drawing and Visualization
func _draw() -> void:
	if not camera:
		return

	update_lock.lock()
	for heat_type: String in _heatmaps:
		var heatmap: Dictionary = _heatmaps[heat_type]
		_draw_heatmap(heatmap)
	update_lock.unlock()

func _draw_heatmap(heatmap: Dictionary) -> void:
	for chunk_pos: Vector2i in heatmap.chunks:
		var chunk: Dictionary = heatmap.chunks[chunk_pos]
		for local_pos: Vector2i in chunk.cells:
			var cell: Dictionary = chunk.cells[local_pos]
			var world_cell: Vector2i = chunk_to_world_cell(chunk_pos, local_pos)
			var visible_heat: float = calculate_visible_heat(cell, _debug_settings)

			if visible_heat <= 0:
				continue

			var world_pos: Vector2 = cell_to_world(world_cell)
			var rect: Rect2 = Rect2(
				world_pos,
				Vector2.ONE * STYLE.CELL_SIZE
			)

			var t: float = visible_heat / STYLE.MAX_HEAT
			var color: Color = get_cell_color(t, heatmap.config)
			draw_rect(rect, color)
#endregion

#region Navigation
func is_cell_navigable(pos: Vector2) -> bool:
	if _nav_map == RID() or _nav_map == null or not NavigationServer2D.map_is_active(_nav_map):
		return true

	var regions: Array[RID] = NavigationServer2D.map_get_regions(_nav_map)
	if regions.is_empty():
		return true

	for region: RID in regions:
		if region and NavigationServer2D.region_owns_point(region, pos):
			return true

	return false
#endregion
