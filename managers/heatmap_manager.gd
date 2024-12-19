extends Node2D

#region Constants
const STYLE = {
	"CELL_SIZE": 20,
	"MAX_HEAT": 100.0,
	"DECAY_RATE": 0.1,
	"HEAT_RADIUS": 2,
	"HEAT_PER_SECOND": 20.0,
	"BOUNDARY_HEAT_MULTIPLIER": 8.0,
	"BOUNDARY_CHECK_RADIUS": 3,
	"BOUNDARY_PENETRATION_DEPTH": 3,
	"DEBUG_COLORS": {
		"START": Color(0, 1, 0, 0.3),
		"END": Color(1, 0, 0, 0.3),
		"BOUNDARY": Color(1, 0, 1, 0.4),
		"REPULSION": Color(1, 0, 0, 0.6)
	}
}
#endregion
## Shared navigation map RID for all colonies
var _nav_map: RID
## Dictionary mapping colony IDs to their heat grids
var _colony_grids: Dictionary = {} # int -> Dictionary[Vector2i, float]
## Dictionary for debug visualization settings
var _debug_settings: Dictionary = {} # int -> bool
## Array of boundary repulsion points for debug visualization
var _boundary_repulsion_points: Array[Dictionary] = []

func _ready() -> void:
	# Wait one frame to ensure navigation is ready
	await get_tree().process_frame
	# Get the navigation map from the NavigationRegion2D in the scene
	var nav_region = get_tree().get_first_node_in_group("navigation")
	if nav_region:
		_nav_map = nav_region.navigation_map
	else:
		push_warning("HeatmapManager: No NavigationRegion2D found in group 'navigation'")
		
#region Colony Management
func register_colony(colony: Colony) -> void:
	var colony_id = colony.get_instance_id()
	if not _colony_grids.has(colony_id):
		_colony_grids[colony_id] = {}
		_debug_settings[colony_id] = false

func unregister_colony(colony: Colony) -> void:
	var colony_id = colony.get_instance_id()
	_colony_grids.erase(colony_id)
	_debug_settings.erase(colony_id)
#endregion

## Toggle debug visualization for a specific colony
func set_debug_draw(colony: Colony, enabled: bool) -> void:
	var colony_id = colony.get_instance_id()
	if _colony_grids.has(colony_id):
		_debug_settings[colony_id] = enabled
		queue_redraw()

func _process(delta: float) -> void:
	_boundary_repulsion_points.clear()
	
	# Process each colony's ants
	for colony_id in _colony_grids.keys():
		var colony = instance_from_id(colony_id) as Colony
		if not colony:
			# Clean up if colony no longer exists
			_colony_grids.erase(colony_id)
			_debug_settings.erase(colony_id)
			continue
		
		# Update heat for all ants in the colony
		for ant in colony.get_ants():
			var current_pos = ant.global_position
			_update_boundary_repulsion(colony_id, current_pos, delta)
			_update_movement_heat(colony_id, current_pos, delta)
		
		_decay_heat(colony_id, delta)
	
	if _debug_settings.values().has(true):
		queue_redraw()

#region Heat Updates
func _update_boundary_repulsion(colony_id: int, world_pos: Vector2, delta: float) -> void:
	var center_cell = world_to_cell(world_pos)
	var base_heat = STYLE.HEAT_PER_SECOND * delta * STYLE.BOUNDARY_HEAT_MULTIPLIER
	
	for dx in range(-STYLE.BOUNDARY_CHECK_RADIUS, STYLE.BOUNDARY_CHECK_RADIUS + 1):
		for dy in range(-STYLE.BOUNDARY_CHECK_RADIUS, STYLE.BOUNDARY_CHECK_RADIUS + 1):
			var check_cell = center_cell + Vector2i(dx, dy)
			var check_pos = cell_to_world(check_cell)
			
			if not is_cell_navigable(check_pos):
				_create_repulsion_from_boundary(colony_id, check_cell, world_pos, base_heat)

func _create_repulsion_from_boundary(colony_id: int, boundary_cell: Vector2i, ant_pos: Vector2, base_heat: float) -> void:
	var boundary_pos = cell_to_world(boundary_cell)
   
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
					_add_heat_to_cell(colony_id, repulsion_cell, repulsion_strength)
				   
					if _debug_settings[colony_id]:
						_boundary_repulsion_points.append({
						   "position": repulsion_pos,
						   "strength": repulsion_strength
					   })
					
func _update_movement_heat(colony_id: int, world_pos: Vector2, delta: float) -> void:
	var center_cell = world_to_cell(world_pos)
	var base_heat = STYLE.HEAT_PER_SECOND * delta
   
	for dx in range(-STYLE.HEAT_RADIUS, STYLE.HEAT_RADIUS + 1):
		for dy in range(-STYLE.HEAT_RADIUS, STYLE.HEAT_RADIUS + 1):
			var cell = center_cell + Vector2i(dx, dy)
			var cell_pos = cell_to_world(cell)
			var distance = center_cell.distance_to(cell)
		   
			if distance <= STYLE.HEAT_RADIUS and is_cell_navigable(cell_pos):
				var heat = base_heat / (1 + distance * distance)
				_add_heat_to_cell(colony_id, cell, heat)
#endregion

#region Heat Management
func _add_heat_to_cell(colony_id: int, cell: Vector2i, amount: float) -> void:
	if not _colony_grids[colony_id].has(cell):
		_colony_grids[colony_id][cell] = 0.0
	_colony_grids[colony_id][cell] = minf(_colony_grids[colony_id][cell] + amount, STYLE.MAX_HEAT)

func _decay_heat(colony_id: int, delta: float) -> void:
	var cells_to_remove = []
	var grid = _colony_grids[colony_id]
	
	for cell in grid:
		grid[cell] = maxf(0.0, grid[cell] - STYLE.DECAY_RATE * delta)
		if grid[cell] <= 0.0:
			cells_to_remove.append(cell)
	
	for cell in cells_to_remove:
		grid.erase(cell)
#endregion

#region Public API
## Get avoidance direction for an ant at a given position
func get_avoidance_direction(colony: Colony, world_pos: Vector2) -> Vector2:
	var colony_id = colony.get_instance_id()
	if not _colony_grids.has(colony_id):
		return Vector2.ZERO
		
	var center_cell = world_to_cell(world_pos)
	var direction = Vector2.ZERO
	var total_weight = 0.0
	
	# Boundary repulsion
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
	
	# Heat avoidance
	var heat_direction = Vector2.ZERO
	var heat_weight = 0.0
	
	for dx in range(-STYLE.HEAT_RADIUS, STYLE.HEAT_RADIUS + 1):
		for dy in range(-STYLE.HEAT_RADIUS, STYLE.HEAT_RADIUS + 1):
			var cell = center_cell + Vector2i(dx, dy)
			var heat = _colony_grids[colony_id].get(cell, 0.0)
			
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

## Get current heat value at a position
func get_heat_at_position(colony: Colony, pos: Vector2) -> float:
	var colony_id = colony.get_instance_id()
	if not _colony_grids.has(colony_id):
		return 0.0
	var cell = world_to_cell(pos)
	return _colony_grids[colony_id].get(cell, 0.0)
#endregion

#region Utility Functions
func is_cell_navigable(pos: Vector2) -> bool:
	if _nav_map == RID():
		return true
	return NavigationServer2D.map_get_closest_point(_nav_map, pos).distance_to(pos) < STYLE.CELL_SIZE

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(world_pos / STYLE.CELL_SIZE)

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell * STYLE.CELL_SIZE)
#endregion

func _draw() -> void:
	for colony_id in _colony_grids:
		if not _debug_settings[colony_id]:
			continue
			
		var grid = _colony_grids[colony_id]
		
		# Draw heat grid
		for cell in grid:
			var heat = grid[cell]
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
				color = STYLE.DEBUG_COLORS.START.lerp(STYLE.DEBUG_COLORS.END, t)
				
			draw_rect(rect, color)
		
		# Draw repulsion points for debugging
		for point in _boundary_repulsion_points:
			var size = 5.0 * point.strength / STYLE.MAX_HEAT
			draw_circle(point.position, size, STYLE.DEBUG_COLORS.REPULSION)
