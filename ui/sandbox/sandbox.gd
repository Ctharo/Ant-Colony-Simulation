extends Node2D

const MAP_SIZE_COEF = 4.0
var map_generator: MapGenerator
var map_size: Vector2
var logger: Logger
var source_geometry: NavigationMeshSourceGeometryData2D
@onready var camera = $Camera2D

# Navigation properties
var heatmap_manager: HeatmapManager

# States
var initializing: bool = false
@onready var sandbox_ui := %UI as SandboxUI

func _init() -> void:
	logger = Logger.new("sandbox", DebugLogger.Category.PROGRAM)

func _ready() -> void:
	map_size = get_viewport_rect().size * MAP_SIZE_COEF
	camera.target_position = map_size/2
	camera.position = camera.target_position
	initialize()

func initialize() -> bool:
	logger.info("Initializing sandbox...")
	var viewport_size = map_size

	# Generate map first
	var result := await generate_map(viewport_size)
	if not result:
		logger.error("Problem generating map")
		return false

	# Setup heatmap
	result = setup_heatmap()
	if not result:
		logger.error("Problem setting up heatmap")
		return false
		
	heatmap_manager.map_size = map_size

	# Center both camera position and target


	logger.info("Sandbox initialized")
	sandbox_ui.queue_redraw()
	sandbox_ui.initializing = false
	return result

func generate_map(size: Vector2) -> bool:
	map_generator = MapGenerator.new()
	map_generator.name = "MapGenerator"
	add_child(map_generator)
	await map_generator.generate_navigation(size)
	return true

func setup_heatmap() -> bool:
	heatmap_manager = HeatmapManager.new()
	add_child(heatmap_manager)
	heatmap_manager.add_to_group("heatmap")
	heatmap_manager.setup_camera(camera)
	return true



func _exit_tree() -> void:
	ColonyManager.delete_all()

func _on_back_button_pressed() -> void:
	transition_to_scene("main")

#region Scene Management
func transition_to_scene(scene_name: String) -> void:
	create_tween().tween_callback(Callable(self, "_change_scene").bind(scene_name))

func _change_scene(scene_name: String) -> void:
	var error = get_tree().change_scene_to_file("res://" + "ui" + "/" + scene_name + ".tscn")
	if error != OK:
		DebugLogger.error(DebugLogger.Category.PROGRAM, "Failed to load scene: " + scene_name)
#endregion
