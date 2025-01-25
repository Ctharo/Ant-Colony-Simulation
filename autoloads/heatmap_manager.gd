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
var _heatmaps: Dictionary = {}  # int -> HeatmapInstance
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
	var sources: Dictionary = {}  # entity_id -> heat_value

	func add_heat(entity_id: int, amount: float, max_heat: float) -> void:
		if not sources.has(entity_id):
			sources[entity_id] = 0.0
		sources[entity_id] = minf(sources[entity_id] + amount, max_heat)
		_update_total_heat()

	func remove_source(entity_id: int) -> void:
		sources.erase(entity_id)
		_update_total_heat()

	func decay(delta: float, decay_rate: float) -> bool:
		var any_active = false
		for entity_id in sources:
			sources[entity_id] = maxf(0.0, sources[entity_id] - decay_rate * delta)
			if sources[entity_id] > 0:
				any_active = true
		_update_total_heat()
		return any_active

	func get_total_heat_for_colony(colony_id: int) -> float:
		var total: float = 0.0
		for source_id in sources:
			var source: Node2D = instance_from_id(source_id)
			if is_instance_valid(source):
				var source_colony_id: int = source.colony.get_instance_id() if source is Ant else source.get_instance_id()
				if source_colony_id == colony_id:
					total += sources[source_id]
		return total

	func _update_total_heat() -> void:
		heat = 0.0
		for contribution in sources.values():
			heat += contribution

class HeatChunk:
	var cells: Dictionary = {}  # Vector2i -> HeatCell
	var active_cells: int = 0
	var last_update_time: int = 0

	func get_or_create_cell(local_pos: Vector2i) -> HeatCell:
		if not cells.has(local_pos):
			cells[local_pos] = HeatCell.new()
		return cells[local_pos]

	func update(delta: float, decay_rate: float) -> bool:
		active_cells = 0
		var cells_to_remove: Array = []

		for pos in cells:
			if not cells[pos].decay(delta, decay_rate):
				cells_to_remove.append(pos)
			else:
				active_cells += 1

		for pos in cells_to_remove:
			cells.erase(pos)

		last_update_time = Time.get_ticks_msec()
		return active_cells > 0

class HeatmapInstance:
	var chunks: Dictionary = {}  # Vector2i -> HeatChunk
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
func update_entity_heat(entity: Node2D, delta: float, heat_type: String, factor: float = 1.0) -> void:
	if not is_instance_valid(entity) or not _heatmaps.has(heat_type):
		return

	# Prepare data outside lock
	var update_data = {
		"entity_id": entity.get_instance_id(),
		"center_cell": world_to_cell(entity.global_position),
		"base_heat": _heatmaps[heat_type].config.generating_rate * delta * factor,
		"heat_type": heat_type
	}

	update_lock.lock()
	_update_movement_heat(update_data)
	update_lock.unlock()

func _update_movement_heat(data: Dictionary) -> void:
	var heatmap: HeatmapInstance = _heatmaps[data.heat_type]
	var radius: int = heatmap.config.heat_radius
	var center_cell: Vector2i = data.center_cell

	var updates: Array[Dictionary] = []
	# Gather all updates without modifying data
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var cell: Vector2i = center_cell + Vector2i(dx, dy)
			var distance: float = center_cell.distance_to(cell)

			if distance <= radius:
				updates.append({
					"cell": cell,
					"heat": data.base_heat / (1 + distance * distance)
				})

	# Apply all updates at once
	for update in updates:
		_add_heat_to_cell(data.entity_id, update.cell, update.heat, data.heat_type)

func _add_heat_to_cell(entity_id: int, world_cell: Vector2i, amount: float, heat_type: String) -> void:
	var chunk_pos: Vector2i = world_to_chunk(world_cell)
	var local_pos: Vector2i = world_to_local_cell(world_cell)
	var heatmap: HeatmapInstance = _heatmaps[heat_type]
	var chunk: HeatChunk = heatmap.get_or_create_chunk(chunk_pos)
	var cell: HeatCell = chunk.get_or_create_cell(local_pos)
	cell.add_heat(entity_id, amount, STYLE.MAX_HEAT)

#region Heat Direction Calculation
func get_heat_direction(entity: Node2D, heat_type: String) -> Vector2:
	if not is_instance_valid(entity) or not _heatmaps.has(heat_type):
		return Vector2.ZERO

	var query_data = {
		"entity_id": entity.get_instance_id(),
		"position": entity.global_position,
		"heat_type": heat_type
	}

	update_lock.lock()
	var result = _calculate_heat_direction(query_data)
	update_lock.unlock()

	return result

## TODO: Needs to get heat direction respecting olfactory range/physics
## i.e. if no heat touching ant, no heat direction
func _calculate_heat_direction(data: Dictionary) -> Vector2:
	var heatmap: HeatmapInstance = _heatmaps[data.heat_type]
	var radius: float = heatmap.config.heat_radius * STYLE.CELL_SIZE * 2
	var direction: Vector2 = Vector2.ZERO
	var total_weight: float = 0.0

	var nearby_cells = get_cells_in_radius(data.position, radius, data.heat_type)

	for cell_data in nearby_cells:
		var heat = _calculate_cell_influence(cell_data, data)
		if heat > 0:
			var distance: float = data.position.distance_to(cell_data.position)
			var falloff: float = 1.0 / (1.0 + distance * 0.1)
			var away_vector: Vector2 = (data.position - cell_data.position).normalized()

			var weight = heat * falloff
			direction += away_vector * weight
			total_weight += weight

	if total_weight > 0:
		direction = direction.normalized()

	return direction

func _find_best_navigable_direction(base_direction: Vector2, world_pos: Vector2, base_weight: float) -> Vector2:
	var normalized_direction = base_direction.normalized()
	var check_distance = STYLE.CELL_SIZE * 2
	var base_target = world_pos + normalized_direction * check_distance

	if is_cell_navigable(base_target):
		return base_direction

	var test_angles = [PI/12, -PI/12, PI/6, -PI/6, PI/4, -PI/4, PI/3, -PI/3]

	for angle in test_angles:
		var test_direction = normalized_direction.rotated(angle)
		var test_target = world_pos + test_direction * check_distance

		if is_cell_navigable(test_target):
			return test_direction * base_weight

	return normalized_direction * (base_weight * 0.1)

func _calculate_cell_influence(cell_data: Dictionary, query_data: Dictionary) -> float:
	var cell: HeatCell = cell_data.cell
	var total_heat: float = 0.0

	for source_id in cell.sources:
		if source_id != query_data.entity_id:  # Don't be influenced by own heat
			total_heat += cell.sources[source_id]

	return total_heat

func get_heat_at_position(entity: Node2D, heat_type: String) -> float:
	if not is_instance_valid(entity) or not _heatmaps.has(heat_type):
		return 0.0

	var query_data = {
		"colony_id": entity.colony.get_instance_id() if entity is Ant else entity.get_instance_id(),
		"world_cell": world_to_cell(entity.global_position),
		"heat_type": heat_type
	}

	var result: float = 0.0
	update_lock.lock()
	result = _get_heat_for_query(query_data)
	update_lock.unlock()

	return result

func _get_heat_for_query(data: Dictionary) -> float:
	var chunk_pos: Vector2i = world_to_chunk(data.world_cell)
	var local_pos: Vector2i = world_to_local_cell(data.world_cell)
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
			var world_cell: Vector2i = chunk_to_world_cell(chunk_pos, local_pos)
			var visible_heat: float = _calculate_visible_heat(cell)

			if visible_heat <= 0:
				continue

			var world_pos: Vector2 = cell_to_world(world_cell)
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

#region Coordinate Conversions
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
	@warning_ignore("integer_division")
	return Vector2i(x % STYLE.CHUNK_SIZE, y % STYLE.CHUNK_SIZE)

func chunk_to_world_cell(chunk_pos: Vector2i, local_pos: Vector2i) -> Vector2i:
	return Vector2i(
		chunk_pos.x * STYLE.CHUNK_SIZE + local_pos.x,
		chunk_pos.y * STYLE.CHUNK_SIZE + local_pos.y
	)

func chunk_to_world(chunk_pos: Vector2i) -> Vector2:
	return Vector2(chunk_pos * STYLE.CHUNK_SIZE * STYLE.CELL_SIZE)

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
	var center_cell: Vector2i = world_to_cell(world_pos)
	var cells_radius: int = ceili(radius / STYLE.CELL_SIZE)
	var found_cells: Array[Dictionary] = []

	var chunk_radius: int = ceili(float(cells_radius) / STYLE.CHUNK_SIZE)
	var center_chunk: Vector2i = world_to_chunk(center_cell)

	var heatmap: HeatmapInstance = _heatmaps[heat_type]
	for dx in range(-chunk_radius, chunk_radius + 1):
		for dy in range(-chunk_radius, chunk_radius + 1):
			var check_chunk: Vector2i = center_chunk + Vector2i(dx, dy)
			if not heatmap.chunks.has(check_chunk):
				continue

			var chunk: HeatChunk = heatmap.chunks[check_chunk]
			for local_pos in chunk.cells:
				var cell: HeatCell = chunk.cells[local_pos]
				var world_cell: Vector2i = chunk_to_world_cell(check_chunk, local_pos)
				var cell_pos: Vector2 = cell_to_world(world_cell)

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
