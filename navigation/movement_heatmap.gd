class_name MovementHeatmap
extends Node2D

#region Constants
const STYLE = {
	"CELL_SIZE": 15,  # Size of each heatmap cell
	"MAX_HEAT": 100.0,  # Maximum heat value for a cell
	"DECAY_RATE": 0.2,  # How much heat decays per second
	"HEAT_RADIUS": 2,  # How many cells around the ant get heated
	"HEAT_PER_SECOND": 20.0,  # How much heat is added per second
	"BOUNDARY_HEAT_MULTIPLIER": 8.0,  # Increased for stronger edge repulsion
	"BOUNDARY_CHECK_RADIUS": 3,  # How far to look for boundaries
	"BOUNDARY_PENETRATION_DEPTH": 2,  # How deep into walls to check for repulsion
	"DEBUG_COLORS": {
		"START": Color(Color.GREEN, 0.3),  
		"END": Color(Color.RED, 0.3),    
		"BOUNDARY": Color(Color.BLUE, 0.4),
		"REPULSION": Color(1, 0, 0, 0.6)
	}
}
#endregion

#region Member Variables
var _grid: Dictionary = {}  # Vector2i -> float
var _last_position: Vector2
var _debug_draw: bool = false : set = set_debug_draw
var _boundary_repulsion_points: Array[Dictionary] = []  # Store repulsion points for debug
#endregion

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	top_level = true

func _ready() -> void:
	_last_position = get_parent().global_position

func set_debug_draw(value: bool) -> void:
	_debug_draw = value
	queue_redraw()

func _process(delta: float) -> void:
	var ant = get_parent() as Ant
	if not ant:
		return
		
	var current_world_pos = ant.global_position
	_boundary_repulsion_points.clear()
	
	# Update boundary repulsion first
	_update_boundary_repulsion(current_world_pos, delta)
	
	# Then update regular movement heat
	_update_movement_heat(current_world_pos, delta)
	
	_last_position = current_world_pos
	_decay_heat(delta)
	
	if _debug_draw:
		queue_redraw()

## Creates repulsion forces from boundaries by checking inside obstacles
func _update_boundary_repulsion(world_pos: Vector2, delta: float) -> void:
	var center_cell = world_to_cell(world_pos)
	var base_heat = STYLE.HEAT_PER_SECOND * delta * STYLE.BOUNDARY_HEAT_MULTIPLIER
	
	# Check surrounding area for boundaries
	for dx in range(-STYLE.BOUNDARY_CHECK_RADIUS, STYLE.BOUNDARY_CHECK_RADIUS + 1):
		for dy in range(-STYLE.BOUNDARY_CHECK_RADIUS, STYLE.BOUNDARY_CHECK_RADIUS + 1):
			var check_cell = center_cell + Vector2i(dx, dy)
			var check_pos = cell_to_world(check_cell)
			
			# If we find a boundary, create repulsion from inside it
			if not is_cell_navigable(check_pos):
				_create_repulsion_from_boundary(check_cell, world_pos, base_heat)

## Creates strong repulsion forces from inside boundaries
func _create_repulsion_from_boundary(boundary_cell: Vector2i, ant_pos: Vector2, base_heat: float) -> void:
	var boundary_pos = cell_to_world(boundary_cell)
	
	# Check points inside the boundary
	for dx in range(-STYLE.BOUNDARY_PENETRATION_DEPTH, STYLE.BOUNDARY_PENETRATION_DEPTH + 1):
		for dy in range(-STYLE.BOUNDARY_PENETRATION_DEPTH, STYLE.BOUNDARY_PENETRATION_DEPTH + 1):
			var inside_cell = boundary_cell + Vector2i(dx, dy)
			var inside_pos = cell_to_world(inside_cell)
			
			# Calculate repulsion vector from inside the boundary
			var to_ant = ant_pos - inside_pos
			var distance = to_ant.length()
			
			if distance < STYLE.CELL_SIZE * STYLE.BOUNDARY_CHECK_RADIUS:
				var repulsion_direction = to_ant.normalized()
				var repulsion_strength = base_heat * (1.0 / (1.0 + distance * 0.1))
				
				# Create repulsion heat in the direction away from boundary
				var repulsion_pos = inside_pos + repulsion_direction * STYLE.CELL_SIZE
				var repulsion_cell = world_to_cell(repulsion_pos)
				
				if is_cell_navigable(repulsion_pos):
					_add_heat_to_cell(repulsion_cell, repulsion_strength)
					
					# Store repulsion point for debugging
					if _debug_draw:
						_boundary_repulsion_points.append({
							"position": repulsion_pos,
							"strength": repulsion_strength
						})

## Updates heat based on movement
func _update_movement_heat(world_pos: Vector2, delta: float) -> void:
	var center_cell = world_to_cell(world_pos)
	var base_heat = STYLE.HEAT_PER_SECOND * delta
	
	for dx in range(-STYLE.HEAT_RADIUS, STYLE.HEAT_RADIUS + 1):
		for dy in range(-STYLE.HEAT_RADIUS, STYLE.HEAT_RADIUS + 1):
			var cell = center_cell + Vector2i(dx, dy)
			var cell_pos = cell_to_world(cell)
			var distance = center_cell.distance_to(cell)
			
			if distance <= STYLE.HEAT_RADIUS and is_cell_navigable(cell_pos):
				var heat = base_heat / (1 + distance * distance)
				_add_heat_to_cell(cell, heat)

## Returns a weighted avoidance direction, prioritizing boundary repulsion
func get_avoidance_direction(world_pos: Vector2) -> Vector2:
	var center_cell = world_to_cell(world_pos)
	var direction = Vector2.ZERO
	var total_weight = 0.0
	
	# First, consider boundary repulsion
	var boundary_direction = Vector2.ZERO
	var boundary_weight = 0.0
	
	for dx in range(-STYLE.BOUNDARY_CHECK_RADIUS, STYLE.BOUNDARY_CHECK_RADIUS + 1):
		for dy in range(-STYLE.BOUNDARY_CHECK_RADIUS, STYLE.BOUNDARY_CHECK_RADIUS + 1):
			var cell = center_cell + Vector2i(dx, dy)
			var cell_pos = cell_to_world(cell)
			
			if not is_cell_navigable(cell_pos):
				var away_vector = (world_pos - cell_pos).normalized()
				var distance = world_pos.distance_to(cell_pos)
				var weight = STYLE.BOUNDARY_HEAT_MULTIPLIER / (1 + distance * 0.1)
				
				boundary_direction += away_vector * weight
				boundary_weight += weight
	
	if boundary_weight > 0:
		boundary_direction /= boundary_weight
		direction += boundary_direction * STYLE.BOUNDARY_HEAT_MULTIPLIER
		total_weight += STYLE.BOUNDARY_HEAT_MULTIPLIER
	
	# Then add regular heat avoidance
	var heat_direction = Vector2.ZERO
	var heat_weight = 0.0
	
	for dx in range(-STYLE.HEAT_RADIUS, STYLE.HEAT_RADIUS + 1):
		for dy in range(-STYLE.HEAT_RADIUS, STYLE.HEAT_RADIUS + 1):
			var cell = center_cell + Vector2i(dx, dy)
			var heat = _grid.get(cell, 0.0)
			
			if heat > 0:
				var cell_pos = cell_to_world(cell)
				var away_vector = (world_pos - cell_pos).normalized()
				heat_direction += away_vector * heat
				heat_weight += heat
	
	if heat_weight > 0:
		heat_direction /= heat_weight
		direction += heat_direction
		total_weight += 1.0
	
	if total_weight > 0:
		direction /= total_weight
		
	return direction

func _add_heat_to_cell(cell: Vector2i, amount: float) -> void:
	if not _grid.has(cell):
		_grid[cell] = 0.0
	_grid[cell] = minf(_grid[cell] + amount, STYLE.MAX_HEAT)

func _decay_heat(delta: float) -> void:
	var cells_to_remove = []
	
	for cell in _grid:
		_grid[cell] = maxf(0.0, _grid[cell] - STYLE.DECAY_RATE * delta)
		if _grid[cell] <= 0.0:
			cells_to_remove.append(cell)
	
	for cell in cells_to_remove:
		_grid.erase(cell)

func is_cell_navigable(pos: Vector2) -> bool:
	var ant = get_parent() as Ant
	if not ant or not ant.nav_agent:
		return true
		
	var map_rid = ant.nav_agent.get_navigation_map()
	return NavigationServer2D.map_get_closest_point(map_rid, pos).distance_to(pos) < STYLE.CELL_SIZE

#region Utility Functions
func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(world_pos / STYLE.CELL_SIZE)

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell * STYLE.CELL_SIZE)

func get_heat_at_position(pos: Vector2) -> float:
	var cell = world_to_cell(pos)
	return _grid.get(cell, 0.0)
#endregion

func _draw() -> void:
	if not _debug_draw:
		return
		
	# Draw heat grid
	for cell in _grid:
		var heat = _grid[cell]
		if heat <= 0:
			continue
			
		var rect = Rect2(
			cell_to_world(cell),
			Vector2.ONE * STYLE.CELL_SIZE
		)
		
		var t = heat / STYLE.MAX_HEAT
		var color
		
		if not is_cell_navigable(rect.position):
			color = STYLE.DEBUG_COLORS.BOUNDARY
			color.a *= t
		else:
			# Lerp between green and red based on heat value
			color = STYLE.DEBUG_COLORS.START.lerp(STYLE.DEBUG_COLORS.END, t)
			
		draw_rect(rect, color)
	
	# Draw repulsion points for debugging
	for point in _boundary_repulsion_points:
		var size = 5.0 * point.strength / STYLE.MAX_HEAT
		draw_circle(point.position, size, STYLE.DEBUG_COLORS.REPULSION)
