## Defines the properties available for each object type in the behavior editor
class_name ObjectDefinitions

## Food object properties
class Food:
	var amount: float
	var position: Vector2

## Pheromone object properties
class Pheromone:
	var type: String
	var strength: float
	var position: Vector2

## Home object properties
class Home:
	var position: Vector2
	var food_stored: float

## Ant object properties
class Ant:
	var position: Vector2
	var carrying_food: bool
	var health: float
	var energy: float

## Self (current ant) object properties
class Self:
	var position: Vector2
	var carrying_food: bool
	var health: float
	var energy: float
	var sight_range: float
	var pheromone_sense_range: float
	var speed: float
	var strength: float

## Colony object properties
class Colony:
	var position: Vector2
	var food_stored: float
	var ant_count: int
	var queen_health: float

## Static method to get all object types
static func get_object_types() -> Array:
	return ["food", "pheromone", "home", "ant", "self", "colony"]

## Static method to get properties for a given object type
static func get_properties_for_type(object_type: String) -> Array:
	match object_type:
		"food":
			return Food.new().get_property_list()
		"pheromone":
			return Pheromone.new().get_property_list()
		"home":
			return Home.new().get_property_list()
		"ant":
			return Ant.new().get_property_list()
		"self":
			return Self.new().get_property_list()
		"colony":
			return Colony.new().get_property_list()
		_:
			return []
