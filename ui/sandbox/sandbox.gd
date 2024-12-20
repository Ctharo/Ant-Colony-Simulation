extends Control

var logger: Logger

var ant_info_panel: AntInfoPanel
var colony_info_panel: ColonyInfoPanel
@onready var info_panels_container = %InfoPanelsContainer
@onready var spawn_colony_button = %SpawnColonyButton

# Navigation properties
var navigation_region: NavigationRegion2D
var navigation_poly: NavigationPolygon

const NAVIGATION_OBSTACLES_NUM_MIN = 15
const NAVIGATION_OBSTACLES_NUM_MAX = 15
const OBSTACLE_SIZE_MIN = 20.0
const OBSTACLE_SIZE_MAX = 70.0

# States
var _awaiting_colony_placement: bool = false
var _last_selected_ant: Ant = null

func _init() -> void:
	logger = Logger.new("sandbox", DebugLogger.Category.PROGRAM)

func _ready() -> void:
	initialize()
	_setup_ui()

func initialize() -> bool:
	# Setup navigation before spawning ants
	var result = await setup_navigation()
	return result

func _setup_ui() -> void:
	# Connect UI signals
	spawn_colony_button.pressed.connect(_on_spawn_colony_pressed)


#region Selection Logic
func _find_closest_colony(pos: Vector2) -> Colony:
	var closest_colony: Colony = null
	var closest_distance: float = 100.0  # Maximum selection distance for colonies

	# Get all colonies in the scene
	for colony in ColonyManager.get_all().to_array():
		var distance = colony.global_position.distance_to(pos)
		if distance < closest_distance:
			closest_distance = distance
			closest_colony = colony

	return closest_colony

func _is_within_colony_distance(colony: Colony, pos: Vector2) -> bool:
	return colony.global_position.distance_to(pos) <= colony.radius  # Use colony radius for selection

func _is_within_selection_distance(ant: Ant, pos: Vector2) -> bool:
	return ant.global_position.distance_to(pos) <= 20.0  # Selection radius

func _find_closest_ant(pos: Vector2) -> Ant:
	var closest_ant: Ant = null
	var closest_distance: float = 100.0  # Maximum selection distance

	# Get all ants in the scene
	for ant in AntManager.get_all().to_array():
		var distance = ant.global_position.distance_to(pos)
		if distance < closest_distance:
			closest_distance = distance
			closest_ant = ant

	return closest_ant


#endregion

#region Colony Management
func _on_spawn_colony_pressed() -> void:
	_awaiting_colony_placement = true
	spawn_colony_button.disabled = true

func spawn_colony(p_position: Vector2) -> Colony:
	var colony = ColonyManager.spawn_colony()
	colony.global_position = p_position
	return colony
#endregion

#region Input Handling
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
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

#endregion

#region Scene Management
func _on_close_pressed() -> void:
	transition_to_scene("main")

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

	# Create obstacles container
	var obstacles_container = Node2D.new()
	obstacles_container.name = "Obstacles"
	add_child(obstacles_container)
	move_child(obstacles_container, 0)

	# Get viewport boundaries
	var viewport_rect := get_viewport_rect()
	var size := viewport_rect.size

	# Create walkable area - account for control panel
	var side_margin := 40.0
	var top_margin := 70.0  # Increased to account for control panel
	var bottom_margin := 40.0
	var outline := PackedVector2Array([
		Vector2(side_margin, top_margin),
		Vector2(size.x - side_margin, top_margin),
		Vector2(size.x - side_margin, size.y - bottom_margin),
		Vector2(side_margin, size.y - bottom_margin)
	])

	# Add main outline and generate initial polygons
	navigation_poly.add_outline(outline)
	navigation_poly.make_polygons_from_outlines()

	# Place obstacles
	var placed_obstacles := []
	var max_attempts = 50
	var obstacles_placed = 0
	var obstacles_num = randi_range(NAVIGATION_OBSTACLES_NUM_MIN, NAVIGATION_OBSTACLES_NUM_MAX)

	while obstacles_placed < obstacles_num and max_attempts > 0:
		max_attempts -= 1

		# Generate position - use correct margins
		var center_x = randf_range(side_margin * 3, size.x - side_margin * 3)
		var center_y = randf_range(top_margin * 2, size.y - bottom_margin * 3)
		var center = Vector2(center_x, center_y)

		# Skip if too close to center
		if center.distance_to(size / 2) < 150:
			continue

		var obstacle_size = randf_range(OBSTACLE_SIZE_MIN, OBSTACLE_SIZE_MAX)

		# Check overlap
		var overlaps = false
		for existing in placed_obstacles:
			if center.distance_to(existing["center"]) < (obstacle_size + existing["size"] + 20):
				overlaps = true
				break

		if overlaps:
			continue

		# Generate obstacle points
		var obstacle_points = _create_obstacle_points(center, obstacle_size)

		# Validate obstacle
		if _validate_obstacle(obstacle_points, navigation_poly):
			# Create physical obstacle
			_create_obstacle(obstacle_points, center, obstacles_container)

			# Add to navigation
			navigation_poly.add_outline(obstacle_points)
			navigation_poly.make_polygons_from_outlines()

			placed_obstacles.append({
				"center": center,
				"size": obstacle_size
			})

			obstacles_placed += 1

	# Configure navigation
	navigation_region.navigation_polygon = navigation_poly

	# Configure NavigationServer2D
	var map_rid = navigation_region.get_navigation_map()
	NavigationServer2D.map_set_active(map_rid, true)
	NavigationServer2D.map_set_cell_size(map_rid, 1.0)
	NavigationServer2D.map_set_edge_connection_margin(map_rid, 5.0)
	NavigationServer2D.map_force_update(map_rid)

	# Wait for physics update
	await get_tree().physics_frame
	await get_tree().physics_frame

	logger.debug("Navigation system initialized with %d obstacles" % obstacles_placed)
	return true

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
	if navigation_poly:
		# Draw main outline
		var outline = navigation_poly.get_outline(0)
		var closed_outline = PackedVector2Array(outline)
		closed_outline.append(outline[0])  # Add first point to close the shape
		draw_polyline(closed_outline, Color.GREEN, 2.0)

		# Draw obstacles
		for i in range(1, navigation_poly.get_outline_count()):
			var obstacle = navigation_poly.get_outline(i)
			var closed_obstacle = PackedVector2Array(obstacle)
			closed_obstacle.append(obstacle[0])  # Add first point to close the shape
			draw_polyline(closed_obstacle, Color.RED, 2.0)
#endregion

#region Utils
func get_random_position() -> Vector2:
	var viewport_rect := get_viewport_rect()
	var x := randf_range(0, viewport_rect.size.x)
	var y := randf_range(0, viewport_rect.size.y)
	return Vector2(x, y)
#endregion


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_check_selections()
			get_viewport().set_input_as_handled()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			deselect_all()
	elif event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _check_selections() -> void:
	var mouse_pos = get_global_mouse_position()

	if _awaiting_colony_placement:
		spawn_colony(mouse_pos)
		_awaiting_colony_placement = false
		spawn_colony_button.disabled = false
		return

	# Check for colony selection first (colonies should have priority)
	var closest_colony = _find_closest_colony(mouse_pos)
	var closest_ant = _find_closest_ant(mouse_pos)
	if closest_colony and _is_within_colony_distance(closest_colony, mouse_pos):
		show_colony_info(closest_colony)
	# If no colony selected, try selecting an ant
	elif closest_ant and _is_within_selection_distance(closest_ant, mouse_pos):
		show_ant_info(closest_ant)
	else:
		# If clicking empty space, close both panels
		deselect_all()

func deselect_all():
	if ant_info_panel and ant_info_panel != null:
		ant_info_panel.queue_free()
	if colony_info_panel and colony_info_panel != null:
		colony_info_panel.queue_free()
