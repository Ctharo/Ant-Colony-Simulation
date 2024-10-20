class_name Ant
extends Node

signal spawned
signal food_spotted
signal ant_spotted
signal action_completed
signal pheromone_sensed
signal damaged
signal died


## The unique identifier for this ant
var id: int

## The role of this ant in the colony
var role: String

## The current position of the ant
var position: Vector2

## The colony this ant belongs to
var colony: Colony

## The reach capabilities of the ant
var reach: Reach

## The vision capabilities of the ant
var vision: Vision

## The sense capabilities of the ant
var sense: Sense

## The energy levels of the ant
var energy: Energy

## The strength capabilities of the ant
var strength: Strength

## The health status of the ant
var health: Health

## The foods being carried by the ant
var foods: Foods

func _ready() -> void:
	spawned.emit()

## Check if the ant is carrying food
func is_carrying_food() -> bool:
	return not foods.is_empty()

## Check if the ant can carry more food
func can_carry_more() -> bool:
	return foods.mass() < strength.carry_max()

## Get the available carry capacity
func available_carry_mass() -> float:
	return strength.carry_max() - foods.mass()

## Check if the ant is from a friendly colony
func is_friendly(other_colony: Colony) -> bool:
	return other_colony == colony

## Get food items within reach
func food_in_reach() -> Foods:
	return Foods.new(foods.in_range(position, reach.distance))

## Get food items in view
func food_in_view() -> Foods:
	return Foods.new(foods.in_range(position, vision.distance))

## Get pheromones sensed by the ant
func pheromones_sensed(type: String = "") -> Pheromones:
	var all_pheromones = Pheromones.new() # Assume this is populated from the world
	var sensed = all_pheromones.sensed(position, sense.distance)
	return sensed if type.is_empty() else sensed.of_type(type)

## Get ants in view
func ants_in_view() -> Ants:
	var all_ants = Ants.new() # Assume this is populated from the world
	return all_ants.in_range(position, vision.distance)

## Check if the ant is at its home colony
func is_at_home() -> bool:
	return position.distance_to(colony.position) < reach.distance + colony.radius
