class_name Ant
extends Node2D

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

## The speed capabilities of the ant
var speed: Speed

## The behavior tree for this ant
var behavior_tree: BehaviorTree

## The navigation agent for this ant
var nav_agent: NavigationAgent2D

func _init():
	
	reach = Reach.new()
	vision = Vision.new()
	sense = Sense.new()
	energy = Energy.new()
	strength = Strength.new()
	health = Health.new()
	foods = Foods.new()
	speed = Speed.new()
	
	behavior_tree = BehaviorTree.Builder.new(self).build()


func _ready() -> void:
	spawned.emit()

func _process(delta: float) -> void:
	behavior_tree.update(delta)

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
	return Foods.in_reach(position, reach.distance)

## Get food items in view
func food_in_view() -> Foods:
	return Foods.in_view(position, vision.distance)

## Return true if food is in view
func is_food_in_view() -> bool:
	return not food_in_view().is_empty()

## Get pheromones sensed by the ant
func pheromones_sensed(type: String = "") -> Pheromones:
	var all_pheromones = Pheromones.new() # Assume this is populated from the world
	var sensed = all_pheromones.sensed(position, sense.distance)
	return sensed if type.is_empty() else sensed.of_type(type)

## Returns true if pheromones are sensed.
##@unoptimized
func is_pheromone_sensed(type: String = "") -> bool:
	var all_pheromones = Pheromones.new() # Assume this is populated from the world
	var sensed = all_pheromones.sensed(position, sense.distance)
	return !sensed.is_empty() if type.is_empty() else !sensed.of_type(type).is_empty()

## Get ants in view
func ants_in_view() -> Ants:
	return Ants.in_view(position, vision.distance)

## Check if the ant is at its home colony
func is_at_home() -> bool:
	return position.distance_to(colony.position) < reach.distance + colony.radius

## Handle the ant taking damage
func take_damage(amount: float) -> void:
	health.current_level -= amount
	damaged.emit()
	if health.current_level <= 0:
		died.emit()

## Handle the ant consuming food for energy
func consume_food(amount: float) -> void:
	var consumed = foods.consume(amount)
	energy.current_level += consumed

## Move the ant to a new position
func move(direction: Vector2, delta: float) -> void:
	var vector = direction * speed.movement_rate * delta 
	move_to(vector)

func move_to(location: Vector2) -> void:
	nav_agent.target_position = global_position + location

## Harvest food from a source over a given time period
func harvest_food(food_source: Food, time: float) -> float:
	var potential_harvest = speed.harvesting_rate * time
	var harvested_amount = min(food_source.amount, potential_harvest)
	harvested_amount = min(harvested_amount, available_carry_mass())
	
	food_source.amount -= harvested_amount
	foods.add(Food.new(harvested_amount))
		
	return harvested_amount

## Store food into colony over a given time period[br]
##Returns amount stored[br]
##** Note, not currently using argument _time **
func store_food(colony: Colony, _time: float) -> float:
	var storing_amount: float = foods.mass()
	var total_stored = colony.foods.add_food(storing_amount)
	print("Stored %.2f food -> colony total: %.2f food stored" % [storing_amount, total_stored])
	foods.clear()
	return storing_amount

## Emit a pheromone at the current position
func emit_pheromone(type: String, concentration: float) -> void:
	print("Emitting pheromone")
	#var new_pheromone = Pheromone.new(position, type, concentration, self)
	# Add the pheromone to the world (implementation depends on your world management system)

## Perform an action (placeholder for more complex behavior)
func perform_action() -> void:
	# Implement ant behavior here
	action_completed.emit()

# Connect signals
func _connect_signals() -> void:
	health.depleted.connect(func(): died.emit())
	energy.depleted.connect(func(): take_damage(1))  # Ant takes damage when out of energy
