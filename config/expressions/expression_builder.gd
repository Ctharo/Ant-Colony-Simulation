class_name ExpressionBuilder
extends Node

func create_is_food_visible_condition() -> Condition:
	# Get base properties
	var vision_range = PropertyExpression.new()
	vision_range.id = "vision_range"
	vision_range.name = "Vision Range"
	vision_range.property_path = "properties.vision_range"
	
	var ant_position = PropertyExpression.new()
	ant_position.id = "ant_position"
	ant_position.name = "Ant Position"
	ant_position.property_path = "proprioception.base.position"
	
	var food_list = PropertyExpression.new()
	food_list.id = "food_list"
	food_list.name = "Global Food List"
	food_list.property_path = "world.food_items"
	
	# Create distance calculator for food items
	var food_distance = DistanceExpression.new()
	food_distance.id = "food_distance"
	food_distance.name = "Distance to Food"
	food_distance.position1_expression = ant_position
	# position2_expression will be set dynamically to each food item
	
	# Filter foods by distance
	var visible_food = ArrayFilterExpression.new()
	visible_food.id = "visible_food"
	visible_food.name = "Visible Food Items"
	visible_food.array_expression = food_list
	visible_food.predicate_expression = food_distance
	
	# Count visible food
	var food_count = ArrayCountExpression.new()
	food_count.id = "food_count"
	food_count.name = "Visible Food Count"
	food_count.array_expression = visible_food
	
	# Create final condition
	var is_food_visible = Condition.new()
	is_food_visible.id = "is_food_visible"
	is_food_visible.name = "Is Food Visible"
	is_food_visible.description = "True if there are any food items within vision range"
	is_food_visible.logic_expression = food_count
	
	return is_food_visible
