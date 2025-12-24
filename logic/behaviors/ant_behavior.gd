class_name AntBehavior
extends Resource

@export var name: String
## Conditions that activate this behavior
@export var activation_conditions: Array[Logic]
## Priority of this behavior (higher = more important)
@export var priority: int = 0
## Movement profile to use while behavior is active
@export var movement_profile: InfluenceProfile
## Pheromones to emit while behavior is active
@export var active_pheromones: Array[Pheromone]
## Actions that can be taken during this behavior
@export var available_actions: Array[AntAction]

var is_active: bool = false
var ant: Ant
var logger: iLogger

func _init() -> void:
	logger = iLogger.new("ant_behavior", DebugLogger.Category.ENTITY)

func initialize(p_ant: Ant) -> void:
	ant = p_ant

	# Initialize all actions with this ant
	for action in available_actions:
		action.initialize(ant)

## Check if this behavior should be active based on conditions
func should_be_active() -> bool:
	if activation_conditions.is_empty():
		return false

	# All conditions must be true to activate
	for condition in activation_conditions:
		if not condition.get_value(ant):
			return false

	return true

## Activate this behavior
func activate() -> void:
	if is_active:
		return

	is_active = true
	logger.debug("Activating behavior: " + name)

	# Set movement profile
	if is_instance_valid(movement_profile) and is_instance_valid(ant.influence_manager):
		ant.influence_manager.active_profile = movement_profile

	# Set available actions (but don't force any to start)
	if is_instance_valid(ant.action_manager):
		ant.action_manager.clear_actions()
		for action in available_actions:
			ant.action_manager.add_action(action)

	# Activate pheromones
	for pheromone in active_pheromones:
		if not pheromone in ant.pheromones:
			ant.pheromones.append(pheromone)

## Deactivate this behavior
func deactivate() -> void:
	if not is_active:
		return

	logger.debug("Deactivating behavior: " + name)
	is_active = false

	# No need to clear actions - the next behavior will set its own

	# Remove behavior-specific pheromones
	for pheromone in active_pheromones:
		if pheromone in ant.pheromones:
			ant.pheromones.erase(pheromone)
