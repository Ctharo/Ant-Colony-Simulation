class_name ActionFactory
extends RefCounted

## Singleton instance
static var _instance: ActionFactory
## Dictionary of condition resources
static var _condition_cache: Dictionary = {}

## Get the singleton instance
static func get_instance() -> ActionFactory:
	if not _instance:
		_instance = ActionFactory.new()
	return _instance

## Create a move action
static func create_move_action(name: String = "Move", target: Vector2 = Vector2.ZERO, priority: int = 50) -> MoveToAction:
	var action = MoveToAction.new()
	action.name = name
	action.target_position = target
	action.priority = priority
	return action

## Create a move to colony action
static func create_move_to_colony_action(priority: int = 80) -> MoveToAction:
	var action = MoveToAction.new()
	action.name = "Return To Colony"
	action.description = "Return to the colony"
	action.priority = priority
	action.use_navigation = true
	
	# Set condition (should return home)
	action.start_condition = _get_condition("should_return_home")
	
	return action

## Create a harvest food action
static func create_harvest_food_action(priority: int = 90) -> HarvestFoodAction:
	var action = HarvestFoodAction.new()
	action.name = "Harvest Food"
	action.description = "Pick up food when found"
	action.priority = priority
	action.auto_find_nearest = true
	
	# Set condition (can see food & not carrying food)
	var can_see_food = _get_condition("can_see_food")
	var not_carrying = _get_condition("not_carrying_food")
	
	if can_see_food and not_carrying:
		# Ideally we'd create a composite condition here
		action.start_condition = can_see_food
	
	return action

## Create a store food action
static func create_store_food_action(priority: int = 95) -> StoreFoodAction:
	var action = StoreFoodAction.new()
	action.name = "Store Food"
	action.description = "Store food at the colony"
	action.priority = priority
	
	# Set condition (carrying food & at colony)
	var carrying_food = _get_condition("is_carrying_food")
	var in_colony = _get_condition("is_in_colony")
	
	if carrying_food and in_colony:
		# Ideally we'd create a composite condition here
		action.start_condition = carrying_food
	
	return action

## Create a rest action
static func create_rest_action(priority: int = 100) -> RestAction:
	var action = RestAction.new()
	action.name = "Rest"
	action.description = "Rest to recover energy and health"
	action.priority = priority
	action.rest_until_full = true
	action.only_at_colony = true
	
	# Set condition (should rest & at colony)
	var low_energy = _get_condition("low_energy")
	var in_colony = _get_condition("is_in_colony")
	
	if low_energy and in_colony:
		# Ideally we'd create a composite condition here
		action.start_condition = low_energy
	
	return action

## Create a flee action
static func create_flee_action(priority: int = 99) -> FleeAction:
	var action = FleeAction.new()
	action.name = "Flee"
	action.description = "Flee from danger"
	action.priority = priority
	action.auto_find_nearest = true
	
	# Set condition (in danger)
	action.start_condition = _get_condition("in_danger")
	
	return action

## Create a patrol action
static func create_patrol_action(priority: int = 40) -> PatrolAction:
	var action = PatrolAction.new()
	action.name = "Patrol"
	action.description = "Patrol around the area"
	action.priority = priority
	action.use_random_waypoints = true
	action.relative_to_colony = true
	
	return action

## Create a forage composite action
static func create_forage_composite() -> CompositeAction:
	var composite = CompositeAction.new()
	composite.name = "Forage"
	composite.description = "Search for and collect food"
	composite.priority = 60
	composite.composite_type = CompositeAction.CompositeType.SEQUENCE
	
	# Create child actions
	var move_action = create_move_action("Search For Food")
	move_action.is_continuous = true
	
	var harvest_action = create_harvest_food_action()
	
	# Add child actions
	composite.child_actions = [move_action, harvest_action]
	
	# Set condition (should look for food)
	composite.start_condition = _get_condition("should_look_for_food")
	
	return composite

## Create a return home composite action
static func create_return_home_composite() -> CompositeAction:
	var composite = CompositeAction.new()
	composite.name = "Return With Food"
	composite.description = "Return to colony and store food"
	composite.priority = 70
	composite.composite_type = CompositeAction.CompositeType.SEQUENCE
	
	# Create child actions
	var move_action = create_move_to_colony_action()
	var store_action = create_store_food_action()
	
	# Add child actions
	composite.child_actions = [move_action, store_action]
	
	# Set condition (should return home)
	composite.start_condition = _get_condition("should_return_home")
	
	return composite

## Get a condition by name
static func _get_condition(condition_name: String) -> Logic:
	if _condition_cache.has(condition_name):
		return _condition_cache[condition_name]
	
	var path = ""
	match condition_name:
		"should_look_for_food":
			path = "res://resources/expressions/conditions/should_look_for_food.tres"
		"should_return_home":
			path = "res://resources/expressions/conditions/should_return home.tres"
		"can_see_food":
			path = "res://resources/expressions/conditions/can_see_food.tres"
		"is_carrying_food":
			path = "res://resources/expressions/conditions/is_carrying_food.tres"
		"not_carrying_food":
			# This would need to be created or inverted from is_carrying_food
			path = "res://resources/expressions/conditions/is_carrying_food.tres"
		"is_in_colony":
			path = "res://resources/expressions/conditions/is_in_colony.tres"
		"low_energy":
			path = "res://resources/expressions/conditions/low_energy.tres"
		"in_danger":
			path = "res://resources/expressions/conditions/threat/in_danger.tres"
			
	if not path.is_empty():
		var condition = load(path)
		_condition_cache[condition_name] = condition
		return condition
	
	return null

## Create a scout ant action profile
static func create_scout_profile() -> AntActionProfile:
	var profile = AntActionProfile.new()
	profile.name = "Scout"
	profile.priority = 5
	
	# Create actions for the scout
	profile.actions = [
		create_patrol_action(60),     # Higher priority for patrolling
		create_flee_action(),         # Flee from danger 
		create_move_to_colony_action(70),  # Return to colony when needed
		create_rest_action()          # Rest at colony
	]
	
	return profile

## Create a forager ant action profile
static func create_forager_profile() -> AntActionProfile:
	var profile = AntActionProfile.new()
	profile.name = "Forager"
	profile.priority = 10
	
	# Create actions for the forager
	profile.actions = [
		create_forage_composite(),      # Forage for food
		create_return_home_composite(), # Return home with food
		create_flee_action(),           # Flee from danger
		create_rest_action()            # Rest at colony
	]
	
	return profile

## Create a guard ant action profile
static func create_guard_profile() -> AntActionProfile:
	var profile = AntActionProfile.new()
	profile.name = "Guard"
	profile.priority = 15
	
	# Create a patrol with specific waypoints around colony
	var patrol = PatrolAction.new()
	patrol.name = "Guard Colony"
	patrol.description = "Guard the colony perimeter"
	patrol.priority = 80
	patrol.relative_to_colony = true
	patrol.loop_patrol = true
	
	# Set up waypoints in a circle around colony
	var waypoints: Array[Vector2] = []
	var radius = 80.0  # colony radius + guard distance
	var steps = 8
	
	for i in range(steps):
		var angle = i * TAU / steps
		waypoints.append(Vector2(cos(angle), sin(angle)) * radius)
	
	patrol.waypoints = waypoints
	
	# Create actions for the guard
	profile.actions = [
		patrol,              # Patrol around colony
		create_flee_action(85),  # Flee, but lower priority than patrolling
		create_rest_action()     # Rest at colony
	]
	
	return profile
