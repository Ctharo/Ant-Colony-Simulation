class_name MapGenerator
extends Node2D

## Logger instance for debugging
var logger: Logger
var settings_manager: SettingsManager = SettingsManager

## Navigation and viewport properties
var map_size: Vector2
var navigation_region: NavigationRegion2D
var _obstacles
#region Constants
## Constants for navigation mesh generation
var NAVIGATION_OBSTACLES_DENSITY: float = settings_manager.get_setting("obstacle_density")
var OBSTACLE_SIZE_MIN: float = settings_manager.get_setting("obstacle_size_min")
var OBSTACLE_SIZE_MAX: float = settings_manager.get_setting("obstacle_size_max")
const MIN_OBSTACLE_SEPARATION: float = 100.0  # Increased for better spacing
const AGENT_RADIUS: float = 12.5  # The largest diameter of the ant collision polygon?
const PADDING: float = 15.0
const CELL_SIZE: float = 1.0     # Default cell size
const MIN_VERTICES: int = 5  # Minimum vertices for irregular polygons
const MAX_VERTICES: int = 15  # Maximum vertices for irregular polygons
const IRREGULARITY: float = 0.4  # Maximum deviation from regular polygon (0-1)
const SPIKINESS: float = 0.3  # Maximum deviation in radius (0-1)
#endregion

#region Drawing colors
const BACKGROUND_COLOR = Color(Color.LIGHT_GREEN, 0.2)
const OBSTACLE_FILL_COLOR = Color(Color.WEB_GRAY, 0.7)
const OBSTACLE_BORDER_COLOR = Color(0.3, 0.3, 0.3, 0.8)
const PERIPHERY_COLOR = Color(0.2, 0.2, 0.2, 0.9)
const BORDER_WIDTH = 2.0
#endregion

func _init() -> void:
	logger = Logger.new("map_generator", DebugLogger.Category.PROGRAM)

## Creates a navigation setup for the given viewport
func generate_navigation(p_map_size: Vector2, _margin_config: Dictionary = {}) -> NavigationRegion2D:
	map_size = p_map_size
	
	
	# Create and configure navigation polygon
	var nav_poly = NavigationPolygon.new()
	nav_poly.agent_radius = AGENT_RADIUS
	nav_poly.cell_size = CELL_SIZE
	nav_poly.baking_rect = Rect2(Vector2.ZERO, map_size)
	
	# Define the navigation boundary points with slight inset
	var inset = nav_poly.cell_size  # Use cell_size as inset
	var boundary_vertices = PackedVector2Array([
		Vector2(inset, inset),
		Vector2(inset, map_size.y - inset),
		Vector2(map_size.x - inset, map_size.y - inset),
		Vector2(map_size.x - inset, inset)
	])
	
	# Set up the main navigation area
	nav_poly.add_outline(boundary_vertices)

	if logger.is_debug_enabled():
		logger.debug("Created main navigation boundary with vertices: %s" % [boundary_vertices])
	
	# Generate and add obstacles
	var safe_area = _calculate_safe_area()
	var obstacles = _generate_obstacles(safe_area)
	
	# Add valid obstacles to navigation polygon
	var obstacle_data: NavigationMeshSourceGeometryData2D = NavigationMeshSourceGeometryData2D.new()
	for obstacle_points in obstacles:
		if _validate_polygon_points(obstacle_points):
			if is_outline_counterclockwise(obstacle_points):
				obstacle_points.reverse()
			obstacle_data.add_obstruction_outline(obstacle_points)
			if logger.is_trace_enabled():
				logger.trace("Added valid obstacle with points: %s" % [obstacle_points])
	
	_obstacles = obstacle_data.get_obstruction_outlines()
	var count: int = _obstacles.size()
	if logger.is_debug_enabled():
		logger.debug("Added %d valid obstacles to navigation mesh" % [count])
	
	NavigationServer2D.bake_from_source_geometry_data(nav_poly, obstacle_data)
	
	# Create and configure navigation region
	navigation_region = NavigationRegion2D.new()
	navigation_region.navigation_polygon = nav_poly
	add_child(navigation_region)
	
	queue_redraw()
	
	# Wait for physics processing
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	return navigation_region

## Creates points for an irregular polygon
func _create_obstacle_points(center: Vector2, size: float) -> PackedVector2Array:
	# Randomly determine number of vertices
	var num_vertices = randi_range(MIN_VERTICES, MAX_VERTICES)
	var points = PackedVector2Array()
	
	# Generate base angles for a regular polygon
	var base_angle = TAU / num_vertices
	var angle_offset = randf_range(0, base_angle)  # Random rotation
	
	for i in range(num_vertices):
		# Calculate base angle for this vertex
		var angle = i * base_angle + angle_offset
		
		# Add irregularity to angle (deviation from regular spacing)
		var angle_irregularity = randf_range(-IRREGULARITY, IRREGULARITY) * base_angle
		angle += angle_irregularity
		
		# Add spikiness (deviation from regular radius)
		var radius = size * (1.0 + randf_range(-SPIKINESS, SPIKINESS))
		
		# Calculate point position
		var point = Vector2(
			center.x + cos(angle) * radius,
			center.y + sin(angle) * radius
		)
		points.push_back(point)
	
	if logger.is_trace_enabled():
		logger.trace("Generated irregular polygon with %d vertices at %s" % [
			num_vertices,
			center
		])
	
	return points

## Validates polygon points
func _validate_polygon_points(points: PackedVector2Array) -> bool:
	if points.size() < MIN_VERTICES:
		logger.trace("Invalid number of points: %d (minimum %d)" % [
			points.size(),
			MIN_VERTICES
		])
		return false
	
	# Check if all points are within the map bounds with padding
	var padding = PADDING
	for point in points:
		if point.x < padding or point.x > map_size.x - padding or \
		   point.y < padding or point.y > map_size.y - padding:
			logger.trace("Point outside safe bounds: %s" % [point])
			return false
	
	# Check if polygon is convex (required for navigation mesh)
	if not _is_polygon_convex(points):
		logger.trace("Generated polygon is not convex")
		return false
	
	return true

## Checks if a polygon is convex using cross product
func _is_polygon_convex(points: PackedVector2Array) -> bool:
	var n = points.size()
	if n < 3:
		return false
	
	var _sign = 0
	
	for i in range(n):
		var current = points[i]
		var next = points[(i + 1) % n]
		var next_next = points[(i + 2) % n]
		
		var cross_product = (next.x - current.x) * (next_next.y - current.y) - \
						   (next.y - current.y) * (next_next.x - current.x)
		
		if _sign == 0:
			_sign = signf(cross_product)
		elif _sign * cross_product < 0:
			return false
	
	return true

func _calculate_safe_area() -> Dictionary:
	var padding = max(OBSTACLE_SIZE_MAX, MIN_OBSTACLE_SEPARATION) * 2
	logger.debug("Calculating safe area with padding: %f" % [padding])
	
	var safe_area = {
		"left": padding,
		"right": map_size.x - padding,
		"top": padding,
		"bottom": map_size.y - padding
	}
	
	var usable_width = safe_area.right - safe_area.left
	var usable_height = safe_area.bottom - safe_area.top
	logger.debug("Usable area: %f x %f" % [usable_width, usable_height])
	
	return safe_area

## Generates obstacle points arrays
func _generate_obstacles(safe_area: Dictionary) -> Array[PackedVector2Array]:
	# Calculate number of obstacles based on area rather than length
	var area = map_size.x * map_size.y
	var obstacles_num = floori(NAVIGATION_OBSTACLES_DENSITY * area) * 0.00001  # Adjusted for large maps
	
	logger.debug("Attempting to generate %d obstacles for map size %s" % [obstacles_num, map_size])
	logger.debug("Safe area: %s" % [safe_area])
	
	var existing_obstacles: Array[PackedVector2Array] = []
	var attempts_per_obstacle = 15  # Increased attempts
	var max_attempts = obstacles_num * attempts_per_obstacle
	var current_attempts = 0
	
	var validation_failures = 0
	var overlap_failures = 0
	var origin_failures = 0
	
	while existing_obstacles.size() < obstacles_num and current_attempts < max_attempts:
		current_attempts += 1
		
		var center = Vector2(
			randf_range(safe_area.left, safe_area.right),
			randf_range(safe_area.top, safe_area.bottom)
		)
		
		# Skip if too close to origin
		if center.distance_to(Vector2.ZERO) < AGENT_RADIUS * 20:
			origin_failures += 1
			if current_attempts % 100 == 0:
				logger.trace("Origin proximity failures: %d" % [origin_failures])
			continue
			
		var obstacle_size = randf_range(OBSTACLE_SIZE_MIN, OBSTACLE_SIZE_MAX)
		var obstacle_points = _create_obstacle_points(center, obstacle_size)
		
		if not _validate_polygon_points(obstacle_points):
			validation_failures += 1
			if current_attempts % 100 == 0:
				logger.trace("Validation failures: %d" % [validation_failures])
			continue
			
		if _check_obstacle_overlap(obstacle_points, existing_obstacles):
			overlap_failures += 1
			if current_attempts % 100 == 0:
				logger.trace("Overlap failures: %d" % [overlap_failures])
			continue
			
		existing_obstacles.append(obstacle_points)
		
		if logger.is_trace_enabled():
			logger.trace("Generated valid obstacle %d/%d at %s" % [
				existing_obstacles.size(),
				obstacles_num,
				center
			])
	
	logger.debug("Obstacle generation summary:")
	logger.debug("- Total attempts: %d" % [current_attempts])
	logger.debug("- Validation failures: %d" % [validation_failures])
	logger.debug("- Overlap failures: %d" % [overlap_failures])
	logger.debug("- Origin proximity failures: %d" % [origin_failures])
	logger.debug("- Successful obstacles: %d" % [existing_obstacles.size()])
	
	return existing_obstacles

## Check obstacle overlap
func _check_obstacle_overlap(new_obstacle: PackedVector2Array, existing_obstacles: Array[PackedVector2Array]) -> bool:
	var min_distance = AGENT_RADIUS * 3  # Minimum separation based on agent radius
	
	for existing in existing_obstacles:
		for new_point in new_obstacle:
			for existing_point in existing:
				if new_point.distance_to(existing_point) < min_distance:
					return true
	return false

## Checks outline winding order
func is_outline_counterclockwise(outline: PackedVector2Array) -> bool:
	var sum = 0.0
	for i in range(outline.size()):
		var current = outline[i]
		var next = outline[(i + 1) % outline.size()]
		sum += (next.x - current.x) * (next.y + current.y)
	return sum > 0

func _draw() -> void:
	if not navigation_region or not navigation_region.navigation_polygon:
		return
	
	_draw_navigation_mesh()

## Draws navigation mesh
func _draw_navigation_mesh() -> void:
	var nav_poly = navigation_region.navigation_polygon
	var outline_count = nav_poly.get_outline_count()
	
	if outline_count == 0:
		logger.error("No outlines found in navigation polygon")
		return
	
	# Draw main area
	var main_outline = nav_poly.get_outline(0)
	if main_outline.size() >= 3:
		draw_colored_polygon(main_outline, BACKGROUND_COLOR)
	
	# Draw obstacles
	for i in range(1, _obstacles.size()):
		var obstacle_vertices = _obstacles[i]
		draw_colored_polygon(obstacle_vertices, OBSTACLE_FILL_COLOR)
		
		# Draw borders
		for j in range(obstacle_vertices.size()):
			var start = obstacle_vertices[j]
			var end = obstacle_vertices[(j + 1) % obstacle_vertices.size()]
			draw_line(start, end, OBSTACLE_BORDER_COLOR, BORDER_WIDTH)
