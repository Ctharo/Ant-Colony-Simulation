class_name ColonyContextMenu
extends BaseContextMenu

#region Signals
signal spawn_ants_requested(colony: Colony)
signal show_info_requested(colony: Colony)
signal destroy_colony_requested(colony: Colony)
signal heatmap_requested(colony: Colony)
#endregion


func _init() -> void:
	var spawn = add_button("Spawn Ants", ContextMenuStyles.ActionType.POSITIVE)

	var info = add_button("Info", ContextMenuStyles.ActionType.INFO)

	var heatmap = add_button("Heatmap", ContextMenuStyles.ActionType.DEFAULT)

	var destroy = add_button("Destroy", ContextMenuStyles.ActionType.DESTRUCTIVE)

	spawn.pressed.connect(_on_spawn_pressed)
	info.pressed.connect(_on_info_pressed)
	destroy.pressed.connect(_on_destroy_pressed)
	heatmap.pressed.connect(_on_heatmap_pressed)

func show_for_colony(pos: Vector2, p_colony: Colony) -> void:
	if not is_instance_valid(p_colony):
		return

	tracked_colony = p_colony
	show_at(pos, p_colony.radius)

func _on_spawn_pressed() -> void:
	if is_instance_valid(tracked_colony):
		spawn_ants_requested.emit(tracked_colony)
	close()

func _on_info_pressed() -> void:
	if is_instance_valid(tracked_colony):
		show_info_requested.emit(tracked_colony)
	close()

func _on_destroy_pressed() -> void:
	if is_instance_valid(tracked_colony):
		destroy_colony_requested.emit(tracked_colony)
	close()

func _on_heatmap_pressed() -> void:
	if is_instance_valid(tracked_colony):
		heatmap_requested.emit(tracked_colony)
	close()
