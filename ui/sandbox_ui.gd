class_name SandboxUI
extends Control
##UI controller for the sandbox simulation view

#region Getters

var hovered_entity:
	get:
		if is_instance_valid(camera) and is_instance_valid(camera.hovered_entity):
			return camera.hovered_entity
		return null


#endregion

#region Node References
var camera: CameraController
var active_context_menu: BaseContextMenu
var entity_info_panel: EntityInfoPanel
var hovered_entity_label: Label
var debug_menu: DebugMenu

@onready var overlay: ColorRect = %InitializingRect
@onready var info_panels_container := %InfoPanelsContainer
#endregion

#region Managers
var settings_manager: SettingsManager = SettingsManager
var colony_manager: ColonyManager = ColonyManager
var ant_manager = AntManager
var food_manager: FoodManager = FoodManager
var sandbox: Node2D
#endregion

#region State
var highlight_ants: bool = false

var initializing: bool = true:
	set(value):
		initializing = value
		if not initializing and is_instance_valid(overlay):
			overlay.queue_free()
			overlay = null

#endregion

#region Lifecycle
func _ready() -> void:
	camera = get_node("../../Camera2D")
	sandbox = get_node("../..")

	if is_instance_valid(overlay):
		overlay.visible = true

	_setup_debug_menu()



func _process(_delta: float) -> void:
	queue_redraw()
	_update_hovered_entity_label()

func _setup_debug_menu() -> void:
	debug_menu = DebugMenu.new()
	debug_menu.setup(sandbox)
	get_node("ControlPanel/HBoxContainer").add_child(debug_menu)

	# UI and camera must keep processing while get_tree().paused is true,
	# otherwise the Resume button and panning freeze along with the sim.
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera.process_mode = Node.PROCESS_MODE_ALWAYS

func _update_hovered_entity_label() -> void:
	if is_instance_valid(hovered_entity_label):
		hovered_entity_label.queue_free()
		hovered_entity_label = null

	if hovered_entity:
		hovered_entity_label = Label.new()
		hovered_entity_label.name = "hovered_entity"
		hovered_entity_label.text = hovered_entity.name
		add_child(hovered_entity_label)
		hovered_entity_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
#endregion

#region Input Handling
func _on_gui_input(event: InputEvent) -> void:
	if initializing:
		return

	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				handle_left_click()
			MOUSE_BUTTON_RIGHT:
				handle_right_click()

		get_viewport().set_input_as_handled()
#endregion

#region Click Handling
func handle_left_click() -> void:
	clear_active_menus()
	select_hovered_entity()

func handle_right_click() -> void:
	clear_active_menus()
	if is_instance_valid(camera) and is_instance_valid(camera.hovered_entity):
		show_context_menu()
	else:
		show_empty_context_menu()

func select_hovered_entity() -> void:
	if hovered_entity:
		show_info_panel(hovered_entity)

#endregion

#region Context Menu Management
func show_context_menu() -> void:
		_create_context_window()
		if camera.hovered_entity is Ant:
			_show_ant_context_menu()
		elif camera.hovered_entity is Colony:
			_show_colony_context_menu()

func _show_colony_context_menu() -> void:

	var colony: Colony = camera.hovered_entity

	active_context_menu.add_button("Spawn Ants",
		preload("res://ui/styles/spawn_normal.tres"),
		preload("res://ui/styles/spawn_hover.tres"))
	active_context_menu.add_button("Info",
		preload("res://ui/styles/info_normal.tres"),
		preload("res://ui/styles/info_hover.tres"))
	active_context_menu.add_button("Heatmap",
		preload("res://ui/styles/info_normal.tres"),
		preload("res://ui/styles/info_hover.tres"))
	active_context_menu.add_button("Destroy",
		preload("res://ui/styles/destroy_normal.tres"),
		preload("res://ui/styles/destroy_hover.tres"))

	active_context_menu.button_pressed.connect(
		func(index: int): _on_colony_menu_button_pressed(index, colony))
	active_context_menu.track_object(colony)
	active_context_menu.show_at(
		world_to_screen(colony.global_position),
		colony.radius
	)


func _on_colony_menu_button_pressed(index: int, colony: Colony) -> void:
	if not is_instance_valid(colony):
		return

	clear_active_menus()


	match index:
		0: # Spawn Ants
			_spawn_ants_at_colony(colony)
		1: # Info
			show_info_panel(colony)
		2: # Heatmap
			colony.heatmap_enabled = !colony.heatmap_enabled
		3: # Destroy
			colony_manager.remove_colony(colony)


func _spawn_ants_at_colony(colony: Colony) -> void:
	var spawn_count: int = int(settings_manager.get_setting("ant_spawn_count", 5))
	colony.spawn_ants(spawn_count)


## Clears, initializes, and sets [member active_context_menu]
func _create_context_window() -> void:
	clear_active_menus()
	active_context_menu = BaseContextMenu.new()
	active_context_menu.setup(camera)
	add_child(active_context_menu)

func show_empty_context_menu() -> void:
	_create_context_window()

	active_context_menu.add_button("Spawn Colony",
		preload("res://ui/styles/spawn_normal.tres"),
		preload("res://ui/styles/spawn_hover.tres"))
	active_context_menu.add_button("Spawn Food",
		preload("res://ui/styles/spawn_normal.tres"),
		preload("res://ui/styles/spawn_hover.tres"))

	var pos = get_global_mouse_position()
	active_context_menu.button_pressed.connect(
		func(index: int): _on_empty_menu_button_pressed(index, pos))
	active_context_menu.show_at(pos)

func _on_empty_menu_button_pressed(index: int, pos: Vector2) -> void:
	var global_pos = screen_to_world(pos)
	match index:
		0: # Spawn Colony
			_on_spawn_colony_requested(global_pos)
		1: # Spawn Food
			_on_spawn_food_requested(global_pos)

	clear_active_menus()


func _show_ant_context_menu() -> void:

	var ant: Ant = hovered_entity
	if not ant:
		return

	active_context_menu.add_button("Info",
		preload("res://ui/styles/info_normal.tres"),
		preload("res://ui/styles/info_hover.tres"))
	active_context_menu.add_button("Track",
		preload("res://ui/styles/info_normal.tres"),
		preload("res://ui/styles/info_hover.tres"))
	active_context_menu.add_button("Kill",
		preload("res://ui/styles/destroy_normal.tres"),
		preload("res://ui/styles/destroy_hover.tres"))

	active_context_menu.button_pressed.connect(
		func(index: int): _on_ant_menu_button_pressed(index, ant))
	active_context_menu.track_object(ant)
	active_context_menu.show_at(world_to_screen(ant.global_position))

func _on_ant_menu_button_pressed(index: int, ant: Ant) -> void:
	if not is_instance_valid(ant):
		return

	match index:
		0: # Info
			show_info_panel(ant)
		1: # Track
			camera.track_entity(ant)
		2: # Kill
			ant_manager.remove_ant(ant)

	clear_active_menus()

func clear_active_menus() -> void:
	close_context_menu()
	close_info_panel()


func close_context_menu() -> void:
	if is_instance_valid(active_context_menu):
		active_context_menu.queue_free()

#endregion

#region Info Panel Management
func show_info_panel(entity: Node) -> void:
	if not entity:
		return

	entity_info_panel = create_info_panel()

	if entity is Colony:
		entity_info_panel.highlight_ants.connect(_on_colony_highlight_ants_requested)

	entity_info_panel.show_entity_info(entity)

func close_info_panel() -> void:
	if is_instance_valid(entity_info_panel):
		entity_info_panel.queue_free()
	entity_info_panel = null

func create_info_panel() -> EntityInfoPanel:
	close_info_panel()
	entity_info_panel = preload("res://ui/entity_info_panel.tscn").instantiate()
	info_panels_container.add_child(entity_info_panel)
	return entity_info_panel

func deselect_all() -> void:
	close_info_panel()
#endregion

#region Colony Handlers
func _on_spawn_colony_requested(pos: Vector2) -> void:
	_spawn_colony_at(pos)

func _spawn_colony_at(pos: Vector2) -> void:
	var colony = colony_manager.spawn_colony_at(pos)
	if not colony:
		Toast.error(self, "Failed to spawn colony")


func _on_colony_highlight_ants_requested(colony: Colony, enabled: bool) -> void:
	if not is_instance_valid(colony):
		return
	colony.highlight_ants_enabled = enabled


#endregion

#region Food Handlers
func _on_spawn_food_requested(pos: Vector2) -> void:
	_spawn_food_at(pos)

func _spawn_food_at(pos: Vector2, count: int = -1) -> void:
	if count <= 0:
		count = int(settings_manager.get_setting("food_spawn_count", 50))
	food_manager.spawn_food_cluster(pos, count)
#endregion

#region Coordinate Conversion

func world_to_screen(world_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_pos

func screen_to_world(screen_pos: Vector2) -> Vector2:
	var vp = get_viewport()
	return (vp.get_screen_transform() * vp.get_canvas_transform()).affine_inverse() \
		* screen_pos

#endregion
