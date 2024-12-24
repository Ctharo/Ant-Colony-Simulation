# Colony Context Menu
class_name ColonyContextMenu
extends BaseContextMenu
@warning_ignore("unused_signal")
signal spawn_ants_requested(colony: Colony)
@warning_ignore("unused_signal")
signal show_info_requested(colony: Colony)
@warning_ignore("unused_signal")
signal destroy_colony_requested(colony: Colony)



func _init() -> void:
	# Add buttons with proper styling
	var spawn = add_button("Spawn Ants", preload("res://ui/styles/spawn_normal.tres"), preload("res://ui/styles/spawn_hover.tres"))
	var info = add_button("Info", preload("res://ui/styles/info_normal.tres"), preload("res://ui/styles/info_hover.tres"))
	var destroy = add_button("Destroy", preload("res://ui/styles/destroy_normal.tres"), preload("res://ui/styles/destroy_hover.tres"))

	spawn.pressed.connect(_on_spawn_pressed)
	info.pressed.connect(_on_info_pressed)
	destroy.pressed.connect(_on_destroy_pressed)

func show_for_colony(pos: Vector2, p_colony: Colony) -> void:
	tracked_colony = p_colony
	show_at(pos, p_colony.radius)  # Pass colony radius for circle

func _on_spawn_pressed() -> void:
	emit_signal("spawn_ants_requested", tracked_colony)
	close()

func _on_info_pressed() -> void:
	emit_signal("show_info_requested", tracked_colony)
	close()

func _on_destroy_pressed() -> void:
	emit_signal("destroy_colony_requested", tracked_colony)
	close()
