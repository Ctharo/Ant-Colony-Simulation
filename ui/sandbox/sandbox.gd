

extends Control

var logger: Logger
var _context_menu_manager: ContextMenuManager
var source_geometry: NavigationMeshSourceGeometryData2D

var ant_info_panel: AntInfoPanel
var colony_info_panel: ColonyInfoPanel
@onready var info_panels_container = %InfoPanelsContainer
@onready var world = %World
@onready var camera = $World/Camera2D

# Navigation properties
var navigation_region: NavigationRegion2D
var navigation_poly: NavigationPolygon

const NAVIGATION_OBSTACLES_DENSITY = 1
const OBSTACLE_SIZE_MIN = 20.0
const OBSTACLE_SIZE_MAX = 70.0

# States
var _awaiting_colony_placement: bool = false

func _init() -> void:
	logger = Logger.new("sandbox", DebugLogger.Category.PROGRAM)

func _ready() -> void:
	initialize()
	_setup_context_menu_manager()

func _setup_context_menu_manager() -> void:
	var camera = %World/Camera2D
	var ui_layer = $UI
	_context_menu_manager = ContextMenuManager.new(camera, ui_layer)
	add_child(_context_menu_manager)

	# Connect context menu signals to local methods
	_context_menu_manager.spawn_ants_requested.connect(_on_spawn_ants_requested)
	_context_menu_manager.show_colony_info_requested.connect(_on_show_colony_info_requested)
	_context_menu_manager.destroy_colony_requested.connect(_on_destroy_colony_requested)
	_context_menu_manager.show_ant_info_requested.connect(_on_show_ant_info_requested)
	_context_menu_manager.destroy_ant_requested.connect(_on_destroy_ant_requested)
	_context_menu_manager.spawn_colony_requested.connect(_on_spawn_colony_requested)

func initialize() -> bool:
	# Setup navigation before spawning ants
	var result = await setup_navigation()
	return result

#region Selection Logic
func _find_closest_colony(pos: Vector2) -> Colony:
	var closest_colony: Colony = null
	var closest_distance: float = 100.0  # Maximum selection distance for colonies

	for colony in ColonyManager.get_all().to_array():
		var distance = colony.global_position.distance_to(pos)
		if distance < closest_distance:
			closest_distance = distance
			closest_colony = colony

	return closest_colony

func _find_closest_ant(pos: Vector2) -> Ant:
	var closest_ant: Ant = null
	var closest_distance: float = 100.0  # Maximum selection distance

	for ant in AntManager.get_all().to_array():
		var distance = ant.global_position.distance_to(pos)
		if distance < closest_distance:
			closest_distance = distance
			closest_ant = ant

	return closest_ant

func _is_within_colony_distance(colony: Colony, pos: Vector2) -> bool:
	return colony.global_position.distance_to(pos) <= colony.radius

func _is_within_selection_distance(ant: Ant, pos: Vector2) -> bool:
	return ant.global_position.distance_to(pos) <= 20.0
#endregion


#region Context Menu Callbacks
func _on_spawn_colony_requested(pos: Vector2) -> void:
	spawn_colony(pos)

func _on_show_colony_info_requested(colony: Colony) -> void:
	show_colony_info(colony)

func _on_spawn_ants_requested(colony: Colony) -> void:
	colony.spawn_ants(10, true)

func _on_destroy_colony_requested(colony: Colony) -> void:
	logger.info("Destroyed colony " % colony.name)
	ColonyManager.remove_colony(colony)

func _on_show_ant_info_requested(ant: Ant) -> void:
	show_ant_info(ant)

func _on_destroy_ant_requested(ant: Ant) -> void:
	logger.info("Destroyed ant " % ant.name)
	AntManager.remove_ant(ant)
#endregion

#region Panel Management
func show_ant_info(ant: Ant) -> void:
	if ant_info_panel and ant_info_panel != null:
		if ant == ant_info_panel.current_ant:
			ant_info_panel.queue_free()
			return
		ant_info_panel.queue_free()
	ant_info_panel = load("res://ui/debug/ant/ant_info_panel.tscn").instantiate()
	info_panels_container.add_child(ant_info_panel)
	ant_info_panel.show_ant_info(ant)
	ant_info_panel.show()

func show_colony_info(colony: Colony) -> void:
	if colony_info_panel and colony_info_panel != null:
		if colony == colony_info_panel.current_colony:
			colony_info_panel.queue_free()
			return
		colony_info_panel.queue_free()
	colony_info_panel = load("res://ui/debug/colony/colony_info_panel.tscn").instantiate()
	info_panels_container.add_child(colony_info_panel)
	colony_info_panel.show_colony_info(colony)
	colony_info_panel.show()

func deselect_all() -> void:
	if ant_info_panel and ant_info_panel != null:
		ant_info_panel.queue_free()
	if colony_info_panel and colony_info_panel != null:
		colony_info_panel.queue_free()
#endregion

#region Colony Management
func spawn_colony(p_position: Vector2) -> Colony:
	var colony = ColonyManager.spawn_colony()
	colony.global_position = p_position
	logger.info("Spawned new colony %s at position %s" % [colony.name, str(colony.global_position)])
	return colony
#endregion



#region Colony Management
func _on_spawn_colony_pressed() -> void:
	_awaiting_colony_placement = true

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_check_selections()
			get_viewport().set_input_as_handled()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			deselect_all()
	elif event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()
		get_viewport().set_input_as_handled()

func _check_selections() -> void:
	var mouse_pos = get_world_mouse_position()

	if _awaiting_colony_placement:
		spawn_colony(mouse_pos)
		_awaiting_colony_placement = false
		return

	_context_menu_manager.clear_active_menu()

	# Check for colony selection first
	var closest_colony = _find_closest_colony(mouse_pos)
	var closest_ant = _find_closest_ant(mouse_pos)

	if closest_colony and _is_within_colony_distance(closest_colony, mouse_pos):
		_context_menu_manager.show_colony_context_menu(closest_colony)
	elif closest_ant and _is_within_selection_distance(closest_ant, mouse_pos):
		_context_menu_manager.show_ant_context_menu(closest_ant)
	else:
		_context_menu_manager.show_empty_context_menu(mouse_pos)

# Update get_world_mouse_position to ensure correct coordinate transformation
func get_world_mouse_position() -> Vector2:
	# Get the viewport and its center
	var viewport = get_viewport()
	var viewport_size = viewport.get_visible_rect().size

	# Get mouse position relative to viewport center
	var mouse_pos = get_local_mouse_position() - viewport_size / 2

	# Apply camera transform
	return mouse_pos / camera.zoom + camera.position

func _get_object_at_position(position: Vector2) -> Node2D:
	# Implementation depends on how you're storing and checking for objects
	# Example implementation:
	var world = %World
	for child in world.get_children():
		if child is Colony or child is Ant:
			if position.distance_to(child.global_position) <= child.radius:
				return child
	return null
#endregion

#region Scene Management
func transition_to_scene(scene_name: String) -> void:
	create_tween().tween_callback(Callable(self, "_change_scene").bind(scene_name))

func _change_scene(scene_name: String) -> void:
	var error = get_tree().change_scene_to_file("res://" + "ui" + "/" + scene_name + ".tscn")
	if error != OK:
		DebugLogger.error(DebugLogger.Category.PROGRAM, "Failed to load scene: " + scene_name)
#endregion

#region Navigation Setup
func setup_navigation() -> bool:
	# Create navigation region
	navigation_region = NavigationRegion2D.new()
	navigation_region.add_to_group("navigation")
	world.add_child(navigation_region)

	# Create navigation polygon and source geometry data
	navigation_poly = NavigationPolygon.new()
	source_geometry = NavigationMeshSourceGeometryData2D.new()

	# Configure navigation polygon to match ant agent settings
	navigation_poly.agent_radius = 10.0  # Match the ant's nav_agent radius
	navigation_poly.cell_size = 1.0  # Match the NavigationServer cell size

	# Create obstacles container
	var obstacles_container = Node2D.new()
	obstacles_container.name = "Obstacles"
	world.add_child(obstacles_container)
	world.move_child(obstacles_container, 0)

	# Get viewport boundaries
	var viewport_rect := get_viewport_rect()
	var _size := viewport_rect.size * 4

	# Define margins
	var side_margin := 160.0
	var top_margin := 280.0
	var bottom_margin := 160.0

	# Define the navigation boundary points
	var nav_left := -_size.x/2 + side_margin
	var nav_right := _size.x/2 - side_margin
	var nav_top := -_size.y/2 + top_margin
	var nav_bottom := _size.y/2 - bottom_margin

	# Calculate safe area for obstacle placement (inset from navigation bounds)
	var safe_left := nav_left + OBSTACLE_SIZE_MAX
	var safe_right := nav_right - OBSTACLE_SIZE_MAX
	var safe_top := nav_top + OBSTACLE_SIZE_MAX
	var safe_bottom := nav_bottom - OBSTACLE_SIZE_MAX

	# Add main traversable outline
	var outline := PackedVector2Array([
		Vector2(nav_left, nav_top),
		Vector2(nav_right, nav_top),
		Vector2(nav_right, nav_bottom),
		Vector2(nav_left, nav_bottom)
	])
	source_geometry.add_traversable_outline(outline)

	# Calculate number of obstacles based on viewport size
	var obstacles_num = floori(NAVIGATION_OBSTACLES_DENSITY * viewport_rect.size.length())

	# Place obstacles
	var placed_obstacles := []
	var max_attempts = 50
	var obstacles_placed = 0

	while obstacles_placed < obstacles_num and max_attempts > 0:
		max_attempts -= 1

		var center_x = randf_range(safe_left, safe_right)
		var center_y = randf_range(safe_top, safe_bottom)
		var center = Vector2(center_x, center_y)

		# Skip if too close to center of map
		if center.distance_to(Vector2.ZERO) < 150:
			continue

		var obstacle_size = randf_range(OBSTACLE_SIZE_MIN, OBSTACLE_SIZE_MAX)

		# Check overlap with existing obstacles
		var overlaps = false
		for existing in placed_obstacles:
			if center.distance_to(existing["center"]) < (obstacle_size + existing["size"] + 20):
				overlaps = true
				break

		if overlaps:
			continue

		# Generate obstacle points
		var obstacle_points = _create_obstacle_points(center, obstacle_size)

		# Validate obstacle is within navigation bounds
		var is_valid = true
		for point in obstacle_points:
			if point.x < nav_left or point.x > nav_right or \
			   point.y < nav_top or point.y > nav_bottom:
				is_valid = false
				break

		if not is_valid:
			continue

		# Create physical obstacle
		_create_obstacle(obstacle_points, center, obstacles_container)

		# Add obstacle outline to source geometry
		source_geometry.add_obstruction_outline(obstacle_points)

		placed_obstacles.append({
			"center": center,
			"size": obstacle_size
		})

		obstacles_placed += 1

	# Parse and bake navigation mesh
	await _parse_and_bake_navigation(navigation_poly, source_geometry)

	# Configure navigation
	navigation_region.navigation_polygon = navigation_poly

	# Configure NavigationServer2D to match ant agent settings
	var map_rid = navigation_region.get_navigation_map()
	NavigationServer2D.map_set_active(map_rid, true)
	NavigationServer2D.map_set_cell_size(map_rid, 1.0)
	NavigationServer2D.map_set_edge_connection_margin(map_rid, 5.0)
	NavigationServer2D.map_force_update(map_rid)

	# Wait for physics update
	await get_tree().physics_frame
	await get_tree().physics_frame

	HeatmapManager.setup_navigation(navigation_region)
	queue_redraw()

	logger.debug("Navigation system initialized with %d obstacles" % obstacles_placed)
	return true

func _parse_and_bake_navigation(nav_poly: NavigationPolygon, source_geometry: NavigationMeshSourceGeometryData2D) -> void:
	# Create callbacks for async operations
	var baking_done = func():
		logger.debug("Navigation baking completed")

	var parsing_done = func():
		logger.debug("Navigation parsing completed")
		# After parsing is done, proceed with baking
		NavigationServer2D.bake_from_source_geometry_data_async(
			nav_poly,
			source_geometry,
			baking_done
		)

	# Parse the source geometry using self (current node) as root
	NavigationServer2D.parse_source_geometry_data(
		nav_poly,
		source_geometry,
		self,  # Use current node as root for parsing
		parsing_done
	)

	# Wait for both operations to complete
	await get_tree().physics_frame

func _create_obstacle_points(center: Vector2, size: float) -> PackedVector2Array:
	var num_points = 8
	var points = PackedVector2Array()

	for p in range(num_points):
		var angle = (p / float(num_points)) * TAU
		# Add randomness to both the angle and radius
		var angle_offset = randf_range(-0.2, 0.2)  # Random angle variation
		var radius_multiplier = randf_range(0.8, 1.2)  # Random size variation
		var point = Vector2(
			center.x + cos(angle + angle_offset) * size * radius_multiplier,
			center.y + sin(angle + angle_offset) * size * radius_multiplier
		)
		points.push_back(point)

	return points

func _create_obstacle(points: PackedVector2Array, center: Vector2, parent: Node) -> void:
	var obstacle = StaticBody2D.new()
	obstacle.position = center
	parent.add_child(obstacle)

	# Create collision shape
	var collision = CollisionPolygon2D.new()
	var local_points = PackedVector2Array()
	for point in points:
		local_points.append(point - center)
	collision.polygon = local_points
	obstacle.add_child(collision)

	# Create base rock polygon
	var polygon = Polygon2D.new()
	polygon.polygon = local_points
	polygon.color = Color(0.5, 0.5, 0.5, 1.0)  # Base gray color
	obstacle.add_child(polygon)

	# Add darker border for depth
	var border = Line2D.new()
	var border_points = local_points.duplicate()
	border_points.append(local_points[0])
	border.points = border_points
	border.width = 2.0
	border.default_color = Color(0.3, 0.3, 0.3, 1.0)  # Darker gray border
	obstacle.add_child(border)

	# Add texture variation with a slightly lighter overlay
	var texture_polygon = Polygon2D.new()
	var smaller_points = PackedVector2Array()
	for point in local_points:
		smaller_points.append(point * 0.8)  # 80% size of original
	texture_polygon.polygon = smaller_points
	texture_polygon.color = Color(0.6, 0.6, 0.6, 0.3)  # Lighter gray with transparency
	obstacle.add_child(texture_polygon)

func _validate_obstacle(points: PackedVector2Array, nav_poly: NavigationPolygon) -> bool:
	# Check for minimum spacing from existing polygons
	var min_spacing = 10.0

	for i in range(nav_poly.get_outline_count()):
		var outline = nav_poly.get_outline(i)
		for point in points:
			for j in range(outline.size()):
				var edge_start = outline[j]
				var edge_end = outline[(j + 1) % outline.size()]

				# Check distance to edge
				var edge_vector = edge_end - edge_start
				var point_vector = point - edge_start
				var edge_length_sq = edge_vector.length_squared()

				if edge_length_sq == 0:
					if point_vector.length() < min_spacing:
						return false
					continue

				var t = clamp(point_vector.dot(edge_vector) / edge_length_sq, 0, 1)
				var projection = edge_start + t * edge_vector

				if point.distance_to(projection) < min_spacing:
					return false

	return true

func segments_intersect(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> bool:
	var d = (p2.x - p1.x) * (p4.y - p3.y) - (p2.y - p1.y) * (p4.x - p3.x)
	if abs(d) < 0.0001:  # Lines are parallel
		return false

	var t = ((p3.x - p1.x) * (p4.y - p3.y) - (p3.y - p1.y) * (p4.x - p3.x)) / d
	var u = ((p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x)) / d

	return t >= 0 && t <= 1 && u >= 0 && u <= 1

func add_navigation_obstacle(obstacle_points: PackedVector2Array) -> void:
	if not navigation_poly or not navigation_region:
		logger.error("Navigation not initialized")
		return

	# Add outline to navigation polygon
	navigation_poly.add_outline(obstacle_points)

	# Update the region with new polygon
	navigation_region.navigation_polygon = navigation_poly

	# Force navigation update
	NavigationServer2D.map_force_update(navigation_region.get_navigation_map())

	# Wait for changes to take effect
	await get_tree().physics_frame
#endregion

#region Debug Visualization
func _draw() -> void:
	if not source_geometry:
		return

	# Draw traversable outlines in green
	var traversable_outlines = source_geometry.get_traversable_outlines()
	for outline in traversable_outlines:
		var closed_outline = PackedVector2Array(outline)
		closed_outline.append(outline[0])  # Add first point to close the shape
		draw_polyline(closed_outline, Color.GREEN, 2.0)

	# Draw obstruction outlines in red
	var obstruction_outlines = source_geometry.get_obstruction_outlines()
	for outline in obstruction_outlines:
		var closed_outline = PackedVector2Array(outline)
		closed_outline.append(outline[0])  # Add first point to close the shape
		draw_polyline(closed_outline, Color.RED, 2.0)

	# Optionally draw the final navigation polygons in a different color
	if navigation_poly:
		var vertices = navigation_poly.vertices
		for polygon_idx in range(navigation_poly.get_polygon_count()):
			var indices = navigation_poly.get_polygon(polygon_idx)
			var points = PackedVector2Array()
			for idx in indices:
				points.append(vertices[idx])
			points.append(points[0])  # Close the polygon
			draw_polyline(points, Color(0.5, 0.5, 1.0, 0.5), 1.0)  # Light blue for final navmesh
#endregion

#region Utils
func get_random_position() -> Vector2:
	var viewport_rect := get_viewport_rect()
	var x := randf_range(0, viewport_rect.size.x)
	var y := randf_range(0, viewport_rect.size.y)
	return Vector2(x, y)
#endregion

func _exit_tree() -> void:
	ColonyManager.delete_all()


func _on_back_button_pressed() -> void:
	transition_to_scene("main")
