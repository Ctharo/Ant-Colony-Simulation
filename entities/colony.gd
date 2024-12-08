class_name Colony
extends Node2D
## The ant colony node that manages colony-wide properties and resources

#region Member Variables
var id: int
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
#endregion
