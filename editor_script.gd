## Tool script to generate ant configuration resources
@tool
extends EditorScript

func _run() -> void:
	# Create behavior configurations
	var behavior_configs = BehaviorConfigList.new()
	
	# MoveToFood behavior
	var move_to_food_action = ActionConfig.new()
	move_to_food_action.base_action = "Move"
	move_to_food_action.params = { "target_type": "food" }
	
	var move_to_food = BehaviorConfig.new()
	move_to_food.action = move_to_food_action
	move_to_food.priority = "HIGH"
	
	behavior_configs.behaviors["MoveToFood"] = move_to_food
	
	# MoveToHome behavior
	var move_to_home_action = ActionConfig.new()
	move_to_home_action.base_action = "Move"
	move_to_home_action.params = { "target_type": "colony" }
	
	var move_to_home = BehaviorConfig.new()
	move_to_home.action = move_to_home_action
	move_to_home.priority = "HIGHEST"
	
	behavior_configs.behaviors["MoveToHome"] = move_to_home
	
	# HarvestFood behavior
	var harvest_action = ActionConfig.new()
	harvest_action.base_action = "Harvest"
	harvest_action.params = { "harvest_rate": 1 }
	
	var harvest_food = BehaviorConfig.new()
	harvest_food.action = harvest_action
	harvest_food.priority = "HIGHEST"
	
	behavior_configs.behaviors["HarvestFood"] = harvest_food
	
	# Save behavior configs
	var err = ResourceSaver.save(behavior_configs, "res://resources/ant_behaviors.tres")
	if err != OK:
		push_error("Failed to save behavior configs")
	
	# Create task configurations
	var task_configs = TaskConfigList.new()
	
	# CollectFood task
	var collect_food = TaskConfig.new()
	collect_food.priority = "MEDIUM"
	collect_food.conditions = [
		{
			"type": "Operator",
			"operator_type": "not",
			"operands": [
				{
					"type": "Custom",
					"name": "LowEnergy"
				}
			]
		}
	]
	collect_food.behaviors = [
		{
			"name": "WanderForFood",
			"priority": "LOWEST"
		},
		{
			"name": "MoveToFood",
			"priority": "HIGH",
			"conditions": [
				{
					"type": "Custom",
					"name": "IsFoodInView"
				}
			]
		},
		{
			"name": "HarvestFood",
			"priority": "HIGHEST",
			"conditions": [
				{
					"type": "Custom",
					"name": "IsFoodInReach"
				}
			]
		}
	]
	
	task_configs.tasks["CollectFood"] = collect_food
	
	# Save task configs
	err = ResourceSaver.save(task_configs, "res://resources/ant_tasks.tres")
	if err != OK:
		push_error("Failed to save task configs")
	
	# Create condition configurations
	var condition_configs = ConditionConfigList.new()
	
	# LowEnergy condition
	var low_energy = ConditionConfig.new()
	low_energy.type = "Custom"
	low_energy.evaluation = {
		"property": "energy",
		"operator": "LESS_THAN",
		"value": 0.3
	}
	
	condition_configs.conditions["LowEnergy"] = low_energy
	
	# IsFoodInView condition
	var food_in_view = ConditionConfig.new()
	food_in_view.type = "Custom"
	food_in_view.evaluation = {
		"property": "food_in_view",
		"operator": "EQUALS",
		"value": true
	}
	
	condition_configs.conditions["IsFoodInView"] = food_in_view
	
	# Save condition configs
	err = ResourceSaver.save(condition_configs, "res://resources/ant_conditions.tres")
	if err != OK:
		push_error("Failed to save condition configs")
