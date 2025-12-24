class_name ActionProfileFactory
extends RefCounted

## Create a foraging composite action with appropriate movement profiles
static func create_foraging_behavior() -> CompositeAction:
	var composite = CompositeAction.new()
	composite.name = "Foraging"
	composite.description = "Search for, collect, and return food"
	composite.priority = 60
	composite.composite_type = CompositeAction.CompositeType.SEQUENCE
	
	# Create sub-actions
	var search_action = MoveToAction.new()
	search_action.name = "SearchForFood"
	search_action.description = "Search for food"
	search_action.is_continuous = true
	search_action.priority = 50
	
	var harvest_action = HarvestFoodAction.new()
	harvest_action.name = "HarvestFood"
	harvest_action.description = "Harvest food when found"
	harvest_action.auto_find_nearest = true
	harvest_action.priority = 70
	
	var return_action = MoveToAction.new()
	return_action.name = "ReturnToColony"
	return_action.description = "Return to colony with food"
	return_action.priority = 80
	
	var store_action = StoreFoodAction.new()
	store_action.name = "StoreFood"
	store_action.description = "Store food at colony"
	store_action.priority = 90
	
	# Add child actions to composite
	composite.child_actions = [
		search_action,
		harvest_action,
		return_action,
		store_action
	]
	
	# Load movement profiles
	var explore_profile = load("res://resources/influences/profiles/look_for_food.tres")
	var harvest_profile = load("res://resources/influences/profiles/stay_still.tres") # Assuming this exists
	var return_profile = load("res://resources/influences/profiles/go_home.tres")
	var store_profile = load("res://resources/influences/profiles/stay_still.tres") # Assuming this exists
	
	# Map actions to profiles
	composite.action_movement_profiles = {
		"SearchForFood": explore_profile,
		"HarvestFood": harvest_profile,
		"ReturnToColony": return_profile,
		"StoreFood": store_profile
	}
	
	# Set up conditions
	composite.start_condition = load("res://resources/expressions/conditions/should_look_for_food.tres")
	
	return composite

## Create a fleeing action with appropriate movement profile
static func create_flee_behavior() -> FleeAction:
	var flee_action = FleeAction.new()
	flee_action.name = "Flee"
	flee_action.description = "Flee from danger"
	flee_action.priority = 95
	flee_action.auto_find_nearest = true
	flee_action.safe_distance = 150.0
	flee_action.speed_multiplier = 1.5
	
	# Set movement profile - either create a specific flee profile or use a random one
	flee_action.movement_profile = load("res://resources/influences/random_influence.tres")
	
	# Set condition
	flee_action.start_condition = load("res://resources/expressions/conditions/threat/in_danger.tres")
	
	return flee_action

## Create a resting action with appropriate movement profile
static func create_rest_behavior() -> RestAction:
	var rest_action = RestAction.new()
	rest_action.name = "Rest"
	rest_action.description = "Rest at colony to recover"
	rest_action.priority = 100
	rest_action.rest_until_full = true
	rest_action.only_at_colony = true
	
	# Set movement profile - use stay still or idle profile
	rest_action.movement_profile = load("res://resources/influences/profiles/wait.tres")
	
	# Set condition - should rest and at colony
	rest_action.start_condition = load("res://resources/expressions/conditions/low_energy.tres")
	
	return rest_action
