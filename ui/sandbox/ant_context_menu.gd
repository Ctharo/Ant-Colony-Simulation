class_name AntContextMenu
extends BaseContextMenu

#region Signals
signal show_info_requested(ant: Ant)
signal destroy_ant_requested(ant: Ant)
signal track_ant_requested(ant: Ant)
#endregion


func _init() -> void:
	var track = add_button("Track Ant",
		preload("res://ui/styles/info_normal.tres"),
		preload("res://ui/styles/info_hover.tres"))

	var info = add_button("Info",
		preload("res://ui/styles/info_normal.tres"),
		preload("res://ui/styles/info_hover.tres"))

	var destroy = add_button("Destroy",
		preload("res://ui/styles/destroy_normal.tres"),
		preload("res://ui/styles/destroy_hover.tres"))

	track.pressed.connect(_on_track_pressed)
	info.pressed.connect(_on_info_pressed)
	destroy.pressed.connect(_on_destroy_pressed)

func show_for_ant(pos: Vector2, p_ant: Ant) -> void:
	if not is_instance_valid(p_ant):
		return

	tracked_ant = p_ant
	show_at(pos, 12.0)

func _on_track_pressed() -> void:
	if is_instance_valid(tracked_ant):
		track_ant_requested.emit(tracked_ant)
	close()

func _on_info_pressed() -> void:
	if is_instance_valid(tracked_ant):
		show_info_requested.emit(tracked_ant)
	close()

func _on_destroy_pressed() -> void:
	if is_instance_valid(tracked_ant):
		destroy_ant_requested.emit(tracked_ant)
	close()
