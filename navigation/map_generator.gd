class_name MapGenerator
extends Node2D

## Logger instance for debugging
var logger: Logger

## Navigation and viewport properties
var viewport_size: Vector2
var nav_poly: NavigationPolygon
var navigation_region: NavigationRegion2D

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

func _init() -> void:
	logger = Logger.new("map_generator", DebugLogger.Category.PROGRAM)

## Creates a navigation setup for the given viewport
func generate_navigation(viewport_rect: Rect2, margin_config: Dictionary = {}) -> NavigationRegion2D:


	# Create navigation polygon
	nav_poly = NavigationPolygon.new()
	var vertex_array = PackedVector2Array()
	var vertices_map = {}  # To map Vector2 positions to vertex indices
	var vertex_index = 0

	# Get viewport size
	viewport_size = viewport_rect.size
	var map_size: Vector2 = viewport_size * MAP_SIZE_COEF

	# Define margins
	var side_margin := viewport_size.x * 0.1  # 10% of viewport width
	var top_margin := viewport_size.y * 0.15   # 15% of viewport height
	var bottom_margin := viewport_size.y * 0.1  # 10% of viewport height

	# Define the navigation boundary points
	var nav_left := -map_size.x/2 + side_margin
	var nav_right := map_size.x/2 - side_margin
	var nav_top := -map_size.y/2 + top_margin
	var nav_bottom := map_size.y/2 - bottom_margin

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
	var obstacles_num = floori(NAVIGATION_OBSTACLES_DENSITY * viewport_rect.size.length())
	var obstacles_placed = 0
	var max_attempts = 50

	while obstacles_placed < obstacles_num and max_attempts > 0:
		max_attempts -= 1

		var center_x = randf_range(safe_left, safe_right)
		var center_y = randf_range(safe_top, safe_bottom)
		var center = Vector2(center_x, center_y)

		# Skip if too close to center
		if center.distance_to(Vector2.ZERO) < 150:
			continue

		var obstacle_size = randf_range(OBSTACLE_SIZE_MIN, OBSTACLE_SIZE_MAX)

		# Create irregular rock-like obstacle vertices
		var obstacle_points = _create_obstacle_points(center, obstacle_size)

		# Add obstacle vertices
		var start_idx = vertex_array.size()
		for vertex in obstacle_points:
			vertex_array.push_back(vertex)

		if is_outline_counterclockwise(obstacle_points):
			obstacle_points.reverse()

		# Add outline first, then polygon for obstacle
		nav_poly.add_outline(obstacle_points)
		nav_poly.set_vertices(vertex_array)

		var obstacle_indices = PackedInt32Array()
		for i in range(obstacle_points.size()):
			obstacle_indices.push_back(start_idx + i)
		nav_poly.add_polygon(obstacle_indices)

		logger.info("Added obstacle outline with points: %s" % [obstacle_points])

		obstacles_placed += 1
	logger.info("Added %d obstacles - Final vertices: %d, Polygons: %d" % [
		obstacles_placed,
		nav_poly.get_vertices().size(),
		nav_poly.get_polygon_count()
	])
	# Create navigation region
	navigation_region = NavigationRegion2D.new()
	navigation_region.add_to_group("navigation")

	# Set the navigation polygon
	navigation_region.navigation_polygon = nav_poly
	NavigationServer2D.region_set_map(navigation_region.get_rid(), get_world_2d().get_navigation_map())
	add_child(navigation_region)
	navigation_region.bake_navigation_polygon()
	await get_tree().physics_frame
	return navigation_region

func is_outline_counterclockwise(outline: PackedVector2Array) -> bool:
	var sum = 0.0
	for i in range(outline.size()):
		var current = outline[i]
		var next = outline[(i + 1) % outline.size()]
		sum += (next.x - current.x) * (next.y + current.y)
	return sum > 0

## Calculates the safe boundaries for navigation
func _calculate_boundaries(
	viewport_size: Vector2,
	side_margin: float,
	top_margin: float,
	bottom_margin: float
) -> Dictionary:
	return {
		"left": -viewport_size.x/2 + side_margin,
		"right": viewport_size.x/2 - side_margin,
		"top": -viewport_size.y/2 + top_margin,
		"bottom": viewport_size.y/2 - bottom_margin,
		"safe_left": -viewport_size.x/2 + side_margin + OBSTACLE_SIZE_MAX,
		"safe_right": viewport_size.x/2 - side_margin - OBSTACLE_SIZE_MAX,
		"safe_top": -viewport_size.y/2 + top_margin + OBSTACLE_SIZE_MAX,
		"safe_bottom": viewport_size.y/2 - bottom_margin - OBSTACLE_SIZE_MAX
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
	var i = 0
	# Draw inner obstacles
	for o in NavigationServer2D.map_get_obstacles(get_world_2d().get_navigation_map()):
		var obstacle = NavigationServer2D.obstacle_get_vertices(o)
		logger.info("Obstacle %d points: %d" % [i, obstacle.size()])
		if obstacle.size() >= 3:
			draw_colored_polygon(obstacle, OBSTACLE_FILL_COLOR)
			logger.info("Drew obstacle %d at points: %s" % [i, obstacle])

			# Draw obstacle borders
			for j in range(obstacle.size()):
				var start: Vector2 = obstacle[j]
				var end: Vector2 = obstacle[(j + 1) % obstacle.size()]
				draw_line(start, end, OBSTACLE_BORDER_COLOR, BORDER_WIDTH)
		else:
			logger.error("Obstacle %d has insufficient points: %d" % [i, obstacle.size()])
		i += 1
