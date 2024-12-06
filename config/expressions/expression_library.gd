class_name ExpressionLibrary
extends Resource

## Dictionary of stored expressions
@export var expressions: Dictionary = {}

## Add expression to library
func add_expression(expression: BaseExpression) -> void:
	expressions[expression.id] = expression

## Get expression by id
func get_expression(id: String) -> BaseExpression:
	return expressions.get(id)

## Example usage
func example_setup() -> void:
	# Create base property list expression
	var food_list = PropertyListExpression.new()
	food_list.id = "vision_food_list"
	food_list.name = "Food Items in Vision"
	food_list.description = "List of all food items currently visible"
	food_list.source_property = "vision.food.items"
	
	# Create named reference to food list
	var named_food_list = NamedListExpression.new()
	named_food_list.id = "visible_food"
	named_food_list.name = "Visible Food"
	named_food_list.description = "Reference to visible food items"
	named_food_list.source_expression = food_list
	
	# Create count of visible food
	var food_count = CountExpression.new()
	food_count.id = "food_count"
	food_count.name = "Food Count"
	food_count.description = "Number of visible food items"
	food_count.list_expression = named_food_list
	
	# Create filtered list of nearby food
	var nearby_food = FilterExpression.new()
	nearby_food.id = "nearby_food"
	nearby_food.name = "Nearby Food"
	nearby_food.description = "Food items within range"
	nearby_food.list_expression = named_food_list
	nearby_food.filter_property = "distance"
	nearby_food.operator = FilterExpression.Operator.LESS
	nearby_food.compare_value = 100.0
	
	# Create sorted list by distance
	var sorted_food = DistanceSortExpression.new()
	sorted_food.id = "sorted_food"
	sorted_food.name = "Food Sorted by Distance"
	sorted_food.description = "Food items sorted by distance"
	sorted_food.list_expression = nearby_food
	sorted_food.position_property = "proprioception.base.position"
	
	# Add to library
	var library = ExpressionLibrary.new()
	library.add_expression(food_list)
	library.add_expression(named_food_list)
	library.add_expression(food_count)
	library.add_expression(nearby_food)
	library.add_expression(sorted_food)
