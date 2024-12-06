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

	var food_list = preload("res://resources/properties/all_food_list.tres").duplicate()
	food_list.initialize(entity, cache_manager)
	print("Food List Size: ", food_list.evaluate().size())

	var food_position = preload("res://resources/properties/food_position.tres").duplicate()
	food_position.initialize(entity, cache_manager)

	# Map positions to food items
	var food_positions = preload("res://resources/properties/food_positions.tres").duplicate()
	food_positions.initialize(entity, cache_manager)
	print("Food Positions: ", food_positions.evaluate())

	var food_distance = preload("res://resources/properties/food_distance.tres").duplicate()
	food_distance.initialize(entity, cache_manager)

	# Create distance calculator
	var food_distances = preload("res://resources/properties/food_distances.tres").duplicate()
	food_distances.initialize(entity, cache_manager)
	print("Food Distances: ", food_distances.evaluate())

	# Filter foods by distance
	var visible_food = preload("res://resources/properties/visible_food.tres").duplicate()
	visible_food.initialize(entity, cache_manager)
	print("Visible Food Count: ", visible_food.evaluate().size())

	# Check if any food is visible
	var has_visible_food = preload("res://resources/properties/has_visible_food.tres").duplicate()
	has_visible_food.initialize(entity, cache_manager)
	print("Has Visible Food: ", has_visible_food.evaluate())

	# Create final condition
	var condition = Condition.new()
	condition.id = "is_food_visible"
	condition.name = "Is Food Visible"
	condition.description = "True if there are any food items within vision range"
	condition.logic_expression = has_visible_food
	return condition
