## Helper class to build common expressions
class_name ExpressionBuilder
extends Node

var cache_manager: ExpressionCache

func _init() -> void:
	cache_manager = ExpressionCache.new()

## Create the "is food visible" condition
func create_is_food_visible_condition(entity: Node) -> Condition:
	# Get base properties
	var vision_range = PropertyExpression.new()
	vision_range.initialize(entity, cache_manager)
	vision_range.id = "vision_range"
	vision_range.name = "Vision Range"
	vision_range.property_path = "vision.base.range"
	vision_range.use_current_item = false  # Use root entity

	var ant_position = PropertyExpression.new()
	ant_position.initialize(entity, cache_manager)
	ant_position.id = "ant_position"
	ant_position.name = "Ant Position"
	ant_position.property_path = "proprioception.base.position"
	ant_position.use_current_item = false  # Use root entity

	var food_position = PropertyExpression.new()
	food_position.initialize(entity, cache_manager)
	food_position.id = "food_position"
	food_position.name = "Food Position"
	food_position.property_path = "global_position"
	food_position.use_current_item = true  # Use current food item

	var food_list = PropertyExpression.new()
	food_list.initialize(entity, cache_manager)
	food_list.id = "all_food_list"
	food_list.name = "Global Food List"
	food_list.property_path = "world.food.list"
	food_list.use_current_item = false  # Use root entity

	# Create distance calculator for food items
	var food_distance = DistanceExpression.new()
	food_distance.initialize(entity, cache_manager)
	food_distance.id = "food_distance"
	food_distance.name = "Distance to Food"
	food_distance.position1_expression = ant_position
	food_distance.position2_expression = food_position

	# Filter foods by distance
	var visible_food = ListFilterExpression.new()
	visible_food.initialize(entity, cache_manager)
	visible_food.id = "visible_food"
	visible_food.name = "Visible Food Items"
	visible_food.array_expression = food_list
	visible_food.predicate_expression = food_distance
	visible_food.operator = 1  # LESS_EQUAL
	visible_food.compare_value = vision_range

	# Check if any food is visible
	var has_visible_food = ListHasItemsExpression.new()
	has_visible_food.initialize(entity, cache_manager)
	has_visible_food.id = "has_visible_food"
	has_visible_food.name = "Has Visible Food"
	has_visible_food.list_expression = visible_food

	# Create final condition
	var condition = Condition.new()
	condition.id = "is_food_visible"
	condition.name = "Is Food Visible"
	condition.description = "True if there are any food items within vision range"
	condition.logic_expression = has_visible_food

	return condition
