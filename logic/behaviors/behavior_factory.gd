class_name BehaviorFactory
extends RefCounted

## The AntConfigManager used to create behaviors
var config_manager: AntConfigManager

## Initialize the BehaviorFactory with a config manager
## @param _config_manager The AntConfigManager to use for creating behaviors
func _init(_config_manager: AntConfigManager):
	if _config_manager == null:
		push_error("BehaviorFactory: Config manager cannot be null")
		return
	config_manager = _config_manager

## Create a behavior from behavior data
## @param behavior_data Dictionary containing the behavior configuration
## @return The created AntBehavior, or null if creation failed
func create_behavior(behavior_data: Dictionary) -> AntBehavior:
	if behavior_data.is_empty():
		push_error("BehaviorFactory: Behavior data is empty")
		return null
	return config_manager.create_behavior(behavior_data)

## Create all behaviors defined in the configuration
## @return Array of all created AntBehaviors
func create_all_behaviors() -> Array[AntBehavior]:
	var behaviors = config_manager.get_all_behaviors()
	if behaviors.is_empty():
		push_warning("BehaviorFactory: No behaviors were created")
	return behaviors
