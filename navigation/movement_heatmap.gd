class_name MovementHeatmap
extends Node2D

const STYLE = {
	"CELL_SIZE": 20,  # Size of each heatmap cell
	"MAX_HEAT": 100.0,  # Maximum heat value for a cell
	"DECAY_RATE": 0.1,  # How much heat decays per second
	"HEAT_RADIUS": 2,  # How many cells around the ant get heated
	"HEAT_PER_SECOND": 20.0,  # How much heat is added per second
	"BOUNDARY_HEAT_MULTIPLIER": 3.0,  # How much extra heat to add near boundaries
	"DEBUG_COLORS": {
		"LOW": Color(0, 0, 1, 0.1),
		"MED": Color(0, 1, 0, 0.2),
		"HIGH": Color(1, 0, 0, 0.3),
		"BOUNDARY": Color(1, 0, 1, 0.4)  # Purple for boundary cells

	}
}

var _grid: Dictionary = {}  # Vector2i -> float (heat value)
var _last_position: Vector2
var _debug_draw: bool = false : set = set_debug_draw

func _init() -> void:
	# Make this node process even when game is paused (for debug visualization)
	process_mode = Node.PROCESS_MODE_ALWAYS
	top_level = true

	
func _ready() -> void:
	# Set up initial position
	_last_position = get_parent().global_position
	
func set_debug_draw(value: bool) -> void:
	_debug_draw = value
	queue_redraw()

func _process(delta: float) -> void:
	var ant = get_parent() as Ant
	if not ant:
		return
		
	# Always work with world positions
	var current_world_pos = ant.global_position
	_update_heat(current_world_pos, delta)
	_last_position = current_world_pos
	
	_decay_heat(delta)
	
	if _debug_draw:
		queue_redraw()

func _update_heat(world_pos: Vector2, delta: float) -> void:
	var center_cell = world_to_cell(world_pos)
	var base_heat = STYLE.HEAT_PER_SECOND * delta
	
	var valid_cells := []
	
	# First identify valid cells
	for dx in range(-STYLE.HEAT_RADIUS, STYLE.HEAT_RADIUS + 1):
		for dy in range(-STYLE.HEAT_RADIUS, STYLE.HEAT_RADIUS + 1):
			var cell = center_cell + Vector2i(dx, dy)
			var cell_world_pos = cell_to_world(cell)
			var distance = center_cell.distance_to(cell)
			
			if distance > STYLE.HEAT_RADIUS:
				continue
			
			if is_cell_navigable(cell_world_pos):
				valid_cells.append({"cell": cell, "distance": distance})
	
	# Apply normal heat to valid cells
	for valid in valid_cells:
		var cell_heat = base_heat / (1 + valid.distance * valid.distance)
		_add_heat_to_cell(valid.cell, cell_heat)
	
	# Get and apply boundary pushback heat
	var boundary_pushback = get_boundary_pushback_cells(center_cell)
	for push in boundary_pushback:
		var cell_heat = base_heat * STYLE.BOUNDARY_HEAT_MULTIPLIER * push.strength / (1 + push.distance * push.distance)
		_add_heat_to_cell(push.cell, cell_heat)
		
## Returns all pushback cells on the other side of boundaries within radius
func get_boundary_pushback_cells(center_cell: Vector2i) -> Array:
	var pushback_cells := []
	var center_pos = cell_to_world(center_cell)
	
	# Check in full radius
	for dx in range(-STYLE.HEAT_RADIUS, STYLE.HEAT_RADIUS + 1):
		for dy in range(-STYLE.HEAT_RADIUS, STYLE.HEAT_RADIUS + 1):
			var check_cell = center_cell + Vector2i(dx, dy)
			var check_pos = cell_to_world(check_cell)
			var distance = center_cell.distance_to(check_cell)
			
			# Skip if too far
			if distance > STYLE.HEAT_RADIUS:
				continue
				
			# If we hit a boundary
			if not is_cell_navigable(check_pos):
				# Calculate direction away from boundary
				var away_dir = (center_pos - check_pos).normalized()
				
				# Create multiple pushback cells in that direction
				for i in range(1, STYLE.HEAT_RADIUS + 1):
					var push_pos = check_pos + away_dir * STYLE.CELL_SIZE * i
					var push_cell = world_to_cell(push_pos)
					
					# Only add if we haven't already found this cell
					if not pushback_cells.any(func(data): return data.cell == push_cell):
						pushback_cells.append({
							"cell": push_cell,
							"distance": distance,
							"strength": 1.0 / i  # Diminish effect with distance
						})
	
	return pushback_cells

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
	
	# Clean up empty cells
	for cell in cells_to_remove:
		_grid.erase(cell)

func is_cell_navigable(pos: Vector2) -> bool:
	# Get the ant's navigation map
	var ant = get_parent() as Ant
	if not ant or not ant.nav_agent:
		return true
		
	var map_rid = ant.nav_agent.get_navigation_map()
	return NavigationServer2D.map_get_closest_point(map_rid, pos).distance_to(pos) < STYLE.CELL_SIZE

func is_near_boundary(cell: Vector2i) -> bool:
	var cell_pos = cell_to_world(cell)
	var has_blocked_neighbor = false
	
	# Check immediate neighbors
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
				
			var neighbor_pos = cell_pos + Vector2(dx, dy) * STYLE.CELL_SIZE
			if not is_cell_navigable(neighbor_pos):
				has_blocked_neighbor = true
				break
				
	return has_blocked_neighbor

func get_heat_at_position(pos: Vector2) -> float:
	var cell = world_to_cell(pos)
	return _grid.get(cell, 0.0)

func get_avoidance_direction(world_pos: Vector2) -> Vector2:
	var center_cell = world_to_cell(world_pos)
	var direction = Vector2.ZERO
	var total_weight = 0.0
	
	for dx in range(-STYLE.HEAT_RADIUS, STYLE.HEAT_RADIUS + 1):
		for dy in range(-STYLE.HEAT_RADIUS, STYLE.HEAT_RADIUS + 1):
			var cell = center_cell + Vector2i(dx, dy)
			var heat = _grid.get(cell, 0.0)
			if heat > 0:
				# Calculate avoidance in world space
				var cell_world_pos = cell_to_world(cell)
				var away_vector = (world_pos - cell_world_pos).normalized()
				direction += away_vector * heat
				total_weight += heat
	
	if total_weight > 0:
		direction /= total_weight
		
	return direction

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(world_pos / STYLE.CELL_SIZE)

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell * STYLE.CELL_SIZE)

func _draw() -> void:
	if not _debug_draw:
		return
		
	for cell in _grid:
		var heat = _grid[cell]
		if heat <= 0:
			continue
			
		# Draw directly in world space
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
			if t < 0.33:
				color = STYLE.DEBUG_COLORS.LOW
			elif t < 0.66:
				color = STYLE.DEBUG_COLORS.MED
			else:
				color = STYLE.DEBUG_COLORS.HIGH
			
		draw_rect(rect, color)
