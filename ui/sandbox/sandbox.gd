

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
	camera = %World/Camera2D
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
	queue_redraw()
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
	logger.info("Destroyed colony " % str(colony.name))
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
	var mouse_pos = get_local_mouse_position()

	if _awaiting_colony_placement:
		spawn_colony(mouse_pos)
		_awaiting_colony_placement = false
		return

	_context_menu_manager.clear_active_menu()

	# Check for colony selection first
	var closest_colony = _find_closest_colony(mouse_pos)
	var closest_ant = _find_closest_ant(mouse_pos)

	if closest_colony and _is_within_colony_distance(closest_colony, mouse_pos):
		_context_menu_manager.show_colony_context_menu(closest_colony, closest_colony.position)
	elif closest_ant and _is_within_selection_distance(closest_ant, mouse_pos):
		_context_menu_manager.show_ant_context_menu(closest_ant, closest_ant.position)
	else:
		_context_menu_manager.show_empty_context_menu(mouse_pos)

func _get_object_at_position(p_position: Vector2) -> Node2D:
	# Implementation depends on how you're storing and checking for objects
	# Example implementation:
	var p_world = %World
	for child in p_world.get_children():
		if child is Colony or child is Ant:
			if p_position.distance_to(child.global_position) <= child.radius:
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
	add_child(navigation_region)

	# Create navigation polygon
	navigation_poly = NavigationPolygon.new()
	navigation_poly.agent_radius = 10.0
	navigation_poly.cell_size = 1.0

	# Get viewport size
	var viewport_rect := get_viewport_rect()
	var viewport_size := viewport_rect.size * 4

	# Define margins
	var side_margin := 160.0
	var top_margin := 280.0
	var bottom_margin := 160.0

	# Define the navigation boundary points
	var nav_left := -viewport_size.x/2 + side_margin
	var nav_right := viewport_size.x/2 - side_margin
	var nav_top := -viewport_size.y/2 + top_margin
	var nav_bottom := viewport_size.y/2 - bottom_margin

	# Add main boundary with clockwise winding
	var main_outline = PackedVector2Array([
	   Vector2(nav_left, nav_top),
	   Vector2(nav_right, nav_top),
	   Vector2(nav_right, nav_bottom),
	   Vector2(nav_left, nav_bottom)
	])
	navigation_poly.add_outline(main_outline)

	# Calculate safe area for obstacle placement
	var safe_left := nav_left + OBSTACLE_SIZE_MAX
	var safe_right := nav_right - OBSTACLE_SIZE_MAX
	var safe_top := nav_top + OBSTACLE_SIZE_MAX
	var safe_bottom := nav_bottom - OBSTACLE_SIZE_MAX

	# Track existing obstacles for intersection checks
	var existing_obstacles: Array[PackedVector2Array] = []

	# Place obstacles
	var obstacles_num = floori(NAVIGATION_OBSTACLES_DENSITY * viewport_rect.size.length())
	var obstacles_placed = 0
	var max_attempts = 50

	while obstacles_placed < obstacles_num and max_attempts > 0:
		max_attempts -= 1
	   
		var center_x = randf_range(safe_left, safe_right)
		var center_y = randf_range(safe_top, safe_bottom)
		var center = Vector2(center_x, center_y)
	   
		if center.distance_to(Vector2.ZERO) < 150:
			continue
		   
		var obstacle_size = randf_range(OBSTACLE_SIZE_MIN, OBSTACLE_SIZE_MAX)
		var obstacle_points = _create_obstacle_points(center, obstacle_size)

		# Validate obstacle placement
		var valid = true
		for existing in existing_obstacles:
			if check_outline_intersection(obstacle_points, existing):
				valid = false
				break

		if not valid:
			continue

	   # Add obstacle (ensure clockwise winding order like the main outline)
		if is_outline_counterclockwise(obstacle_points):
			obstacle_points.reverse()		

		navigation_poly.add_outline(obstacle_points)
		existing_obstacles.append(obstacle_points)
		obstacles_placed += 1

	logger.info("Added %d obstacles - Outlines: %d" % [
	   obstacles_placed,
	   navigation_poly.get_outline_count()
	])

	# Generate polygons
	navigation_poly.make_polygons_from_outlines()

	# Set the navigation polygon
	navigation_region.navigation_polygon = navigation_poly

	# Configure NavigationServer2D
	var map_rid = navigation_region.get_navigation_map()
	if map_rid.is_valid():
		NavigationServer2D.map_set_active(map_rid, true)
		NavigationServer2D.map_set_cell_size(map_rid, 1.0)
		NavigationServer2D.map_set_edge_connection_margin(map_rid, 5.0)
		NavigationServer2D.map_force_update(map_rid)

	await get_tree().physics_frame

	return true

func check_outline_intersection(outline1: PackedVector2Array, outline2: PackedVector2Array) -> bool:
	# Check if any edges of outline1 intersect with any edges of outline2
	for i in range(outline1.size()):
		var a1 = outline1[i]
		var a2 = outline1[(i + 1) % outline1.size()]
		
		for j in range(outline2.size()):
			var b1 = outline2[j]
			var b2 = outline2[(j + 1) % outline2.size()]
			
			if segments_intersect(a1, a2, b1, b2):
				return true
			
			# Also check if one outline is inside the other
			if point_in_polygon(a1, outline2) or point_in_polygon(b1, outline1):
				return true
	
	return false
	
func segments_intersect(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> bool:
	var d = (p2.x - p1.x) * (p4.y - p3.y) - (p2.y - p1.y) * (p4.x - p3.x)
	if abs(d) < 0.0001:  # Lines are parallel
		return false
	var t = ((p3.x - p1.x) * (p4.y - p3.y) - (p3.y - p1.y) * (p4.x - p3.x)) / d
	var u = ((p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x)) / d
	return t >= 0 && t <= 1 && u >= 0 && u <= 1
	
func is_outline_counterclockwise(outline: PackedVector2Array) -> bool:
	var sum = 0.0
	for i in range(outline.size()):
		var current = outline[i]
		var next = outline[(i + 1) % outline.size()]
		sum += (next.x - current.x) * (next.y + current.y)
	return sum > 0

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

func _create_obstacle_points(center: Vector2, size: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var num_points := randi_range(6, 8)  # Random number of points for variety
	var angle_step := 2 * PI / num_points
	
	for i in range(num_points):
		# Get base angle for this point
		var angle = i * angle_step
		# Add some randomness to both angle and radius
		var radius = size * (0.7 + randf() * 0.6)  # Random between 70% and 130% of size
		var point = center + Vector2(
			cos(angle) * radius * (0.8 + randf() * 0.4),  # Add radius variance
			sin(angle) * radius * (0.8 + randf() * 0.4)
		)
		points.push_back(point)
	
	return points
#endregion

#region Debug Visualization
func _draw() -> void:
	if not Engine.is_editor_hint() and navigation_poly:
		# First draw the main outline (walkable area)
		var main_outline = navigation_poly.get_outline(0)
		draw_colored_polygon(main_outline, Color.TRANSPARENT)
		
		# Draw all obstacle outlines (non-walkable areas)
		for i in range(1, navigation_poly.get_outline_count()):
			var obstacle = navigation_poly.get_outline(i)
			
			# Draw filled obstacle
			draw_colored_polygon(obstacle, Color(0.5, 0.5, 0.5, 0.7))  # Grey with some transparency
			
			# Draw obstacle border
			for j in range(obstacle.size()):
				var start = obstacle[j]
				var end = obstacle[(j + 1) % obstacle.size()]
				draw_line(start, end, Color(0.3, 0.3, 0.3, 0.8), 2.0)  # Darker grey outline# Darker grey outline
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
