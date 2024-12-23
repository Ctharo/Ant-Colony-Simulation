class_name MapGenerator
extends Node2D

#region Properties
## Logger instance for debugging
var logger: Logger

## Navigation properties
var nav_map: RID
var nav_region: RID
var obstacles: Array[RID] = []

## Constants for navigation mesh generation
const NAVIGATION_OBSTACLES_DENSITY = 1
const OBSTACLE_SIZE_MIN = 20.0
const OBSTACLE_SIZE_MAX = 70.0
const MAP_SIZE_COEF = 4.0

## Drawing colors
const BACKGROUND_COLOR = Color(Color.DARK_KHAKI, 0.2)
const OBSTACLE_FILL_COLOR = Color(0.5, 0.5, 0.5, 0.7)
const OBSTACLE_BORDER_COLOR = Color(0.3, 0.3, 0.3, 0.8)
const PERIPHERY_COLOR = Color(0.2, 0.2, 0.2, 0.9)
const BORDER_WIDTH = 2.0
#endregion

func _init() -> void:
	logger = Logger.new("map_generator", DebugLogger.Category.PROGRAM)
	
func _ready() -> void:
	nav_map = get_world_2d().navigation_map
	NavigationServer2D.map_set_cell_size(nav_map, 1.0)
	NavigationServer2D.map_set_edge_connection_margin(nav_map, 5.0)

func _exit_tree() -> void:
	# Cleanup navigation resources
	for obstacle in obstacles:
		NavigationServer2D.free_rid(obstacle)
	if nav_region.is_valid():
		NavigationServer2D.free_rid(nav_region)
	if nav_map.is_valid():
		NavigationServer2D.free_rid(nav_map)

## Creates a navigation setup for the given viewport
func generate_navigation(viewport_rect: Rect2, margin_config: Dictionary = {}) -> void:
	var viewport_size = viewport_rect.size
	var map_size: Vector2 = viewport_size * MAP_SIZE_COEF
	
	# Calculate margins and boundaries
	var boundaries = _calculate_boundaries(map_size)
	
	# Create and configure navigation region
	nav_region = NavigationServer2D.region_create()
	NavigationServer2D.region_set_transform(nav_region, Transform2D.IDENTITY)
	
	# Create navigation polygon for main boundary
	var nav_poly = NavigationPolygon.new()
	var main_vertices = [
		Vector2(boundaries.left, boundaries.top),
		Vector2(boundaries.left, boundaries.bottom),
		Vector2(boundaries.right, boundaries.bottom),
		Vector2(boundaries.right, boundaries.top)
	]
	
	nav_poly.add_outline(PackedVector2Array(main_vertices))
	NavigationServer2D.region_set_navigation_polygon(nav_region, nav_poly)
	NavigationServer2D.region_set_map(nav_region, nav_map)
	NavigationServer2D.map_set_active(nav_map, true)
	# Generate obstacles
	_generate_obstacles(boundaries)
	logger.info("Generated %d obstacles" % obstacles.size())
	await get_tree().physics_frame
	if not NavigationServer2D.map_is_active(nav_map):
		logger.error("Problem generating map")
		return
	var obstacle_count: int = NavigationServer2D.map_get_obstacles(nav_map).size()
	logger.info("Navigation map setup complete with %d obstacles registered" % obstacle_count)

## Generate navigation obstacles
func _generate_obstacles(boundaries: Dictionary) -> void:
	var obstacles_num = floori(NAVIGATION_OBSTACLES_DENSITY * get_viewport_rect().size.length())
	var obstacles_placed = 0
	var max_attempts = 50
	
	while obstacles_placed < obstacles_num and max_attempts > 0:
		max_attempts -= 1
		
		var center_x = randf_range(boundaries.safe_left, boundaries.safe_right)
		var center_y = randf_range(boundaries.safe_top, boundaries.safe_bottom)
		var center = Vector2(center_x, center_y)
		
		# Skip if too close to center
		if center.distance_to(Vector2.ZERO) < 150:
			continue
			
		var obstacle_size = randf_range(OBSTACLE_SIZE_MIN, OBSTACLE_SIZE_MAX)
		var obstacle_points = _create_obstacle_points(center, obstacle_size)
		
		# Create and configure obstacle
		var obstacle = NavigationServer2D.obstacle_create()
		NavigationServer2D.obstacle_set_vertices(obstacle, obstacle_points)
		NavigationServer2D.obstacle_set_map(obstacle, nav_map)
		NavigationServer2D.obstacle_set_avoidance_layers(obstacle, 1)
		
		obstacles.push_back(obstacle)
		obstacles_placed += 1
		
		if logger.is_trace_enabled():
			logger.trace("Added obstacle %d with points: %s" % [obstacles_placed, obstacle_points])

## Calculates the safe boundaries for navigation
func _calculate_boundaries(p_viewport_size: Vector2) -> Dictionary:
	var side_margin := p_viewport_size.x * 0.1
	var top_margin := p_viewport_size.y * 0.15
	var bottom_margin := p_viewport_size.y * 0.1
	
	return {
		"left": -p_viewport_size.x/2 + side_margin,
		"right": p_viewport_size.x/2 - side_margin,
		"top": -p_viewport_size.y/2 + top_margin,
		"bottom": p_viewport_size.y/2 - bottom_margin,
		"safe_left": -p_viewport_size.x/2 + side_margin + OBSTACLE_SIZE_MAX,
		"safe_right": p_viewport_size.x/2 - side_margin - OBSTACLE_SIZE_MAX,
		"safe_top": -p_viewport_size.y/2 + top_margin + OBSTACLE_SIZE_MAX,
		"safe_bottom": p_viewport_size.y/2 - bottom_margin - OBSTACLE_SIZE_MAX
	}

## Creates points for an obstacle polygon
func _create_obstacle_points(center: Vector2, p_size: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var num_points := randi_range(6, 8)
	var angle_step := 2 * PI / num_points
	
	for i in range(num_points):
		var angle = i * angle_step
		var radius = p_size * (0.7 + randf() * 0.6)
		var point = center + Vector2(
			cos(angle) * radius * (0.8 + randf() * 0.4),
			sin(angle) * radius * (0.8 + randf() * 0.4)
		)
		points.push_back(point)
	
	return points

func _draw() -> void:
	if not nav_map.is_valid():
		return
		
	# Draw main navigable area
	var regions = NavigationServer2D.map_get_regions(nav_map)
	#if regions.size() > 0:
		#var nav_poly = NavigationServer2D.region_get_navigation_polygon(regions[0])
		#if nav_poly:
			#var outline = nav_poly.get_outline(0)
			#if outline.size() >= 3:
				#draw_colored_polygon(outline, BACKGROUND_COLOR)
	#
	# Draw obstacles
	for obstacle in obstacles:
		var vertices = NavigationServer2D.obstacle_get_vertices(obstacle)
		if vertices.size() >= 3:
			draw_colored_polygon(vertices, OBSTACLE_FILL_COLOR)
			
			# Draw obstacle borders
			for i in range(vertices.size()):
				var start = vertices[i]
				var end = vertices[(i + 1) % vertices.size()]
				draw_line(start, end, OBSTACLE_BORDER_COLOR, BORDER_WIDTH)
