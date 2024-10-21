class_name BehaviorFactory
extends RefCounted

## The AntConfigManager used to create behaviors
var config_manager: AntConfigManager

## Initialize the BehaviorFactory with a config manager
func _init(_config_manager: AntConfigManager):
	config_manager = _config_manager

## Create a behavior from behavior data
func create_behavior(behavior_data: Dictionary) -> AntBehavior:
	return config_manager.create_behavior(behavior_data)

## Create all behaviors defined in the configuration
func create_all_behaviors() -> Array[AntBehavior]:
	return config_manager.get_all_behaviors()
