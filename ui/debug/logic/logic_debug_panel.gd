class_name LogicDebugPanel
extends VBoxContainer

const STYLE = {
	"EVAL_TIME_WARNING": 1.0, # ms
	"EVAL_TIME_CRITICAL": 5.0, # ms
	"CACHED_COLOR": Color(0.2, 0.8, 0.2),
	"EVALUATED_COLOR": Color(0.8, 0.8, 0.2),
	"INVALIDATED_COLOR": Color(0.8, 0.2, 0.2),
	"TREE_INDENT": 15,
}

@onready var expression_tree: Tree = %ExpressionTree
@onready var cache_stats_label: Label = %CacheStatsLabel
@onready var evaluation_log: RichTextLabel = %EvaluationLog

var evaluation_system: EvaluationSystem
var cache: EvaluationCache
var tracked_expressions: Dictionary = {}

func _init() -> void:
	custom_minimum_size = Vector2(400, 300)
	
func initialize(p_evaluation_system: EvaluationSystem) -> void:
	evaluation_system = p_evaluation_system
	cache = evaluation_system._cache
	setup_ui()
	connect_signals()

func setup_ui() -> void:
	# Expression Tree Section
	var tree_section = create_section("Expression Tree")
	expression_tree = Tree.new()
	expression_tree.name = "ExpressionTree"
	expression_tree.unique_name_in_owner = true
	expression_tree.custom_minimum_size.y = 150
	tree_section.add_child(expression_tree)
	
	# Cache Stats Section
	var stats_section = create_section("Cache Statistics")
	cache_stats_label = Label.new()
	cache_stats_label.name = "CacheStatsLabel"
	cache_stats_label.unique_name_in_owner = true
	stats_section.add_child(cache_stats_label)
	
	# Evaluation Log Section
	var log_section = create_section("Evaluation Log")
	evaluation_log = RichTextLabel.new()
	evaluation_log.name = "EvaluationLog"
	evaluation_log.unique_name_in_owner = true
	evaluation_log.bbcode_enabled = true
	evaluation_log.custom_minimum_size.y = 100
	evaluation_log.scroll_following = true
	log_section.add_child(evaluation_log)

func create_section(title: String) -> VBoxContainer:
	var section = VBoxContainer.new()
	
	var header = Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	
	var separator = HSeparator.new()
	
	section.add_child(header)
	section.add_child(separator)
	add_child(section)
	
	return section

func connect_signals() -> void:
	cache.value_invalidated.connect(_on_cache_value_invalidated)
	expression_tree.item_selected.connect(_on_expression_selected)

func update_tree() -> void:
	expression_tree.clear()
	var root = expression_tree.create_item()
	root.set_text(0, "Expressions")
	
	# Sort expressions by ID for consistent display
	var sorted_expressions = evaluation_system._states.keys()
	sorted_expressions.sort()
	
	for expression_id in sorted_expressions:
		var state = evaluation_system._states[expression_id]
		_add_expression_to_tree(state.logic, root)

func _add_expression_to_tree(logic: Logic, parent: TreeItem) -> TreeItem:
	var item = expression_tree.create_item(parent)
	var cache_info = cache.get_debug_info(logic.id)
	
	# Basic expression info
	var display_text = "%s: %s" % [logic.name, logic.expression_string]
	if cache_info.value != null:
		display_text += " = %s" % str(cache_info.value)
	item.set_text(0, display_text)
	
	# Color based on cache state
	if cache_info.value != null:
		item.set_custom_color(0, STYLE.CACHED_COLOR)
	elif logic.id in tracked_expressions:
		item.set_custom_color(0, STYLE.EVALUATED_COLOR)
	
	# Add nested expressions recursively
	for nested in logic.nested_expressions:
		_add_expression_to_tree(nested, item)
		
	return item

func update_cache_stats() -> void:
	var stats = cache.get_stats()
	var text = """
	Cached Values: %d
	Dependencies: %d
	Reverse Dependencies: %d
	""" % [
		stats.cached_values,
		stats.dependencies,
		stats.reverse_dependencies
	]
	cache_stats_label.text = text

func _on_cache_value_invalidated(expression_id: String) -> void:
	var timestamp = Time.get_unix_time_from_system()
	var message = "[color=red]%s: Invalidated %s[/color]\n" % [
		timestamp,
		expression_id
	]
	evaluation_log.append_text(message)
	update_tree()
	update_cache_stats()

func _on_expression_selected() -> void:
	var selected = expression_tree.get_selected()
	if not selected:
		return
		
	# Find the Logic object for this tree item
	var logic: Logic
	for expression_id in evaluation_system._states:
		var state = evaluation_system._states[expression_id]
		if state.logic.name in selected.get_text(0):
			logic = state.logic
			break
			
	if not logic:
		return
		
	# Show detailed debug info
	var debug_info = cache.get_debug_info(logic.id)
	var timestamp = Time.get_unix_time_from_system()
	var message = """
	[b]Expression Debug (%s)[/b]
	ID: %s
	Value: %s
	Last Updated: %d seconds ago
	Dependencies: %s
	Dependents: %s
	
	""" % [
		timestamp,
		logic.id,
		debug_info.value,
		timestamp - debug_info.timestamp,
		debug_info.dependencies,
		debug_info.reverse_dependencies
	]
	evaluation_log.append_text(message)
