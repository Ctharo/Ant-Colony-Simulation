class_name AntDecisionMaker
extends Node

## The ant this decision maker is controlling
var ant: Ant

## List of behaviors available to this ant
var behaviors: Array[AntBehavior] = []

## The currently executing behavior
var current_behavior: AntBehavior = null

## Reference to the AntConfigManager
var config_manager: AntConfigManager

## Initialize the AntDecisionMaker with an ant and config manager
func _init(_ant: Ant, _config_manager: AntConfigManager):
	ant = _ant
	config_manager = _config_manager
	behaviors = config_manager.get_all_behaviors()

## Update method to be called each frame
## delta: Time elapsed since the last frame
func update(delta: float) -> void:
	if current_behavior:
		if current_behavior.update(delta):
			# The behavior has completed or failed
			current_behavior.clear_condition_cache()
			current_behavior = null
	
	if not current_behavior:
		for behavior in behaviors:
			if behavior.should_execute():
				current_behavior = behavior
				current_behavior.start(ant)
				break
	
	# Clear condition caches for all behaviors at the end of the update
	for behavior in behaviors:
		behavior.clear_condition_cache()

## Add a new behavior to the decision maker
func add_behavior(behavior: AntBehavior) -> void:
	behaviors.append(behavior)

## Remove a behavior from the decision maker
func remove_behavior(behavior: AntBehavior) -> void:
	behaviors.erase(behavior)

## Refresh behaviors from the config manager
func refresh_behaviors() -> void:
	behaviors = config_manager.get_all_behaviors()
