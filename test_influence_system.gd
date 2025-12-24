extends Node

# Simple test script to verify influence system fixes
func _ready():
	print("Testing influence system fixes...")
	
	# Enable debug logging
	DebugLogger.set_log_level(DebugLogger.LogLevel.TRACE)
	DebugLogger.set_category_enabled(DebugLogger.Category.INFLUENCE, true)
	DebugLogger.set_category_enabled(DebugLogger.Category.ENTITY, true)
	
	# Test influence profile loading
	test_influence_profiles()
	
	# Test expression evaluation
	test_expressions()
	
	print("Test completed!")

func test_influence_profiles():
	print("\n=== Testing Influence Profiles ===")
	
	# Test loading profiles
	var look_for_food = load("res://resources/influences/profiles/look_for_food.tres")
	var go_home = load("res://resources/influences/profiles/go_home.tres")
	var default_profile = load("res://resources/influences/profiles/default.tres")
	
	print("Look for food profile: ", look_for_food.name)
	print("  Enter conditions: ", look_for_food.enter_conditions.size())
	print("  Influences: ", look_for_food.influences.size())
	
	print("Go home profile: ", go_home.name)
	print("  Enter conditions: ", go_home.enter_conditions.size())
	print("  Influences: ", go_home.influences.size())
	
	print("Default profile: ", default_profile.name)
	print("  Enter conditions: ", default_profile.enter_conditions.size())
	print("  Influences: ", default_profile.influences.size())

func test_expressions():
	print("\n=== Testing Expressions ===")
	
	# Test forward influence
	var forward_influence = load("res://resources/influences/forward_influence.tres")
	print("Forward influence: ", forward_influence.name)
	print("  Expression: ", forward_influence.expression_string)
	print("  Type: ", forward_influence.type)
	
	# Test random influence
	var random_influence = load("res://resources/influences/random_influence.tres")
	print("Random influence: ", random_influence.name)
	print("  Expression: ", random_influence.expression_string)
	print("  Type: ", random_influence.type)
	
	# Test should look for food condition
	var should_look_for_food = load("res://resources/expressions/conditions/should_look_for_food.tres")
	print("Should look for food: ", should_look_for_food.name)
	print("  Expression: ", should_look_for_food.expression_string)
	print("  Nested expressions: ", should_look_for_food.nested_expressions.size())
