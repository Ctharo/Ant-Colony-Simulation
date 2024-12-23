class_name MapGenerator

## Logger instance for debugging
var logger: Logger

var viewport_size: Vector2

## Constants for navigation mesh generation
const NAVIGATION_OBSTACLES_DENSITY = 1
const OBSTACLE_SIZE_MIN = 20.0
const OBSTACLE_SIZE_MAX = 70.0
const MAP_SIZE_COEF = 4.0

func _init() -> void:
	logger = Logger.new("map_generator", DebugLogger.Category.PROGRAM)

## Creates a navigation setup for the given viewport
func generate_navigation(viewport_rect: Rect2, margin_config: Dictionary = {}) -> NavigationRegion2D:
	# Create navigation region
	var navigation_region := NavigationRegion2D.new()
	navigation_region.add_to_group("navigation")
	
	# Create navigation polygon
	var navigation_poly := NavigationPolygon.new()
	navigation_poly.agent_radius = 10.0
	navigation_poly.cell_size = 1.0
	
	# Get viewport size
	viewport_size = viewport_rect.size * MAP_SIZE_COEF
	
	# Define margins with defaults
	var side_margin: float = margin_config.get("side", 160.0)
	var top_margin: float = margin_config.get("top", 280.0)
	var bottom_margin: float = margin_config.get("bottom", 160.0)
	
	# Generate the navigation mesh
	_generate_navigation_mesh(
		navigation_poly,
		viewport_size,
		side_margin,
		top_margin,
		bottom_margin
	)
	
	# Set the navigation polygon
	navigation_region.navigation_polygon = navigation_poly
	
	# Configure NavigationServer2D
	var map_rid = navigation_region.get_navigation_map()
	if map_rid.is_valid():
		_configure_navigation_server(map_rid)
	
	return navigation_region

## Generates the navigation mesh with obstacles
func _generate_navigation_mesh(
	navigation_poly: NavigationPolygon,
	viewport_size: Vector2,
	side_margin: float,
	top_margin: float,
	bottom_margin: float
) -> void:
	# Define the navigation boundary points
	var boundaries := _calculate_boundaries(
		viewport_size,
		side_margin,
		top_margin,
		bottom_margin
	)
	
	# Add main boundary with clockwise winding
	var main_outline = PackedVector2Array([
		Vector2(boundaries.left, boundaries.top),
		Vector2(boundaries.right, boundaries.top),
		Vector2(boundaries.right, boundaries.bottom),
		Vector2(boundaries.left, boundaries.bottom)
	])
	navigation_poly.add_outline(main_outline)
	
	# Generate and add obstacles
	var obstacles := _generate_obstacles(boundaries)
	for obstacle in obstacles:
		navigation_poly.add_outline(obstacle)
	
	# Generate polygons
	navigation_poly.make_polygons_from_outlines()
	
	logger.info("Added %d obstacles - Outlines: %d" % [
		obstacles.size(),
		navigation_poly.get_outline_count()
	])

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

## Generates obstacles for the navigation mesh
func _generate_obstacles(boundaries: Dictionary) -> Array[PackedVector2Array]:
	var existing_obstacles: Array[PackedVector2Array] = []
	var viewport_size := Vector2(
		boundaries.right - boundaries.left,
		boundaries.bottom - boundaries.top
	)
	
	var obstacles_num = floori(NAVIGATION_OBSTACLES_DENSITY * viewport_size.length())
	var obstacles_placed = 0
	var max_attempts = 50
	
	while obstacles_placed < obstacles_num and max_attempts > 0:
		max_attempts -= 1
		
		var center := _get_random_obstacle_position(boundaries)
		if center.distance_to(Vector2.ZERO) < 150:
			continue
		
		var obstacle_size = randf_range(OBSTACLE_SIZE_MIN, OBSTACLE_SIZE_MAX)
		var obstacle_points = _create_obstacle_points(center, obstacle_size)
		
		if _is_valid_obstacle_placement(obstacle_points, existing_obstacles):
			if is_outline_counterclockwise(obstacle_points):
				obstacle_points.reverse()
			
			existing_obstacles.append(obstacle_points)
			obstacles_placed += 1
	
	return existing_obstacles

## Gets a random position for an obstacle within safe boundaries
func _get_random_obstacle_position(boundaries: Dictionary) -> Vector2:
	return Vector2(
		randf_range(boundaries.safe_left, boundaries.safe_right),
		randf_range(boundaries.safe_top, boundaries.safe_bottom)
	)

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

## Checks if an obstacle placement is valid
func _is_valid_obstacle_placement(
	new_obstacle: PackedVector2Array,
	existing_obstacles: Array[PackedVector2Array]
) -> bool:
	for existing in existing_obstacles:
		if check_outline_intersection(new_obstacle, existing):
			return false
	return true

## Configures the NavigationServer2D settings
func _configure_navigation_server(map_rid: RID) -> void:
	NavigationServer2D.map_set_active(map_rid, true)
	NavigationServer2D.map_set_cell_size(map_rid, 1.0)
	NavigationServer2D.map_set_edge_connection_margin(map_rid, 5.0)
	NavigationServer2D.map_force_update(map_rid)

## Utility function to check if two outlines intersect
func check_outline_intersection(outline1: PackedVector2Array, outline2: PackedVector2Array) -> bool:
	for i in range(outline1.size()):
		var a1 = outline1[i]
		var a2 = outline1[(i + 1) % outline1.size()]
		
		for j in range(outline2.size()):
			var b1 = outline2[j]
			var b2 = outline2[(j + 1) % outline2.size()]
			
			if segments_intersect(a1, a2, b1, b2):
				return true
			
			if point_in_polygon(a1, outline2) or point_in_polygon(b1, outline1):
				return true
	
	return false

## Utility function to check if two segments intersect
func segments_intersect(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> bool:
	var d = (p2.x - p1.x) * (p4.y - p3.y) - (p2.y - p1.y) * (p4.x - p3.x)
	if abs(d) < 0.0001:
		return false
	var t = ((p3.x - p1.x) * (p4.y - p3.y) - (p3.y - p1.y) * (p4.x - p3.x)) / d
	var u = ((p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x)) / d
	return t >= 0 && t <= 1 && u >= 0 && u <= 1

## Utility function to check if a point is inside a polygon
func point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	var inside = false
	var j = polygon.size() - 1
	
	for i in range(polygon.size()):
		if ((polygon[i].y > point.y) != (polygon[j].y > point.y) and
			point.x < (polygon[j].x - polygon[i].x) * (point.y - polygon[i].y) / 
			(polygon[j].y - polygon[i].y) + polygon[i].x):
			inside = !inside
		j = i
	
	return inside

## Utility function to check if an outline is counterclockwise
func is_outline_counterclockwise(outline: PackedVector2Array) -> bool:
	var sum = 0.0
	for i in range(outline.size()):
		var current = outline[i]
		var next = outline[(i + 1) % outline.size()]
		sum += (next.x - current.x) * (next.y + current.y)
	return sum > 0
