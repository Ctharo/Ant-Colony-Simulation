extends Control

var logger: Logger

@onready var ant_info_panel = $AntInfoPanel
@onready var colony_info_panel = $ColonyInfoPanel

# Navigation properties
var navigation_region: NavigationRegion2D
var navigation_poly: NavigationPolygon

# Spawn control parameters
const ANTS_TO_SPAWN = 10
const BATCH_SIZE = 1  # Number of ants to spawn per batch
const FRAMES_BETWEEN_BATCHES = 5  # Frames to wait between batches

# Spawning state
var _pending_spawns: int = 0
var _spawn_colony: Colony = null
var _frames_until_next_batch: int = 0
var _is_spawning: bool = false

func _init() -> void:
	logger = Logger.new("sandbox", DebugLogger.Category.PROGRAM)
	
func _ready() -> void:
	initialize()
		
func initialize() -> bool:
	# Setup navigation before spawning ants
	var result = await setup_navigation()
	if result:
		spawn_ants(ANTS_TO_SPAWN)
	return true

func _process(delta: float) -> void:
	_spawn(delta)

func _spawn(delta:float) -> void:
	if not _is_spawning:
		return

	if _frames_until_next_batch > 0:
		_frames_until_next_batch -= 1
		return

	if _pending_spawns <= 0:
		_finish_spawning()
		return

	var batch_size = mini(BATCH_SIZE, _pending_spawns)
	_spawn_batch(batch_size)
	logger.debug("Spawned batch of %d ants. Remaining: %d" % [batch_size, _pending_spawns])

	_frames_until_next_batch = FRAMES_BETWEEN_BATCHES

## Setup the navigation system for the entire sandbox
## Setup the navigation system for the entire sandbox
func setup_navigation() -> bool:
	# Create navigation region
	navigation_region = NavigationRegion2D.new()
	navigation_region.add_to_group("navigation") 
	add_child(navigation_region)

	# Create navigation polygon
	navigation_poly = NavigationPolygon.new()
	
	# Create a node to hold all obstacles
	var obstacles_container = Node2D.new()
	obstacles_container.name = "Obstacles"
	add_child(obstacles_container)

	# Get viewport boundaries
	var viewport_rect := get_viewport_rect()
	var size := viewport_rect.size

	# Create walkable area polygon (full viewport minus margin)
	var margin := 40.0
	var outline := PackedVector2Array([
		Vector2(margin, margin),
		Vector2(size.x - margin, margin),
		Vector2(size.x - margin, size.y - margin),
		Vector2(margin, size.y - margin)
	])

	# Add main outline first
	navigation_poly.add_outline(outline)
	navigation_poly.make_polygons_from_outlines()

	# Track placed obstacles
	var placed_obstacles := []
	var num_obstacles = randi_range(10, 20)
	var max_attempts = 100
	var obstacles_placed = 0

	while obstacles_placed < num_obstacles and max_attempts > 0:
		max_attempts -= 1

		var center_x = randf_range(margin * 3, size.x - margin * 3)
		var center_y = randf_range(margin * 3, size.y - margin * 3)
		var center = Vector2(center_x, center_y)

		# Avoid placing obstacles in the center
		if center.distance_to(size / 2) < 150:
			continue

		var obstacle_size = randf_range(20, 50)

		# Check overlap with existing obstacles
		var overlaps = false
		for existing in placed_obstacles:
			if center.distance_to(existing["center"]) < (obstacle_size + existing["size"] + 20):
				overlaps = true
				break

		if overlaps:
			continue

		# Generate obstacle points
		var obstacle_points = create_obstacle_points(center, obstacle_size)
		
		# Validate obstacle placement
		if validate_obstacle(obstacle_points, navigation_poly):
			# Create the obstacle
			create_obstacle(obstacle_points, center, obstacles_container)
			
			# Add to navigation system
			navigation_poly.add_outline(obstacle_points)
			navigation_poly.make_polygons_from_outlines()
			
			placed_obstacles.append({
				"center": center,
				"size": obstacle_size
			})
			
			obstacles_placed += 1

	# Configure NavigationServer2D settings
	var map_rid = navigation_region.get_navigation_map()
	NavigationServer2D.map_set_active(map_rid, true)
	NavigationServer2D.map_set_cell_size(map_rid, 1.0)
	NavigationServer2D.map_set_edge_connection_margin(map_rid, 5.0)
	
	# Apply navigation settings
	navigation_region.navigation_polygon = navigation_poly
	navigation_region.enabled = true
	
	# Force update and wait for baking to complete
	NavigationServer2D.map_force_update(map_rid)
	navigation_region.bake_navigation_polygon()
	await navigation_region.bake_finished

	logger.debug("Navigation system initialized with %d obstacles" % obstacles_placed)
	return true

## Create points for an obstacle
func create_obstacle_points(center: Vector2, size: float) -> PackedVector2Array:
	var num_points = 8
	var points = PackedVector2Array()
	
	for p in range(num_points):
		var angle = (p / float(num_points)) * TAU
		var random_offset = randf_range(0.8, 1.2)  # Add some randomness to shape
		var point = Vector2(
			center.x + cos(angle) * size * random_offset,
			center.y + sin(angle) * size * random_offset
		)
		points.push_back(point)
	
	return points

	
## Create a visual obstacle with collision
func create_obstacle(points: PackedVector2Array, center: Vector2, parent: Node) -> void:
	var obstacle = StaticBody2D.new()
	obstacle.collision_layer = 1  # Make sure this matches your navigation layers
	obstacle.collision_mask = 1
	obstacle.position = center
	parent.add_child(obstacle)

	# Create collision shape
	var collision = CollisionPolygon2D.new()
	var local_points = PackedVector2Array()
	for point in points:
		local_points.append(point - center)
	collision.polygon = local_points
	obstacle.add_child(collision)

	# Create visual representation
	var polygon = Polygon2D.new()
	polygon.polygon = local_points
	polygon.color = Color(0.5, 0.5, 0.5, 1.0)
	obstacle.add_child(polygon)
	
	# Add border for depth
	var border = Line2D.new()
	var border_points = local_points.duplicate()
	border_points.append(local_points[0])
	border.points = border_points
	border.width = 2.0
	border.default_color = Color(0.3, 0.3, 0.3, 1.0)
	obstacle.add_child(border)



## Validate obstacle placement
func validate_obstacle(points: PackedVector2Array, nav_poly: NavigationPolygon) -> bool:
	# Check if the obstacle would create invalid navigation
	for i in range(nav_poly.get_outline_count()):
		var outline = nav_poly.get_outline(i)
		
		# Check for intersections with existing navigation polygons
		for j in range(points.size()):
			var p1 = points[j]
			var p2 = points[(j + 1) % points.size()]
			
			for k in range(outline.size()):
				var p3 = outline[k]
				var p4 = outline[(k + 1) % outline.size()]
				
				if segments_intersect(p1, p2, p3, p4):
					return false
	
	# Check for minimum distance from navigation edges
	var min_distance = 20.0  # Minimum distance from navigation edges
	for point in points:
		for i in range(nav_poly.get_outline_count()):
			var outline = nav_poly.get_outline(i)
			for j in range(outline.size()):
				var edge_start = outline[j]
				var edge_end = outline[(j + 1) % outline.size()]
				if point_to_line_distance(point, edge_start, edge_end) < min_distance:
					return false
	
	return true
	
## Calculate point to line distance
func point_to_line_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_vec = line_end - line_start
	var point_vec = point - line_start
	var line_length = line_vec.length()
	if line_length == 0:
		return point_vec.length()
	
	var t = max(0, min(1, point_vec.dot(line_vec) / (line_length * line_length)))
	var projection = line_start + t * line_vec
	return point.distance_to(projection)
	
## Check if two line segments intersect
func segments_intersect(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> bool:
	var d = (p2.x - p1.x) * (p4.y - p3.y) - (p2.y - p1.y) * (p4.x - p3.x)
	if abs(d) < 0.0001:  # Lines are parallel
		return false

	var t = ((p3.x - p1.x) * (p4.y - p3.y) - (p3.y - p1.y) * (p4.x - p3.x)) / d
	var u = ((p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x)) / d

	return t >= 0 && t <= 1 && u >= 0 && u <= 1

## Helper function to visualize the obstacles (optional)
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

## Add an obstacle to the navigation mesh
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

## Handle unhandled input events
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

## Close handler
func _on_close_pressed():
	transition_to_scene("main")

## Transition to a new scene
func transition_to_scene(scene_name: String) -> void:
	create_tween().tween_callback(Callable(self, "_change_scene").bind(scene_name))

func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			ant_info_panel.unselect_current()

## Change to a new scene
func _change_scene(scene_name: String) -> void:
	var error = get_tree().change_scene_to_file("res://" + "ui" + "/" + scene_name + ".tscn")
	if error != OK:
		DebugLogger.error(DebugLogger.Category.PROGRAM, "Failed to load scene: " + scene_name)

func spawn_colony(p_position: Vector2 = get_random_position()) -> Colony:
	_spawn_colony = ColonyManager.spawn_colony()
	_spawn_colony.selected.connect(_on_colony_selected)
	_spawn_colony.deselected.connect(_on_colony_deselected)
	_spawn_colony.global_position = p_position
	return _spawn_colony

func spawn_ants(num_to_spawn: int = 1) -> void:
	logger.info("Spawning %s ants" % num_to_spawn)
	_pending_spawns = num_to_spawn
	if not _spawn_colony:
		spawn_colony(get_viewport_rect().get_center())
	_is_spawning = true
	_frames_until_next_batch = 0

func _spawn_batch(size: int) -> void:
	var ants = _spawn_colony.spawn_ants(size, true)
	_pending_spawns -= size
	for ant in ants:
		ant.ant_selected.connect(_on_ant_selected)
		ant.ant_deselected.connect(_on_ant_deselected)


func _finish_spawning() -> void:
	_is_spawning = false
	#AntManager.start_ants()
	logger.info("Finished spawning all ants")

func _on_ant_selected(ant: Ant):
	ant_info_panel.show_ant_info(ant)

func _on_ant_deselected(ant: Ant):
	ant_info_panel.deselect_current()

func _on_colony_selected(colony: Colony):
	colony_info_panel.show_colony_info(colony)
	
func _on_colony_deselected(colony: Colony):
	colony_info_panel.deselect_current()

func _on_gui_input(event: InputEvent) -> void:
	report()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			ant_info_panel.unselect_current()

func report():
	print("GUI input detected")


func _on_mouse_entered() -> void:
	report()

func _on_mouse_exited() -> void:
	report()

func get_random_position() -> Vector2:
	var viewport_rect := get_viewport_rect()
	var x := randf_range(0, viewport_rect.size.x)
	var y := randf_range(0, viewport_rect.size.y)
	return Vector2(x, y)
