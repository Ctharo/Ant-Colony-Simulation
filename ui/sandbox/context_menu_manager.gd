class_name ContextMenuManager
extends Node

## Camera node reference for coordinate transformations
var camera: Camera2D

## Currently active context menu instance
var active_context_menu: BaseContextMenu

## UI layer node reference
var _ui_layer: CanvasLayer

# Signals
signal spawn_ants_requested(colony: Colony)
signal show_colony_info_requested(colony: Colony)
signal destroy_colony_requested(colony: Colony)
signal show_ant_info_requested(ant: Ant)
signal destroy_ant_requested(ant: Ant)
signal spawn_colony_requested(position: Vector2)

func _init(p_camera: Camera2D, p_ui_layer: CanvasLayer) -> void:
	camera = p_camera
	_ui_layer = p_ui_layer

## Shows context menu for ant
func show_ant_context_menu(ant: Ant, world_pos: Vector2) -> void:
	if active_context_menu and is_instance_valid(active_context_menu):
		active_context_menu.close()

	active_context_menu = AntContextMenu.new()
	active_context_menu.setup(camera)
	_ui_layer.add_child(active_context_menu)

	active_context_menu.show_info_requested.connect(func(a): show_ant_info_requested.emit(a))
	active_context_menu.destroy_ant_requested.connect(func(a): destroy_ant_requested.emit(a))

	active_context_menu.show_for_ant(camera.get_screen_to_canvas(world_pos), ant)

## Shows context menu for colony
func show_colony_context_menu(colony: Colony, world_pos: Vector2) -> void:
	if active_context_menu and is_instance_valid(active_context_menu):
		active_context_menu.close()

	active_context_menu = ColonyContextMenu.new()
	active_context_menu.setup(camera)
	_ui_layer.add_child(active_context_menu)

	active_context_menu.spawn_ants_requested.connect(func(col): spawn_ants_requested.emit(col))
	active_context_menu.show_info_requested.connect(func(col): show_colony_info_requested.emit(col))
	active_context_menu.destroy_colony_requested.connect(func(col): destroy_colony_requested.emit(col))

	active_context_menu.show_for_colony(camera.get_screen_to_canvas(world_pos), colony)

## Shows context menu for empty space
func show_empty_context_menu(world_pos: Vector2) -> void:
	if active_context_menu and is_instance_valid(active_context_menu):
		active_context_menu.close()

	active_context_menu = EmptyContextMenu.new()
	active_context_menu.setup(camera)
	_ui_layer.add_child(active_context_menu)

	# When the menu requests colony spawn, emit the original world position
	active_context_menu.spawn_colony_requested.connect(func(_screen_pos):
		spawn_colony_requested.emit(world_pos)
	)

	active_context_menu.show_at_position(camera.get_screen_to_canvas(world_pos))

## Clean up active context menu
func clear_active_menu() -> void:
	if active_context_menu and is_instance_valid(active_context_menu):
		active_context_menu.close()
		active_context_menu = null
