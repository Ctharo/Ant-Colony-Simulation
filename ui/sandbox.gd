extends Node2D
var logger: Logger

func _init() -> void:
	logger = Logger.new("sandbox", DebugLogger.Category.PROGRAM)

func _ready() -> void:
	logger.set_logging_level(DebugLogger.LogLevel.DEBUG)
	logger.set_logging_category(DebugLogger.Category.CONTEXT)
	logger.set_logging_category(DebugLogger.Category.TASK)
	logger.set_logging_category(DebugLogger.Category.PROPERTY)
	logger.set_logging_category(DebugLogger.Category.BEHAVIOR)


	spawn_ants(1)
	AntManager.start_ants()
	_staged_creation()

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
	create_tween().tween_callback(Callable(self, "_change_scene").bind(scene_name))

## Change to a new scene
func _change_scene(scene_name: String) -> void:
	var error = get_tree().change_scene_to_file("res://" + "ui" + "/" + scene_name + ".tscn")
	if error != OK:
		DebugLogger.error(DebugLogger.Category.PROGRAM, "Failed to load scene: " + scene_name)

func spawn_ants(num_to_spawn: int = 1) -> void:
	var colony: Colony = ColonyManager.spawn_colony()
	colony.global_position = get_viewport_rect().get_center()
	for i in range(num_to_spawn):
		# Create a new ant
		var ant = AntManager.spawn_ant()
		ant.foods.add_food(ant.get_property_value(Path.parse("storage.capacity.max")))
		colony.add_ant(ant)

## Create components in stages to avoid freezing
func _staged_creation() -> void:
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.016
	timer.connect("timeout", Callable(self, "_create_batch").bind(timer))
	timer.start()

	await get_tree().create_timer(2.5).timeout

func _create_batch(timer: Timer) -> void:
	var params = {
		"food": 1,
		"pheromones": 1,
	}
	while params.food > 0:
		var food = Food.new(randf_range(0.0, 50.0))
		add_child(food)
		params.food -= 1

	while params.pheromones > 0:
		var pheromone = Pheromone.new(
			Vector2.ZERO,
			["food", "home"].pick_random(),
			randf_range(0.0, 100.0),
			Ants.all().as_array().pick_random()
		)
		add_child(pheromone)
		params.pheromones -= 1
