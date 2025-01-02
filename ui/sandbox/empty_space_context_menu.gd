class_name EmptyContextMenu
extends BaseContextMenu
@warning_ignore("unused_signal")
signal spawn_colony_requested(position: Vector2)
signal spawn_foods_requested(position: Vector2)
var spawn_position: Vector2

func _init() -> void:
	# Add food spawn button
	var spawn_food = add_button("Spawn Food", ContextMenuStyles.ActionType.POSITIVE)
	spawn_food.pressed.connect(_on_food_spawn_pressed)
	# Add colony spawn button
	var spawn = add_button("Spawn Colony", ContextMenuStyles.ActionType.POSITIVE)
	spawn.pressed.connect(_on_spawn_pressed)



func show_at_position(pos: Vector2) -> void:
	spawn_position = pos
	show_at(pos)

func _on_spawn_pressed() -> void:
	emit_signal("spawn_colony_requested", spawn_position)
	close()

func _on_food_spawn_pressed() -> void:
	spawn_foods_requested.emit(spawn_position)
	close()
