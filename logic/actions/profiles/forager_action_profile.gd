class_name ForagerActionProfile
extends AntActionProfile

## Factory method to create a standard forager profile
static func create_standard() -> ForagerActionProfile:
	var profile = ForagerActionProfile.new()
	profile.name = "Forager"
	profile.priority = 10

	# Search for food condition logic
	var search_condition = load("res://resources/expressions/conditions/should_look_for_food.tres")

	# Return to colony condition logic
	var return_condition = load("res://resources/expressions/conditions/should_return home.tres")

	# Create foraging actions
	profile.actions = [
		# Search for food actions
		_create_find_food_action(search_condition),
		_create_harvest_food_action(),

		# Return to colony actions
		_create_return_to_colony_action(return_condition),
		_create_store_food_action(),

		# Rest action
		_create_rest_action()
	] as Array[AntAction]

	return profile

## Create an action to find food
static func _create_find_food_action(condition: Logic) -> MoveToAction:
	var action = MoveToAction.new()
	action.name = "Find Food"
	action.description = "Move around looking for food"
	action.start_condition = condition
	action.is_continuous = true
	action.priority = 80

	return action

## Create an action to harvest food when found
static func _create_harvest_food_action() -> HarvestFoodAction:
	var action = HarvestFoodAction.new()
	action.name = "Harvest Food"
	action.description = "Pick up food when in reach"
	action.auto_find_nearest = true
	action.harvest_time = 1.0
	action.priority = 90

	return action

## Create an action to return to colony
static func _create_return_to_colony_action(condition: Logic) -> MoveToAction:
	var action = MoveToAction.new()
	action.name = "Return To Colony"
	action.description = "Return to colony with food"
	action.start_condition = condition
	action.priority = 85

	# Target will be set dynamically when action starts
	# Ant must implement on_target_position_requested signal/callback

	return action

## Create an action to store food at colony
static func _create_store_food_action() -> StoreFoodAction:
	var action = StoreFoodAction.new()
	action.name = "Store Food"
	action.description = "Deposit food at colony"
	action.store_time = 1.0
	action.priority = 95

	return action

## Create a rest action
static func _create_rest_action() -> RestAction:
	var action = RestAction.new()
	action.name = "Rest"
	action.description = "Rest to recover energy and health"
	action.rest_until_full = true
	action.only_at_colony = true
	action.priority = 100  # Highest priority when applicable

	return action
