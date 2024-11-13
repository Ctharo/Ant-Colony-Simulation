extends Node2D

func _ready() -> void:
	DebugLogger.set_from_enabled("ant")
	DebugLogger.set_category_enabled(DebugLogger.Category.ACTION)
	DebugLogger.set_category_enabled(DebugLogger.Category.TASK)
	DebugLogger.set_category_enabled(DebugLogger.Category.CONDITION)
	DebugLogger.set_category_enabled(DebugLogger.Category.CONTEXT)


	spawn_ants()

## Handle unhandled input events
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

## Close handler
func _on_close_pressed():
	transition_to_scene("main")

## Transition to a new scene
func transition_to_scene(scene_name: String) -> void:
	var tween := create_tween().tween_callback(Callable(self, "_change_scene").bind(scene_name))

## Change to a new scene
func _change_scene(scene_name: String) -> void:
	var error = get_tree().change_scene_to_file("res://" + "ui" + "/" + scene_name + ".tscn")
	if error != OK:
		DebugLogger.error(DebugLogger.Category.PROGRAM, "Failed to load scene: " + scene_name)

func spawn_ants(num_to_spawn: int = 1) -> void:
	var i: int = 0
	var colony: Colony = Colony.new()
	colony.global_position = get_viewport_rect().get_center()

	while i < num_to_spawn:

		# Create a new ant
		var ant = Ant.new()
		ant.colony = colony
		# Add the ant to the scene
		add_child(ant)

		i += 1
