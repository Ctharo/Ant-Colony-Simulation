extends Node2D
## Main sandbox scene managing the simulation environment

const MAP_SIZE_COEF := 4.0

var settings_manager := SettingsManager
var map_generator: MapGenerator
var map_size: Vector2
var logger: iLogger
var source_geometry: NavigationMeshSourceGeometryData2D
var heatmap_manager: HeatmapManager

@onready var camera: CameraController = $Camera2D
@onready var sandbox_ui := %UI as SandboxUI
@onready var ant_container: Node2D = $AntContainer
@onready var colony_container: Node2D = $ColonyContainer
@onready var food_container: Node2D = $FoodContainer

var initializing: bool = false

#region Lifecycle
func _init() -> void:
	logger = iLogger.new("sandbox", DebugLogger.Category.PROGRAM)


func _ready() -> void:
	add_to_group("sandbox")
	
	map_size = get_viewport_rect().size * MAP_SIZE_COEF
	camera.target_position = map_size / 2.0
	camera.position = camera.target_position
	
	_setup_managers()
	initialize()


func _setup_managers() -> void:
	ColonyManager.set_colony_container(colony_container)
	FoodManager.set_food_container(food_container)


func _exit_tree() -> void:
	ColonyManager.delete_all()
#endregion

#region Initialization
func initialize() -> bool:
	logger.info("Initializing sandbox...")
	var viewport_size := map_size
	
	var result := await generate_map(viewport_size)
	if not result:
		logger.error("Problem generating map")
		return false
	
	result = setup_heatmap()
	if not result:
		logger.error("Problem setting up heatmap")
		return false
	
	heatmap_manager.map_size = map_size
	
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
	heatmap_manager = HeatmapManager
	heatmap_manager.setup_navigation()
	heatmap_manager.setup_camera(camera)
	return true
#endregion

#region Scene Management
func _on_back_button_pressed() -> void:
	transition_to_scene("main")


func transition_to_scene(scene_name: String) -> void:
	create_tween().tween_callback(Callable(self, "_change_scene").bind(scene_name))


func _change_scene(scene_name: String) -> void:
	var error := get_tree().change_scene_to_file("res://ui/" + scene_name + ".tscn")
	if error != OK:
		DebugLogger.error(DebugLogger.Category.PROGRAM, "Failed to load scene: " + scene_name)
#endregion
