class_name EmptyContextMenu
extends BaseContextMenu
@warning_ignore("unused_signal")
signal spawn_colony_requested(position: Vector2)

var spawn_position: Vector2

func _init() -> void:
	var spawn = add_button("Spawn Colony", preload("res://ui/styles/spawn_normal.tres"), preload("res://ui/styles/spawn_hover.tres"))
	spawn.pressed.connect(_on_spawn_pressed)

func show_at_position(pos: Vector2) -> void:
	spawn_position = pos
	show_at(pos)

func _on_spawn_pressed() -> void:
	emit_signal("spawn_colony_requested", spawn_position)
	close()
