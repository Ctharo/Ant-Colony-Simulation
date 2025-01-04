class_name HeatmapManager
extends Node2D

#region Constants
const STYLE = {
	"CELL_SIZE": 25,
	"CHUNK_SIZE": 16,
	"MAX_HEAT": 100.0,
	"DECAY_RATE":  0.00025,
	"HEAT_RADIUS": 2,
	"HEAT_PER_SECOND": 10.0,
	"BOUNDARY_HEAT_MULTIPLIER": 8.0,
	"BOUNDARY_CHECK_RADIUS": 3,
	"BOUNDARY_PENETRATION_DEPTH": 2,
	"DEBUG_COLORS": {
		"START": Color(Color.LIGHT_GREEN, 0.3),
		"END": Color(Color.RED, 0.3),
		"BOUNDARY": Color(1, 0, 1, 0.4),
		"REPULSION": Color(1, 0, 0, 0.6)
	}
}

#region Member Variables
var map_size: Vector2
var _spatial_index: QuadTree
var update_thread: Thread
var update_lock: Mutex
var _nav_map: RID
var camera: Camera2D
var _chunks: Dictionary = {}
var _debug_settings: Dictionary = {}
var _boundary_repulsion_points: Array[Dictionary] = []
var update_timer: float = 0.0
var update_interval: float = 1
var logger: Logger
var _is_quitting: bool = false
#endregion

#region Inner Classes
class HeatCell:
	var heat: float = 0.0
	var sources: Dictionary = {}

	func add_heat(entity_id: int, amount: float) -> void:
		if not sources.has(entity_id):
			sources[entity_id] = 0.0
		sources[entity_id] = minf(sources[entity_id] + amount, STYLE.MAX_HEAT)
		_update_total_heat()

	func remove_source(entity_id: int) -> void:
		if sources.has(entity_id):
			sources.erase(entity_id)
			_update_total_heat()

	func decay(delta: float) -> bool:
		var any_active = false
		for entity_id in sources:
			sources[entity_id] = maxf(0.0, sources[entity_id] - STYLE.DECAY_RATE * delta)
			if sources[entity_id] > 0:
				any_active = true
		_update_total_heat()
		return any_active

	func _update_total_heat() -> void:
		heat = 0.0
		for contribution in sources.values():
			heat += contribution

class HeatChunk:
	var cells: Dictionary = {}
	var active_cells: int = 0
	var last_update_time: int = 0

	func get_or_create_cell(local_pos: Vector2i) -> HeatCell:
		if not cells.has(local_pos):
			cells[local_pos] = HeatCell.new()
		return cells[local_pos]

	func update(delta: float) -> bool:
		active_cells = 0
		var cells_to_remove: Array = []

		for pos in cells:
			if not cells[pos].decay(delta):
				cells_to_remove.append(pos)
			else:
				active_cells += 1

		for pos in cells_to_remove:
			cells.erase(pos)

		last_update_time = Time.get_ticks_msec()
		return active_cells > 0
#endregion
	
func _init() -> void:
	name = "HeatmapManager"
	logger = Logger.new("heatmap_manager", DebugLogger.Category.MOVEMENT)
	update_lock = Mutex.new()
	_init_spatial_index()
	top_level = true  # Make sure transforms are in global space

func _ready() -> void:
	_start_update_thread()
	setup_navigation()
	


func _start_update_thread() -> void:
	update_thread = Thread.new()
	update_thread.start(_update_heatmap_thread)

func _init_spatial_index() -> void:
	# Initialize with proper size for the map plus padding
	var world_bounds = QuadTree.QuadTreeBounds.new(
		Vector2(map_size) / 2,  # Center
		Vector2(map_size) * 1.5  # Add 50% padding for overflow
	)
	_spatial_index = QuadTree.new(world_bounds)

#region Thread Management
func _update_heatmap_thread() -> void:
	while not _is_quitting:
		update_lock.lock()
		var current_time: int = Time.get_ticks_msec()

		for chunk_pos in _chunks.keys():
			var chunk: HeatChunk = _chunks[chunk_pos]
			if current_time - chunk.last_update_time >= update_interval * 1000:
				if not chunk.update(update_interval):
					_chunks.erase(chunk_pos)

		update_lock.unlock()
		OS.delay_msec(int(update_interval * 1000))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_cleanup_thread()

func _cleanup_thread() -> void:
	if update_thread and update_thread.is_started():
		_is_quitting = true
		update_thread.wait_to_finish()

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
	update_lock.lock()
	for chunk in _chunks.values():
		for cell in chunk.cells.values():
			cell.remove_source(entity_id)
	_debug_settings.erase(entity_id)
	update_lock.unlock()
	logger.debug("Unregistered entity %s" % entity.name)

func debug_draw(entity: Node2D, enabled: bool) -> void:
	_debug_settings[entity.get_instance_id()] = enabled
	queue_redraw()
#endregion

#region Process and Draw
func _process(delta: float) -> void:
	update_timer += delta
	if update_timer <= update_interval:
		return

	update_lock.lock()
	
	# Instead of clearing and rebuilding every frame,
	# only update when heat changes
	var needs_update = false
	
	for chunk_pos in _chunks:
		var chunk: HeatChunk = _chunks[chunk_pos]
		# Check if chunk was updated since last process
		if chunk.last_update_time > update_timer:
			needs_update = true
			break
	
	if needs_update:
		_spatial_index.clear()
		# Update spatial index with all active heat cells
		for chunk_pos in _chunks:
			var chunk: HeatChunk = _chunks[chunk_pos]
			if chunk.active_cells == 0:
				continue
				
			for local_pos in chunk.cells:
				var cell: HeatCell = chunk.cells[local_pos]
				if cell.heat <= 0:
					continue
					
				var world_cell = chunk_to_world_cell(chunk_pos, local_pos)
				var world_pos = cell_to_world(world_cell)
				
				_spatial_index.insert(world_pos, {
					"position": world_pos,
					"chunk_pos": chunk_pos,
					"local_pos": local_pos,
					"heat": cell.heat
				})

	_boundary_repulsion_points.clear()
	update_lock.unlock()

	if _debug_settings.values().has(true):
		queue_redraw()
	update_timer = 0.0

func _draw() -> void:
	if not camera:
		return

	update_lock.lock()

	for chunk_pos in _chunks:
		var chunk: HeatChunk = _chunks[chunk_pos]
		

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
			var color: Color = _get_cell_color(t, world_pos)
			draw_rect(rect, color)

	update_lock.unlock()

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

func _get_cell_color(t: float, pos: Vector2) -> Color:
	if not is_cell_navigable(pos):
		var color: Color = STYLE.DEBUG_COLORS.BOUNDARY
		color.a *= t
		return color
	return STYLE.DEBUG_COLORS.START.lerp(STYLE.DEBUG_COLORS.END, t)
#endregion

#region Heat Direction Calculation
func get_heat_direction(entity: Node2D, world_pos: Vector2) -> Vector2:
	if not is_instance_valid(entity):
		return Vector2.ZERO

	var entity_id: int = entity.get_instance_id()
	var center_cell: Vector2i = world_to_cell(world_pos)
	
	update_lock.lock()
	
	# Calculate heat avoidance
	var heat_result = _calculate_heat_avoidance(center_cell, world_pos, entity_id)
	var direction = heat_result.direction
	var weight = heat_result.weight
	
	# Add boundary repulsion if needed
	var boundary_result = _calculate_boundary_repulsion(center_cell, world_pos)
	if boundary_result.weight > 0:
		direction += boundary_result.direction * STYLE.BOUNDARY_HEAT_MULTIPLIER
		weight += boundary_result.weight * STYLE.BOUNDARY_HEAT_MULTIPLIER
	
	if weight > 0:
		direction = direction.normalized() * minf(weight, STYLE.MAX_HEAT)
		direction = _find_best_navigable_direction(direction, world_pos, weight)
	
	update_lock.unlock()
	return direction

func _find_best_navigable_direction(base_direction: Vector2, world_pos: Vector2, base_weight: float) -> Vector2:
	var normalized_direction = base_direction.normalized()
	var check_distance = STYLE.CELL_SIZE * 2
	var base_target = world_pos + normalized_direction * check_distance
	
	# If base direction is navigable, use it
	if is_cell_navigable(base_target):
		return base_direction
		
	# Try angles in increasingly larger deviations
	var test_angles = [PI/12, -PI/12, PI/6, -PI/6, PI/4, -PI/4, PI/3, -PI/3]
	
	for angle in test_angles:
		var test_direction = normalized_direction.rotated(angle)
		var test_target = world_pos + test_direction * check_distance
		
		if is_cell_navigable(test_target):
			return test_direction * base_weight
			
	# If no direction is found, return a very small vector in original direction
	return normalized_direction * (base_weight * 0.1)  # Reduced magnitude when blocked
func _calculate_base_heat_direction(center_cell: Vector2i, world_pos: Vector2, entity_id: int) -> Dictionary:
	var direction: Vector2 = Vector2.ZERO
	var total_weight: float = 0.0

	# Boundary repulsion
	var boundary_result = _calculate_boundary_repulsion(center_cell, world_pos)
	direction += boundary_result.direction * STYLE.BOUNDARY_HEAT_MULTIPLIER
	total_weight += boundary_result.weight * STYLE.BOUNDARY_HEAT_MULTIPLIER

	# Heat avoidance
	var heat_result = _calculate_heat_avoidance(center_cell, world_pos, entity_id)
	direction += heat_result.direction
	total_weight += heat_result.weight

	if total_weight > 0.0:
		direction = direction / total_weight

	return {"direction": direction, "weight": total_weight}

func _calculate_boundary_repulsion(center_cell: Vector2i, world_pos: Vector2) -> Dictionary:
	var direction: Vector2 = Vector2.ZERO
	var total_weight: float = 0.0

	for dx in range(-STYLE.BOUNDARY_CHECK_RADIUS, STYLE.BOUNDARY_CHECK_RADIUS + 1):
		for dy in range(-STYLE.BOUNDARY_CHECK_RADIUS, STYLE.BOUNDARY_CHECK_RADIUS + 1):
			var cell: Vector2i = center_cell + Vector2i(dx, dy)
			var cell_pos: Vector2 = cell_to_world(cell)

			if not is_cell_navigable(cell_pos):
				var away_vector: Vector2 = (world_pos - cell_pos).normalized()
				var distance: float = world_pos.distance_to(cell_pos)
				var weight: float = 1.0 / (1.0 + distance * 0.1)

				direction += away_vector * weight
				total_weight += weight

	if total_weight > 0.0:
		direction /= total_weight

	return {"direction": direction, "weight": total_weight}

func _calculate_heat_avoidance(center_cell: Vector2i, world_pos: Vector2, exclude_entity_id: int) -> Dictionary:
	var direction: Vector2 = Vector2.ZERO
	var total_weight: float = 0.0

	# Query radius in world coordinates
	var query_radius = STYLE.HEAT_RADIUS * STYLE.CELL_SIZE * 2
	var nearby_data = _spatial_index.query_radius(world_pos, query_radius)

	for cell_data in nearby_data:
		# Data is now guaranteed to have position
		var cell_pos: Vector2 = cell_data.position
		var chunk: HeatChunk = _chunks[cell_data.chunk_pos]
		var cell_obj: HeatCell = chunk.cells[cell_data.local_pos]
		
		# Skip unnavigable cells
		if not is_cell_navigable(cell_pos):
			continue

		# Calculate heat influence
		var heat: float = 0.0
		for source_id in cell_obj.sources:
			if source_id != exclude_entity_id:
				heat += cell_obj.sources[source_id]

		if heat > 0:
			var distance: float = world_pos.distance_to(cell_pos)
			var falloff: float = 1.0 / (1.0 + distance * 0.1)
			var away_vector: Vector2 = (world_pos - cell_pos).normalized()
			
			# Weight based on heat and distance
			var weight = heat * falloff
			direction += away_vector * weight
			total_weight += weight

	if total_weight > 0:
		direction = direction.normalized()
		
	return {
		"direction": direction,
		"weight": total_weight
	}
	
#endregion

#region Heat Management
func update_entity_heat(entity: Node2D, delta: float, factor: float = 1.0) -> void:
	if not is_instance_valid(entity):
		return

	var entity_id: int = entity.get_instance_id()
	var center_cell: Vector2i = world_to_cell(entity.global_position)
	var base_heat: float = STYLE.HEAT_PER_SECOND * delta * factor

	update_lock.lock()
	_update_movement_heat(entity_id, center_cell, base_heat)

	if entity is Colony:
		_update_boundary_repulsion(entity_id, center_cell, base_heat * STYLE.BOUNDARY_HEAT_MULTIPLIER)
	update_lock.unlock()

func _update_movement_heat(entity_id: int, center_cell: Vector2i, base_heat: float) -> void:
	for dx in range(-STYLE.HEAT_RADIUS, STYLE.HEAT_RADIUS + 1):
		for dy in range(-STYLE.HEAT_RADIUS, STYLE.HEAT_RADIUS + 1):
			var cell: Vector2i = center_cell + Vector2i(dx, dy)
			var cell_pos: Vector2 = cell_to_world(cell)
			var distance: float = center_cell.distance_to(cell)

			if distance <= STYLE.HEAT_RADIUS and is_cell_navigable(cell_pos):
				var heat: float = base_heat / (1 + distance * distance)
				_add_heat_to_cell(entity_id, cell, heat)

func _update_boundary_repulsion(entity_id: int, center_cell: Vector2i, base_heat: float) -> void:
	for dx in range(-STYLE.BOUNDARY_CHECK_RADIUS, STYLE.BOUNDARY_CHECK_RADIUS + 1):
		for dy in range(-STYLE.BOUNDARY_CHECK_RADIUS, STYLE.BOUNDARY_CHECK_RADIUS + 1):
			var check_cell: Vector2i = center_cell + Vector2i(dx, dy)
			var check_pos: Vector2 = cell_to_world(check_cell)

			if not is_cell_navigable(check_pos):
				_create_repulsion_from_boundary(entity_id, check_cell, cell_to_world(center_cell), base_heat)

func _create_repulsion_from_boundary(entity_id: int, boundary_cell: Vector2i, ant_pos: Vector2, base_heat: float) -> void:
	for dx in range(-STYLE.BOUNDARY_PENETRATION_DEPTH, STYLE.BOUNDARY_PENETRATION_DEPTH + 1):
		for dy in range(-STYLE.BOUNDARY_PENETRATION_DEPTH, STYLE.BOUNDARY_PENETRATION_DEPTH + 1):
			var inside_cell: Vector2i = boundary_cell + Vector2i(dx, dy)
			var inside_pos: Vector2 = cell_to_world(inside_cell)
			var to_ant: Vector2 = ant_pos - inside_pos
			var distance: float = to_ant.length()

			if distance < STYLE.CELL_SIZE * STYLE.BOUNDARY_CHECK_RADIUS:
				var repulsion_direction: Vector2 = to_ant.normalized()
				var repulsion_strength: float = base_heat * (1.0 / (1.0 + distance * 0.1))
				var repulsion_pos: Vector2 = inside_pos + repulsion_direction * STYLE.CELL_SIZE
				var repulsion_cell: Vector2i = world_to_cell(repulsion_pos)

				if is_cell_navigable(repulsion_pos):
					_add_heat_to_cell(entity_id, repulsion_cell, repulsion_strength)

					if _debug_settings[entity_id]:
						_boundary_repulsion_points.append({
							"position": repulsion_pos,
							"strength": repulsion_strength
						})
#endregion

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

#endregion

#region Utility Functions
## Checks if a cell position is navigable using NavigationServer2D's region queries
## Returns: Whether the position is navigable
func is_cell_navigable(pos: Vector2) -> bool:
	# Check for invalid navigation map states
	if _nav_map == RID() or _nav_map == null or not NavigationServer2D.map_is_active(_nav_map):
		return true
	
	# Ensure we have valid navigation regions before querying
	var regions: Array[RID] = NavigationServer2D.map_get_regions(_nav_map)
	if regions.is_empty():
		return true
	
	# Check if point is owned by any region in the navigation map
	for region in regions:
		if region and NavigationServer2D.region_owns_point(region, pos):
			return true
	
	return false

func _get_neighboring_chunks(chunk_pos: Vector2i) -> Array:
	var neighbors: Array = [chunk_pos]
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			neighbors.append(chunk_pos + Vector2i(dx, dy))
	return neighbors

func _add_heat_to_cell(entity_id: int, world_cell: Vector2i, amount: float) -> void:
	var chunk_pos: Vector2i = world_to_chunk(world_cell)
	var local_pos: Vector2i = world_to_local_cell(world_cell)
	var world_pos = cell_to_world(world_cell)

	if not _chunks.has(chunk_pos):
		_chunks[chunk_pos] = HeatChunk.new()

	var chunk: HeatChunk = _chunks[chunk_pos]
	var cell: HeatCell = chunk.get_or_create_cell(local_pos)
	var old_heat = cell.heat
	cell.add_heat(entity_id, amount)
	
	# Update spatial index immediately when heat changes
	if cell.heat > 0:
		_spatial_index.insert(world_pos, {
			"position": world_pos,
			"chunk_pos": chunk_pos,
			"local_pos": local_pos,
			"heat": cell.heat
		})
		
func get_heat_at_position(entity: Node2D, pos: Vector2) -> float:
	if not is_instance_valid(entity):
		return 0.0

	var colony_id: int = entity.colony.get_instance_id() if entity is Ant else entity.get_instance_id()
	var world_cell: Vector2i = world_to_cell(pos)
	var chunk_pos: Vector2i = world_to_chunk(world_cell)
	var local_pos: Vector2i = world_to_local_cell(world_cell)

	update_lock.lock()
	if not _chunks.has(chunk_pos):
		update_lock.unlock()
		return 0.0

	var chunk: HeatChunk = _chunks[chunk_pos]
	if not chunk.cells.has(local_pos):
		update_lock.unlock()
		return 0.0

	var cell: HeatCell = chunk.cells[local_pos]
	var total_heat: float = 0.0

	for source_id in cell.sources:
		var source: Node2D = instance_from_id(source_id)
		if is_instance_valid(source):
			var source_colony_id: int = source.colony.get_instance_id() if source is Ant else source.get_instance_id()
			if source_colony_id == colony_id:
				total_heat += cell.sources[source_id]

	update_lock.unlock()
	return total_heat
#endregion
