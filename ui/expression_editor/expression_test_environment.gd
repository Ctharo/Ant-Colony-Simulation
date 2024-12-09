class_name ExpressionTestEnvironment
extends Control

signal test_entity_changed(entity: Node)

@onready var setup_container: HBoxContainer = $SetupContainer
@onready var spawn_foods_spin: SpinBox = $SetupContainer/SpawnFoodsSpinBox
@onready var spawn_ant_button: Button = $SetupContainer/SpawnAntButton
@onready var clear_button: Button = $SetupContainer/ClearButton
@onready var test_results: TextEdit = %TestResults
@onready var evaluate_button: Button = $TestResultsContainer/EvaluateButton


var current_test_ant: Ant
var current_expression: LogicExpression

func _ready() -> void:
	assert(setup_container)
	assert(spawn_foods_spin)
	assert(spawn_ant_button)
	assert(clear_button)
	assert(test_results)
	assert(evaluate_button)



	_setup_signals()

func _setup_signals() -> void:
	spawn_ant_button.pressed.connect(_spawn_test_ant)
	clear_button.pressed.connect(_clear_test_environment)
	evaluate_button.pressed.connect(_evaluate_current_expression)
	spawn_foods_spin.value_changed.connect(_spawn_test_foods)

func set_expression(expression: LogicExpression) -> void:
	current_expression = expression
	if current_test_ant and current_expression:
		current_expression.initialize(current_test_ant)
		_evaluate_current_expression()

func _spawn_test_ant() -> void:
	_clear_test_environment()
	
	var colony := ColonyManager.spawn_colony()
	current_test_ant = AntManager.spawn_ant()
	colony.add_ant(current_test_ant)
	
	# Place ant and colony randomly
	colony.global_position = _get_random_position()
	current_test_ant.global_position = _get_random_position()
	
	# Setup navigation and properties	
	test_entity_changed.emit(current_test_ant)
	
	if current_expression:
		current_expression.initialize(current_test_ant)
		_evaluate_current_expression()

func _spawn_test_foods(amount: int) -> void:
	FoodManager.spawn_foods(amount)
	for food in Foods.all():
		food.global_position = _get_random_position()
	
	if current_expression:
		_evaluate_current_expression()

func _clear_test_environment() -> void:
	if current_test_ant:
		current_test_ant.queue_free()
		current_test_ant = null
	
	for food in Foods.all():
		food.queue_free()
	
	test_results.text = ""
	test_entity_changed.emit(null)

func _evaluate_current_expression() -> void:
	if not current_expression or not current_test_ant:
		test_results.text = "No expression or test ant available"
		return
	
	var result = current_expression.evaluate()
	var result_text = "Expression Evaluation Results:\n"
	result_text += "Type: %s\n" % current_expression.get_class()
	result_text += "Name: %s\n" % current_expression.name
	result_text += "Result: %s\n" % str(result)
	
	# Add type-specific debug info
	match current_expression.get_class():
		"PropertyExpression":
			result_text += "\nProperty Path: %s" % current_expression.property_path
		"ListMapExpression", "ListFilterExpression":
			if current_expression.array_expression:
				var source_result = current_expression.array_expression.evaluate()
				result_text += "\nSource List Size: %d" % (source_result.size() if source_result else 0)
		"DistanceExpression":
			if current_expression.position1_expression and current_expression.position2_expression:
				var pos1 = current_expression.position1_expression.evaluate()
				var pos2 = current_expression.position2_expression.evaluate()
				result_text += "\nPosition 1: %s" % str(pos1)
				result_text += "\nPosition 2: %s" % str(pos2)
	
	test_results.text = result_text

func _get_random_position() -> Vector2:
	var viewport_rect := get_viewport_rect()
	var x := randf_range(0, viewport_rect.size.x)
	var y := randf_range(0, viewport_rect.size.y)
	return Vector2(x, y)
