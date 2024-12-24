class_name MapGenerator
extends Node2D

## Logger instance for debugging
var logger: Logger

## Navigation and viewport properties
var viewport_size: Vector2
var navigation_region: NavigationRegion2D
## Constants for navigation mesh generation
const NAVIGATION_OBSTACLES_DENSITY = 0.03
const OBSTACLE_SIZE_MIN = 20.0
const OBSTACLE_SIZE_MAX = 70.0

## Drawing colors
const BACKGROUND_COLOR = Color(Color.LIGHT_GREEN, 0.2)
const OBSTACLE_FILL_COLOR = Color(Color.WEB_GRAY, 0.7)
const OBSTACLE_BORDER_COLOR = Color(0.3, 0.3, 0.3, 0.8)
const PERIPHERY_COLOR = Color(0.2, 0.2, 0.2, 0.9)
const BORDER_WIDTH = 2.0

func _init() -> void:
	logger = Logger.new("map_generator", DebugLogger.Category.PROGRAM)

## Creates a navigation setup for the given viewport
func generate_navigation(viewport_size: Vector2, _margin_config: Dictionary = {}) -> NavigationRegion2D:
	# Create navigation polygon
	var nav_poly = NavigationPolygon.new()
	var vertex_array = PackedVector2Array()
	var vertices_map = {}  # To map Vector2 positions to vertex indices
	var vertex_index = 0

	# Get viewport size
	var map_size: Vector2 = viewport_size

	# Define margins
	var side_margin := viewport_size.x * 0.1  # 10% of viewport width
	var top_margin := viewport_size.y * 0.15   # 15% of viewport height
	var bottom_margin := viewport_size.y * 0.1  # 10% of viewport height

	# Define the navigation boundary points
	var nav_left := -map_size.x/2 
	var nav_right := map_size.x/2
	var nav_top := -map_size.y/2 
	var nav_bottom := map_size.y/2

	# Add main boundary vertices
	var main_vertices = [
		Vector2(nav_left, nav_top),      # 0
		Vector2(nav_left, nav_bottom),   # 1
		Vector2(nav_right, nav_bottom),  # 2
		Vector2(nav_right, nav_top)      # 3
	]

	# Add main vertices and store their indices
	for vertex in main_vertices:
		vertex_array.push_back(vertex)
		vertices_map[vertex] = vertex_index
		vertex_index += 1

	# Create navigation polygon for main boundary
	nav_poly.clear()
	nav_poly.add_outline(PackedVector2Array(main_vertices))
	nav_poly.set_vertices(vertex_array)
	nav_poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))

	logger.info("Main outline points: %s" % [main_vertices])

	# Calculate safe area for obstacle placement
	var safe_left := nav_left + OBSTACLE_SIZE_MAX
	var safe_right := nav_right - OBSTACLE_SIZE_MAX
	var safe_top := nav_top + OBSTACLE_SIZE_MAX
	var safe_bottom := nav_bottom - OBSTACLE_SIZE_MAX

	# Calculate number of obstacles based on viewport size
	var obstacles_num = floori(NAVIGATION_OBSTACLES_DENSITY * map_size.length())
	var obstacles_placed = 0
	var max_attempts = obstacles_num * 2
	var existing_obstacles: Array[PackedVector2Array] = []

	while obstacles_placed < obstacles_num and max_attempts > 0:
		max_attempts -= 1
		var center_x = randf_range(safe_left, safe_right)
		var center_y = randf_range(safe_top, safe_bottom)
		var center = Vector2(center_x, center_y)
		
		if center.distance_to(Vector2.ZERO) < 150:
			continue
			
		var obstacle_size = randf_range(OBSTACLE_SIZE_MIN, OBSTACLE_SIZE_MAX)
		var obstacle_points = _create_obstacle_points(center, obstacle_size)
		
		# Check for overlaps with minimum distance of OBSTACLE_SIZE_MIN
		if _check_obstacle_overlap(obstacle_points, existing_obstacles, OBSTACLE_SIZE_MIN):
			continue
			
		# Add vertices and update navigation polygon
		var start_idx = vertex_array.size()
		for vertex in obstacle_points:
			vertex_array.push_back(vertex)
			
		if is_outline_counterclockwise(obstacle_points):
			obstacle_points.reverse()
			
		nav_poly.add_outline(obstacle_points)
		nav_poly.set_vertices(vertex_array)
		
		var obstacle_indices = PackedInt32Array()
		for i in range(obstacle_points.size()):
			obstacle_indices.push_back(start_idx + i)
		
		nav_poly.add_polygon(obstacle_indices)
		existing_obstacles.append(obstacle_points)
		obstacles_placed += 1
		
	logger.info("Added %d obstacles - Final vertices: %d, Polygons: %d" % [
		obstacles_placed,
		nav_poly.get_vertices().size(),
		nav_poly.get_polygon_count()
	])
	# Create navigation region
	navigation_region = NavigationRegion2D.new()
	# Set the navigation polygon
	navigation_region.navigation_polygon = nav_poly
	add_child(navigation_region)
	navigation_region.bake_navigation_polygon()
	queue_redraw()
	await get_tree().physics_frame
	return navigation_region

func is_outline_counterclockwise(outline: PackedVector2Array) -> bool:
	var sum = 0.0
	for i in range(outline.size()):
		var current = outline[i]
		var next = outline[(i + 1) % outline.size()]
		sum += (next.x - current.x) * (next.y + current.y)
	return sum > 0

func _check_obstacle_overlap(obstacle_points: PackedVector2Array, existing_obstacles: Array[PackedVector2Array], min_distance: float) -> bool:
	# Check if new obstacle overlaps with existing ones
	for existing in existing_obstacles:
		for point in obstacle_points:
			for i in range(existing.size()):
				var segment_start := existing[i]
				var segment_end := existing[(i + 1) % existing.size()]
				
				# Check distance to line segment
				var closest := _get_closest_point_on_segment(point, segment_start, segment_end)
				if point.distance_to(closest) < min_distance:
					return true
	
	return false

func _get_closest_point_on_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> Vector2:
	var segment := segment_end - segment_start
	if segment.length_squared() == 0:
		return segment_start
		
	var t: float = max(0, min(1, (point - segment_start).dot(segment) / segment.length_squared()))
	return segment_start + segment * t

## Calculates the safe boundaries for navigation
func _calculate_boundaries(
	p_viewport_size: Vector2,
	side_margin: float,
	top_margin: float,
	bottom_margin: float
) -> Dictionary:
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
func _create_obstacle_points(center: Vector2, size: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var num_points := randi_range(6, 8)
	var angle_step := 2 * PI / num_points

	for i in range(num_points):
		var angle = i * angle_step
		var radius = size * (0.7 + randf() * 0.6)
		var point = center + Vector2(
			cos(angle) * radius * (0.8 + randf() * 0.4),
			sin(angle) * radius * (0.8 + randf() * 0.4)
		)
		points.push_back(point)

	return points

func _draw() -> void:
	_draw_navigation_mesh()

## Draws the navigation mesh with obstacles and periphery
func _draw_navigation_mesh() -> void:
	var nav_poly = navigation_region.navigation_polygon
	var outline_count := nav_poly.get_outline_count()
	
	
	if outline_count == 0:
		logger.error("No outlines found in navigation polygon")
		return
		
	var main_outline := nav_poly.get_outline(0)
	if main_outline.size() >= 3:
		draw_colored_polygon(main_outline, BACKGROUND_COLOR)
	else:
		logger.error("Main outline has insufficient points: %d" % main_outline.size())
	
	# Draw inner obstacles
	for i in range(1, outline_count):
		var obstacle := nav_poly.get_outline(i)
		if obstacle.size() >= 3:
			draw_colored_polygon(obstacle, OBSTACLE_FILL_COLOR)
			
			# Draw obstacle borders
			for j in range(obstacle.size()):
				var start := obstacle[j]
				var end := obstacle[(j + 1) % obstacle.size()]
				draw_line(start, end, OBSTACLE_BORDER_COLOR, BORDER_WIDTH)
		else:
			logger.error("Obstacle %d has insufficient points: %d" % [i, obstacle.size()])
