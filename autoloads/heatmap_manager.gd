extends Node2D

#region Constants
const STYLE = {
	"CELL_SIZE": 50,
	"CHUNK_SIZE": 16,
	"MAX_HEAT": 100.0
}

#region Member Variables
var map_size: Vector2
var update_thread: Thread
var update_lock: Mutex
var _nav_map: RID
var camera: Camera2D
var _heatmaps: Dictionary[String, HeatmapInstance] = {} 
var _debug_settings: Dictionary = {}
var update_timer: float = 0.0
var update_interval: float = 1.0
var logger: Logger
var _is_quitting: bool = false
var _last_decay_time: int = 0
#endregion

#region Inner Classes
class HeatCell:
	var heat: float = 0.0
	var sources: Dictionary[int, float] = {}  # entity_id -> heat_value

	func add_heat(entity_id: int, amount: float, max_heat: float) -> void:
		if not sources.has(entity_id):
			sources[entity_id] = 0.0
		sources[entity_id] = minf(sources[entity_id] + amount, max_heat)
		heat = HeatmapUtils.HeatCalculator.calculate_total_heat(sources.values())

	func remove_source(entity_id: int) -> void:
		sources.erase(entity_id)
		heat = HeatmapUtils.HeatCalculator.calculate_total_heat(sources.values())

	func decay(delta: float, decay_rate: float) -> bool:
		var any_active = false
		for entity_id in sources:
			sources[entity_id] = HeatmapUtils.HeatCalculator.apply_decay(
				sources[entity_id],
				decay_rate,
				delta
			)
			if sources[entity_id] > 0:
				any_active = true
		heat = HeatmapUtils.HeatCalculator.calculate_total_heat(sources.values())
		return any_active

	func get_total_heat_for_colony(colony_id: int) -> float:
		var colony_sources: Array[float] = []
		for source_id in sources:
			var source: Node2D = instance_from_id(source_id)
			if is_instance_valid(source):
				var source_colony_id: int = source.colony.get_instance_id() if source is Ant else source.get_instance_id()
				if source_colony_id == colony_id:
					colony_sources.append(sources[source_id])
		return HeatmapUtils.HeatCalculator.calculate_total_heat(colony_sources)

class HeatChunk:
	var cells: Dictionary[Vector2i, HeatCell] = {}  # Vector2i -> HeatCell
	var active_cells: int = 0
	var last_update_time: int = 0

	func get_or_create_cell(local_pos: Vector2i) -> HeatCell:
		if not cells.has(local_pos):
			cells[local_pos] = HeatCell.new()
		return cells[local_pos]

	func update(delta: float, decay_rate: float) -> bool:
		active_cells = 0
		var cells_to_remove: Array = []
		var cell_heats: Array[float] = []

		for pos in cells:
			if not cells[pos].decay(delta, decay_rate):
				cells_to_remove.append(pos)
			else:
				active_cells += 1
				cell_heats.append(cells[pos].heat)

		for pos in cells_to_remove:
			cells.erase(pos)

		last_update_time = Time.get_ticks_msec()
		return HeatmapUtils.StateUtils.is_chunk_active(cell_heats)

class HeatmapInstance:
	var chunks: Dictionary[Vector2i, HeatChunk] = {}  # Vector2i -> HeatChunk
	var config: Pheromone
	
	func _init(p_config: Pheromone) -> void:
		config = p_config
	
	func get_or_create_chunk(chunk_pos: Vector2i) -> HeatChunk:
		if not chunks.has(chunk_pos):
			chunks[chunk_pos] = HeatChunk.new()
		return chunks[chunk_pos]
#endregion

func _init() -> void:
	logger = Logger.new("heatmap_manager", DebugLogger.Category.MOVEMENT)
	update_lock = Mutex.new()
	top_level = true
	_last_decay_time = Time.get_ticks_msec()

func _ready() -> void:
	_start_update_thread()

## Generate [HeatmapManager.HeatmapInstance] that represents the [Pheromone].
func create_heatmap_type(pheromone: Pheromone) -> void:
	var heatmap_name = pheromone.name.to_lower()
	if not _heatmaps.has(heatmap_name):
		_heatmaps[heatmap_name] = HeatmapInstance.new(
			pheromone
		)

#region Thread Management
func _start_update_thread() -> void:
	update_thread = Thread.new()
	update_thread.start(_update_heatmap_thread)

func _update_heatmap_thread() -> void:
	while not _is_quitting:
		var current_time: int = Time.get_ticks_msec()
		var time_since_decay: float = (current_time - _last_decay_time) / 1000.0

		# Only attempt update if enough time has passed
		if time_since_decay >= update_interval:
			# Try to acquire lock, don't block if can't get it
			if update_lock.try_lock():
				_process_decay(time_since_decay)
				update_lock.unlock()
				_last_decay_time = current_time

		call_thread_safe("queue_redraw")
		# Always sleep to prevent tight loop
		OS.delay_msec(int(update_interval * 100))  # Check 10 times per interval

func _process_decay(delta: float) -> void:
	for heat_type in _heatmaps:
		var heatmap: HeatmapInstance = _heatmaps[heat_type]
		var chunks_to_remove: Array = []

		for chunk_pos in heatmap.chunks:
			var chunk: HeatChunk = heatmap.chunks[chunk_pos]
			if not chunk.update(delta, heatmap.config.decay_rate):
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

#region Setup Functions
func setup_navigation() -> void:
	_nav_map = get_world_2d().get_navigation_map()

func setup_camera(p_camera: Camera2D) -> void:
	camera = p_camera
#endregion

#region Entity Management
## Register entity with the heatmap system
func register_entity(entity: Node2D) -> void:
	var entity_id: int = entity.get_instance_id()
	if not _debug_settings.has(entity_id):
		_debug_settings[entity_id] = false
		logger.debug("Registered entity %s" % entity.name)

func unregister_entity(entity: Node2D) -> void:
	var entity_id: int = entity.get_instance_id()
	# Prepare data outside lock
	var entity_data = {
		"id": entity_id,
		"name": entity.name
	}

	update_lock.lock()
	# Quick removal operation
	_debug_settings.erase(entity_id)
	for heatmap in _heatmaps.values():
		for chunk in heatmap.chunks.values():
			for cell in chunk.cells.values():
				cell.remove_source(entity_id)
	update_lock.unlock()

	logger.debug("Unregistered entity %s" % entity_data.name)

func debug_draw(entity: Node2D, enabled: bool) -> void:
	_debug_settings[entity.get_instance_id()] = enabled
	queue_redraw()
#endregion

#region Heat Management
## Adds heat from an entity to a cell
func update_entity_heat(entity: Node2D, delta: float, heat_type: String, factor: float = 1.0) -> void:
	if not _heatmaps.has(heat_type):
		return

	# Prepare data outside lock
	var update_data = {
		"entity_id": entity.get_instance_id(),
		"center_cell": NavigationUtils.GridUtils.world_to_cell(entity.global_position, STYLE["CELL_SIZE"]),
		"base_heat": _heatmaps[heat_type].config.generating_rate * delta * factor,
		"heat_type": heat_type
	}

	update_lock.lock()
	_update_movement_heat(update_data)
	update_lock.unlock()

func _update_movement_heat(data: Dictionary) -> void:
	var heatmap := _heatmaps[data.heat_type]
	var cells_to_update := HeatmapUtils.StateUtils.get_cells_to_update(
		data.center_cell,
		heatmap.config.heat_radius
	)

	for cell in cells_to_update:
		var distance: float = data.center_cell.distance_to(cell)
		var heat := HeatmapUtils.HeatCalculator.calculate_cell_heat(
			data.base_heat,
			distance,
			STYLE.MAX_HEAT
		)
		_add_heat_to_cell(data.entity_id, cell, heat, data.heat_type)
		
func _add_heat_to_cell(entity_id: int, world_cell: Vector2i, amount: float, heat_type: String) -> void:
	var chunk_pos := NavigationUtils.GridUtils.world_to_chunk(world_cell, STYLE.CHUNK_SIZE)
	var local_pos := NavigationUtils.GridUtils.world_to_local_cell(world_cell, STYLE.CHUNK_SIZE)
	var heatmap := _heatmaps[heat_type]
	var chunk := heatmap.get_or_create_chunk(chunk_pos)
	var cell := chunk.get_or_create_cell(local_pos)
	cell.add_heat(entity_id, amount, STYLE.MAX_HEAT)

#region Heat Direction Calculation

func _calculate_cell_influence(cell_data: Dictionary, query_data: Dictionary) -> float:
	var cell: HeatCell = cell_data.cell
	var total_heat: float = 0.0

	for source_id in cell.sources:
		if source_id == query_data.entity_id:  # Don't be influenced by own heat
			continue
		total_heat += cell.sources[source_id]

	return total_heat

func get_heat_at_position(entity: Node2D, heat_type: String) -> float:
	if not _heatmaps.has(heat_type):
		return 0.0

	var query_data = {
		"colony_id": entity.colony.get_instance_id() if entity is Ant else entity.get_instance_id(),
		"world_cell": NavigationUtils.GridUtils.world_to_cell(entity.global_position, STYLE.CELL_SIZE),
		"heat_type": heat_type
	}

	var result: float = 0.0
	update_lock.lock()
	result = _get_heat_for_query(query_data)
	update_lock.unlock()

	return result

func _get_heat_for_query(data: Dictionary) -> float:
	var chunk_pos: Vector2i = NavigationUtils.GridUtils.world_to_chunk(data.world_cell, STYLE.CHUNK_SIZE)
	var local_pos: Vector2i = NavigationUtils.GridUtils.world_to_local_cell(data.world_cell, STYLE.CHUNK_SIZE)
	var heatmap: HeatmapInstance = _heatmaps[data.heat_type]

	if not heatmap.chunks.has(chunk_pos):
		return 0.0

	var chunk: HeatChunk = heatmap.chunks[chunk_pos]
	if not chunk.cells.has(local_pos):
		return 0.0

	var cell: HeatCell = chunk.cells[local_pos]
	return cell.get_total_heat_for_colony(data.colony_id)
#endregion

#region Drawing and Visualization
func _draw() -> void:
	if not camera:
		return

	update_lock.lock()
	for heat_type in _heatmaps:
		var heatmap: HeatmapInstance = _heatmaps[heat_type]
		_draw_heatmap(heatmap)
	update_lock.unlock()

func _draw_heatmap(heatmap: HeatmapInstance) -> void:
	for chunk_pos in heatmap.chunks:
		var chunk: HeatChunk = heatmap.chunks[chunk_pos]
		for local_pos in chunk.cells:
			var cell: HeatCell = chunk.cells[local_pos]
			var world_cell: Vector2i = NavigationUtils.GridUtils.chunk_to_world_cell(chunk_pos, local_pos, STYLE.CHUNK_SIZE)
			var visible_heat: float = _calculate_visible_heat(cell)

			if visible_heat <= 0:
				continue

			var world_pos: Vector2 = NavigationUtils.GridUtils.cell_to_world(world_cell, STYLE.CELL_SIZE)
			var rect: Rect2 = Rect2(
				world_pos,
				Vector2.ONE * STYLE.CELL_SIZE
			)

			var t: float = visible_heat / STYLE.MAX_HEAT
			var color: Color = _get_cell_color(t, heatmap.config)
			draw_rect(rect, color)

func _calculate_visible_heat(cell: HeatCell) -> float:
	var visible_heat: float = 0.0
	for source_id in cell.sources:
		var entity: Node2D = instance_from_id(source_id)
		if not is_instance_valid(entity):
			continue

		if entity is Ant:
			var colony: Node2D = entity.colony
			if colony and (_debug_settings.get(source_id, false) or _debug_settings.get(colony.get_instance_id(), false)):
				visible_heat += cell.sources[source_id]
	return visible_heat

func _get_cell_color(t: float, config: Pheromone) -> Color:
	return config.start_color.lerp(config.end_color, t)

#region Utility Functions
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

func get_cells_in_radius(world_pos: Vector2, radius: float, heat_type: String) -> Array[Dictionary]:
	var center_cell: Vector2i = NavigationUtils.GridUtils.world_to_cell(world_pos, STYLE.CELL_SIZE)
	var cells_radius: int = ceili(radius / STYLE.CELL_SIZE)
	var found_cells: Array[Dictionary] = []

	var chunk_radius: int = ceili(float(cells_radius) / STYLE.CHUNK_SIZE)
	var center_chunk: Vector2i = NavigationUtils.GridUtils.world_to_chunk(center_cell, STYLE.CHUNK_SIZE)

	var heatmap: HeatmapInstance = _heatmaps[heat_type]
	for dx in range(-chunk_radius, chunk_radius + 1):
		for dy in range(-chunk_radius, chunk_radius + 1):
			var check_chunk: Vector2i = center_chunk + Vector2i(dx, dy)
			if not heatmap.chunks.has(check_chunk):
				continue

			var chunk: HeatChunk = heatmap.chunks[check_chunk]
			for local_pos in chunk.cells:
				var cell: HeatCell = chunk.cells[local_pos]
				var world_cell: Vector2i = NavigationUtils.GridUtils.chunk_to_world_cell(check_chunk, local_pos, STYLE.CHUNK_SIZE)
				var cell_pos: Vector2 = NavigationUtils.GridUtils.cell_to_world(world_cell, STYLE.CELL_SIZE)

				if cell.heat > 0 and world_pos.distance_to(cell_pos) <= radius:
					found_cells.append({
						"position": cell_pos,
						"chunk_pos": check_chunk,
						"local_pos": local_pos,
						"heat": cell.heat,
						"sources": cell.sources,
						"cell": cell
					})

	return found_cells
