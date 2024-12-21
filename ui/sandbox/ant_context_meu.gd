# Ant Context Menu
class_name AntContextMenu
extends BaseContextMenu

signal show_info_requested(ant: Ant)
signal destroy_ant_requested(ant: Ant)


func _init() -> void:
	var info = add_button("Info", preload("res://ui/styles/info_normal.tres"), preload("res://ui/styles/info_hover.tres"))
	var destroy = add_button("Destroy", preload("res://ui/styles/destroy_normal.tres"), preload("res://ui/styles/destroy_hover.tres"))
	
	info.pressed.connect(_on_info_pressed)
	destroy.pressed.connect(_on_destroy_pressed)

func show_for_ant(pos: Vector2, p_ant: Ant) -> void:
	tracked_ant = p_ant
	show_at(pos, 12.0)  # Use default ant selection radius
	
func _on_info_pressed() -> void:
	emit_signal("show_info_requested", tracked_ant)
	close()

func _on_destroy_pressed() -> void:
	emit_signal("destroy_ant_requested", tracked_ant)
	close()

# Empty Space Context Menu
