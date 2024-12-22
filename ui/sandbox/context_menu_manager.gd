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

## Convert screen position to world position
func _get_world_position(screen_pos: Vector2) -> Vector2:
	# Get the viewport transform and camera transform
	var viewport_transform = camera.get_viewport_transform()
	var cam_transform = camera.get_canvas_transform()

	# Get the combined inverse transform
	var transform = (viewport_transform * cam_transform).affine_inverse()

	# Convert screen position to world position
	return transform * screen_pos

## Convert world position to screen position
func _get_screen_position(world_pos: Vector2) -> Vector2:
	return camera.get_viewport().get_canvas_transform() * world_pos



## Shows context menu for ant
func show_ant_context_menu(ant: Ant, world_pos: Vector2) -> void:
	if active_context_menu and is_instance_valid(active_context_menu):
		active_context_menu.close()

	active_context_menu = AntContextMenu.new()
	active_context_menu.setup(camera)
	_ui_layer.add_child(active_context_menu)

	active_context_menu.show_info_requested.connect(func(a): show_ant_info_requested.emit(a))
	active_context_menu.destroy_ant_requested.connect(func(a): destroy_ant_requested.emit(a))

	var screen_position = _get_screen_position(world_pos)
	active_context_menu.show_for_ant(screen_position, ant)

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

	var screen_position = _get_screen_position(world_pos)
	active_context_menu.show_for_colony(screen_position, colony)

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

	var screen_position = _get_screen_position(world_pos)
	active_context_menu.show_at_position(screen_position)

## Clean up active context menu
func clear_active_menu() -> void:
	if active_context_menu and is_instance_valid(active_context_menu):
		active_context_menu.close()
		active_context_menu = null
