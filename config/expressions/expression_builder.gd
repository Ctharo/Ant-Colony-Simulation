## Helper class to build common expressions
class_name ExpressionBuilder
extends Node

var cache_manager: ExpressionCache

func _init() -> void:
	cache_manager = ExpressionCache.new()

## Create the "is food visible" condition
func create_is_food_visible_condition(entity: Node) -> Condition:
	# Get base properties
	var vision_range = preload("res://resources/properties/vision_range.tres").duplicate()
	vision_range.initialize(entity, cache_manager)
	print("Vision Range: ", vision_range.evaluate())

	var ant_position = preload("res://resources/properties/ant_position.tres").duplicate()
	ant_position.initialize(entity, cache_manager)
	print("Ant Position: ", ant_position.evaluate())

	var food_position = preload("res://resources/properties/food_position.tres").duplicate()
	food_position.initialize(entity, cache_manager)
	food_position.use_current_item = true  # Use current food item
	print("Food Position: ", food_position.evaluate())

	var food_list = preload("res://resources/properties/all_food_list.tres").duplicate()
	food_list.initialize(entity, cache_manager)
	print("Food List Size: ", food_list.evaluate().size())

	# Create distance calculator for food items
	var food_distance = DistanceExpression.new()
	food_distance.initialize(entity, cache_manager)
	food_distance.id = "food_distance"
	food_distance.name = "Distance to Food"
	food_distance.position1_expression = ant_position
	food_distance.position2_expression = food_position
	print("Food Distance: ", food_distance.evaluate())

	# Filter foods by distance
	var visible_food = preload("res://resources/properties/visible_food.tres")
	visible_food.initialize(entity, cache_manager)
	print("Visible Food Count: ", visible_food.evaluate().size())

	# Check if any food is visible
	var has_visible_food = preload("res://resources/properties/has_visible_food.tres")
	has_visible_food.initialize(entity, cache_manager)
	print("Has Visible Food: ", has_visible_food.evaluate())

	# Create final condition
	var condition = Condition.new()
	condition.id = "is_food_visible"
	condition.name = "Is Food Visible"
	condition.description = "True if there are any food items within vision range"
	condition.logic_expression = has_visible_food
	return condition
