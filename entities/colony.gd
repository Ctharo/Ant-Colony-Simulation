class_name Colony
extends Node2D
## The ant colony node that manages colony-wide properties and resources

#region Member Variables
## Colony radius in units
var radius: float = 10.0
## Collection of food resources
var foods: Foods
## Ants belonging to this colony
var ants: Ants = Ants.new([])

#endregion


var logger: Logger

#region Initialization
func _init() -> void:
	logger = Logger.new("colony", DebugLogger.Category.ENTITY)

func add_ant(ant: Ant) -> Result:
	if not ant:
		return Result.new(Result.ErrorType.INVALID_ARGUMENT, "Invalid ant")

	ants.append(ant)
	ant.set_colony(self)
	return Result.new()

func spawn_ants(num: int, physics_at_spawn: bool = false) -> Array[Ant]:
	var _ants: Array[Ant] = AntManager.spawn_ants(num, physics_at_spawn)
	for ant in _ants:
		randomize()
		add_ant(ant)
		ant.global_rotation = randf_range(-PI, PI)
		var wiggle_x: float = randf_range(-15,15)
		var wiggle_y: float = randf_range(-15,15)

		ant.global_position = global_position + Vector2(wiggle_x, wiggle_y)
	return _ants
#endregion
