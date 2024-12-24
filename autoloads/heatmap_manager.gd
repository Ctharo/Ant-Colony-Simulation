class_name HeatmapManager
extends Node2D

#region Constants
const STYLE = {
	"CELL_SIZE": 15,
	"CHUNK_SIZE": 16,
	"MAX_HEAT": 100.0,
	"DECAY_RATE": 0.025,
	"HEAT_RADIUS": 1,
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

## Shared navigation map RID for all entities
var _nav_map: RID
var camera: Camera2D
var _chunks: Dictionary = {}
var _debug_settings: Dictionary = {}
var _boundary_repulsion_points: Array[Dictionary] = []
var logger: Logger

#region Custom Classes
class HeatCell:
	var heat: float = 0.0
	var sources: Dictionary = {}

	func add_heat(entity_id: int, amount: float) -> void:
		if not sources.has(entity_id):
			sources[entity_id] = 0.0
		sources[entity_id] = minf(sources[entity_id] + amount, STYLE.MAX_HEAT)
		_update_total_heat()

	func remove_source(entity_id: int) -> void:
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

	func get_or_create_cell(local_pos: Vector2i) -> HeatCell:
		if not cells.has(local_pos):
			cells[local_pos] = HeatCell.new()
		return cells[local_pos]

	func update(delta: float) -> bool:
		active_cells = 0
		var cells_to_remove = []

		for pos in cells:
			if not cells[pos].decay(delta):
				cells_to_remove.append(pos)
			else:
				active_cells += 1

		for pos in cells_to_remove:
			cells.erase(pos)

		return active_cells > 0

func _init() -> void:
	name = "HeatmapManager"
	logger = Logger.new("heatmap_manager", DebugLogger.Category.MOVEMENT)
	top_level = true  # Make sure transforms are in global space

func _ready() -> void:
	setup_navigation()

#region Setup Functions
func setup_navigation() -> void:
	_nav_map = get_world_2d().get_navigation_map()

func setup_camera(p_camera: Camera2D) -> void:
	camera = p_camera

#region Entity Management
func register_entity(entity: Node2D) -> void:
	var entity_id = entity.get_instance_id()
	if not _debug_settings.has(entity_id):
		_debug_settings[entity_id] = false
		logger.debug("Registered entity %s" % entity.name)

func unregister_entity(entity: Node2D) -> void:
	var entity_id = entity.get_instance_id()
	for chunk in _chunks.values():
		for cell in chunk.cells.values():
			cell.remove_source(entity_id)
	_debug_settings.erase(entity_id)
	logger.debug("Unregistered entity %s" % entity.name)

func debug_draw(entity: Node2D, enabled: bool) -> void:
	var entity_id = entity.get_instance_id()
	_debug_settings[entity_id] = enabled
	queue_redraw()

#region Process and Draw
func _process(delta: float) -> void:
	queue_redraw()
	for entity_id in _debug_settings:
		var entity = instance_from_id(entity_id)
		if entity:
			update_entity_heat(entity, entity.global_position, delta)

	_boundary_repulsion_points.clear()
	var chunks_to_remove = []

	for chunk_pos in _chunks:
		if not _chunks[chunk_pos].update(delta):
			chunks_to_remove.append(chunk_pos)

	for chunk_pos in chunks_to_remove:
		_chunks.erase(chunk_pos)

	if _debug_settings.values().has(true):
		queue_redraw()

func _draw() -> void:
	if not camera:
		return

	for chunk_pos in _chunks:
		var chunk = _chunks[chunk_pos]
		for local_pos in chunk.cells:
			var cell = chunk.cells[local_pos]
			var world_cell = chunk_to_world_cell(chunk_pos, local_pos)

			var visible_heat = _calculate_visible_heat(cell)
			if visible_heat <= 0:
				continue

			var world_pos = cell_to_world(world_cell)
			var draw_pos = world_pos

			var rect = Rect2(
				draw_pos,
				Vector2.ONE * STYLE.CELL_SIZE
			)

			var t = visible_heat / STYLE.MAX_HEAT
			var color = _get_cell_color(t, world_pos)
			draw_rect(rect, color)

func _calculate_visible_heat(cell: HeatCell) -> float:
	var visible_heat = 0.0
	for source_id in cell.sources:
		var entity = instance_from_id(source_id)
		if not entity:
			continue
		if entity is Ant:
			var colony = entity.colony
			if colony and (_debug_settings.get(source_id, false) or _debug_settings.get(colony.get_instance_id(), false)):
				visible_heat += cell.sources[source_id]
	return visible_heat

func _get_cell_color(t: float, pos: Vector2) -> Color:
	if not is_cell_navigable(pos):
		var color = STYLE.DEBUG_COLORS.BOUNDARY
		color.a *= t
		return color
	return STYLE.DEBUG_COLORS.START.lerp(STYLE.DEBUG_COLORS.END, t)

#region Heat Updates
func update_entity_heat(entity: Node2D, p_position: Vector2, delta: float) -> void:
	var entity_id = entity.get_instance_id()
	var center_cell = world_to_cell(p_position)
	var base_heat = STYLE.HEAT_PER_SECOND * delta

	_update_movement_heat(entity_id, center_cell, base_heat)

	if entity is Colony:
		_update_boundary_repulsion(entity_id, center_cell, base_heat * STYLE.BOUNDARY_HEAT_MULTIPLIER)

func _update_movement_heat(entity_id: int, center_cell: Vector2i, base_heat: float) -> void:
	for dx in range(-STYLE.HEAT_RADIUS, STYLE.HEAT_RADIUS + 1):
		for dy in range(-STYLE.HEAT_RADIUS, STYLE.HEAT_RADIUS + 1):
			var cell = center_cell + Vector2i(dx, dy)
			var cell_pos = cell_to_world(cell)
			var distance = center_cell.distance_to(cell)

			if distance <= STYLE.HEAT_RADIUS and is_cell_navigable(cell_pos):
				var heat = base_heat / (1 + distance * distance)
				_add_heat_to_cell(entity_id, cell, heat)

func _update_boundary_repulsion(entity_id: int, center_cell: Vector2i, base_heat: float) -> void:
	for dx in range(-STYLE.BOUNDARY_CHECK_RADIUS, STYLE.BOUNDARY_CHECK_RADIUS + 1):
		for dy in range(-STYLE.BOUNDARY_CHECK_RADIUS, STYLE.BOUNDARY_CHECK_RADIUS + 1):
			var check_cell = center_cell + Vector2i(dx, dy)
			var check_pos = cell_to_world(check_cell)

			if not is_cell_navigable(check_pos):
				_create_repulsion_from_boundary(entity_id, check_cell, cell_to_world(center_cell), base_heat)

func _create_repulsion_from_boundary(entity_id: int, boundary_cell: Vector2i, ant_pos: Vector2, base_heat: float) -> void:
	for dx in range(-STYLE.BOUNDARY_PENETRATION_DEPTH, STYLE.BOUNDARY_PENETRATION_DEPTH + 1):
		for dy in range(-STYLE.BOUNDARY_PENETRATION_DEPTH, STYLE.BOUNDARY_PENETRATION_DEPTH + 1):
			var inside_cell = boundary_cell + Vector2i(dx, dy)
			var inside_pos = cell_to_world(inside_cell)
			var to_ant = ant_pos - inside_pos
			var distance = to_ant.length()

			if distance < STYLE.CELL_SIZE * STYLE.BOUNDARY_CHECK_RADIUS:
				var repulsion_direction = to_ant.normalized()
				var repulsion_strength = base_heat * (1.0 / (1.0 + distance * 0.1))
				var repulsion_pos = inside_pos + repulsion_direction * STYLE.CELL_SIZE
				var repulsion_cell = world_to_cell(repulsion_pos)

				if is_cell_navigable(repulsion_pos):
					_add_heat_to_cell(entity_id, repulsion_cell, repulsion_strength)

					if _debug_settings[entity_id]:
						_boundary_repulsion_points.append({
							"position": repulsion_pos,
							"strength": repulsion_strength
						})
func get_heat_direction(entity: Node2D, world_pos: Vector2) -> Vector2:
	var entity_id = entity.get_instance_id()
	var center_cell = world_to_cell(world_pos)
	var direction = Vector2.ZERO
	var total_weight = 0.0

	# Boundary repulsion
	if entity is Colony:
		var boundary_result = _calculate_boundary_repulsion(center_cell, world_pos)
		direction += boundary_result.direction * STYLE.BOUNDARY_HEAT_MULTIPLIER
		total_weight += boundary_result.weight * STYLE.BOUNDARY_HEAT_MULTIPLIER

	# Heat avoidance
	var heat_result = _calculate_heat_avoidance(center_cell, world_pos, entity_id)
	direction += heat_result.direction
	total_weight += heat_result.weight

	if total_weight > 0:
		direction /= total_weight

	return direction

func _calculate_boundary_repulsion(center_cell: Vector2i, world_pos: Vector2) -> Dictionary:
	var direction = Vector2.ZERO
	var total_weight = 0.0

	for dx in range(-STYLE.BOUNDARY_CHECK_RADIUS, STYLE.BOUNDARY_CHECK_RADIUS + 1):
		for dy in range(-STYLE.BOUNDARY_CHECK_RADIUS, STYLE.BOUNDARY_CHECK_RADIUS + 1):
			var cell = center_cell + Vector2i(dx, dy)
			var cell_pos = cell_to_world(cell)

			if not is_cell_navigable(cell_pos):
				var away_vector = (world_pos - cell_pos).normalized()
				var distance = world_pos.distance_to(cell_pos)
				var weight = 1.0 / (1 + distance * 0.1)

				direction += away_vector * weight
				total_weight += weight

	if total_weight > 0:
		direction /= total_weight

	return {"direction": direction, "weight": total_weight}

func _calculate_heat_avoidance(center_cell: Vector2i, world_pos: Vector2, exclude_entity_id: int) -> Dictionary:
	var direction = Vector2.ZERO
	var total_weight = 0.0

	var chunk_pos = world_to_chunk(center_cell)
	var neighboring_chunks = _get_neighboring_chunks(chunk_pos)

	for neighbor_pos in neighboring_chunks:
		if not _chunks.has(neighbor_pos):
			continue

		var chunk = _chunks[neighbor_pos]
		for local_pos in chunk.cells:
			var cell = chunk_to_world_cell(neighbor_pos, local_pos)
			var cell_pos = cell_to_world(cell)
			var cell_obj = chunk.cells[local_pos]

			var heat = 0.0
			for source_id in cell_obj.sources:
				if source_id != exclude_entity_id:
					heat += cell_obj.sources[source_id]

			if heat > 0:
				var away_vector = (world_pos - cell_pos).normalized()
				direction += away_vector * heat
				total_weight += heat

	if total_weight > 0:
		direction /= total_weight

	return {"direction": direction, "weight": total_weight}
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

#region Utility Functions
func is_cell_navigable(pos: Vector2) -> bool:
	if _nav_map == RID():
		return true
	return NavigationServer2D.map_get_closest_point(_nav_map, pos).distance_to(pos) < STYLE.CELL_SIZE

func _get_neighboring_chunks(chunk_pos: Vector2i) -> Array:
	var neighbors = [chunk_pos]
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			neighbors.append(chunk_pos + Vector2i(dx, dy))
	return neighbors

func _add_heat_to_cell(entity_id: int, world_cell: Vector2i, amount: float) -> void:
	var chunk_pos = world_to_chunk(world_cell)
	var local_pos = world_to_local_cell(world_cell)

	if not _chunks.has(chunk_pos):
		_chunks[chunk_pos] = HeatChunk.new()

	var cell = _chunks[chunk_pos].get_or_create_cell(local_pos)
	cell.add_heat(entity_id, amount)

func get_heat_at_position(entity: Node2D, pos: Vector2) -> float:
	var colony_id = entity.colony.get_instance_id() if entity is Ant else entity.get_instance_id()
	var world_cell = world_to_cell(pos)
	var chunk_pos = world_to_chunk(world_cell)
	var local_pos = world_to_local_cell(world_cell)

	if not _chunks.has(chunk_pos):
		return 0.0

	var chunk = _chunks[chunk_pos]
	if not chunk.cells.has(local_pos):
		return 0.0

	var cell = chunk.cells[local_pos]
	var total_heat = 0.0

	for source_id in cell.sources:
		var source = instance_from_id(source_id)
		if source:
			var source_colony_id = source.colony.get_instance_id() if source is Ant else source.get_instance_id()
			if source_colony_id == colony_id:
				total_heat += cell.sources[source_id]

	return total_heat
