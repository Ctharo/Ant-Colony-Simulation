extends Control
class_name AntBehaviorEditor

var rule_container: VBoxContainer
var add_rule_button: Button

enum ComparisonOperator {
	EQUAL,
	NOT_EQUAL,
	GREATER_THAN,
	LESS_THAN,
	GREATER_THAN_OR_EQUAL,
	LESS_THAN_OR_EQUAL
}

var property_options = [
	"food.in_view",
	"food.in_reach",
	"energy.current",
	"energy.max",
	"carry_mass.current",
	"carry_mass.max",
	"home.within_reach",
	"sight_range",
	"pheromone_sense_range"
]

var action_options = [
	"move_to_nearest_food",
	"harvest_nearest_food",
	"return_home",
	"store_food"
]

func _ready():
	create_ui()

func create_ui():
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	add_child(main_container)

	var title = Label.new()
	title.text = "Ant Logic Editor"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	main_container.add_child(title)

	rule_container = VBoxContainer.new()
	main_container.add_child(rule_container)

	add_rule_button = Button.new()
	add_rule_button.text = "Add New Rule"
	add_rule_button.connect("pressed", Callable(self, "_on_add_rule_pressed"))
	main_container.add_child(add_rule_button)

func _on_add_rule_pressed():
	var rule = create_rule()
	rule_container.add_child(rule)

func create_rule() -> VBoxContainer:
	var rule = VBoxContainer.new()

	var condition_container = HBoxContainer.new()
	rule.add_child(condition_container)

	var if_label = Label.new()
	if_label.text = "If"
	condition_container.add_child(if_label)

	var property = OptionButton.new()
	for option in property_options:
		property.add_item(option)
	condition_container.add_child(property)

	var operator = OptionButton.new()
	for op in ComparisonOperator.keys():
		operator.add_item(op)
	condition_container.add_child(operator)

	var value = LineEdit.new()
	value.placeholder_text = "Value or Expression"
	condition_container.add_child(value)

	var action_container = HBoxContainer.new()
	rule.add_child(action_container)

	var then_label = Label.new()
	then_label.text = "Then"
	action_container.add_child(then_label)

	var action = OptionButton.new()
	for option in action_options:
		action.add_item(option)
	action_container.add_child(action)

	var remove_button = Button.new()
	remove_button.text = "Remove Rule"
	remove_button.connect("pressed", Callable(self, "_on_remove_rule_pressed").bind(rule))
	rule.add_child(remove_button)

	return rule

func _on_remove_rule_pressed(rule: VBoxContainer):
	rule.queue_free()

func _on_insert_property_pressed(value_field: LineEdit):
	var popup = PopupMenu.new()
	for option in property_options:
		popup.add_item(option)
	
	popup.connect("id_pressed", Callable(self, "_on_property_selected").bind(value_field))
	add_child(popup)
	popup.popup(Rect2(get_global_mouse_position(), Vector2(100, 100)))

func _on_property_selected(id: int, value_field: LineEdit):
	var selected_property = property_options[id]
	var current_text = value_field.text
	var cursor_pos = value_field.caret_column
	
	var new_text = current_text.substr(0, cursor_pos) + selected_property + current_text.substr(cursor_pos)
	value_field.text = new_text
	value_field.caret_column = cursor_pos + selected_property.length()

func get_rules() -> Array:
	var rules = []
	for rule_node in rule_container.get_children():
		var condition_container = rule_node.get_child(0)
		var action_container = rule_node.get_child(1)
		
		var property = condition_container.get_child(1).get_item_text(condition_container.get_child(1).selected)
		var operator = ComparisonOperator.keys()[condition_container.get_child(2).selected]
		var value = condition_container.get_child(3).text
		var action = action_container.get_child(1).get_item_text(action_container.get_child(1).selected)
		
		rules.append({
			"property": property,
			"operator": operator,
			"value": value,
			"action": action
		})
	return rules

func set_rules(rules: Array):
	# Clear existing rules
	for child in rule_container.get_children():
		child.queue_free()
	
	# Add loaded rules
	for rule_data in rules:
		var rule = create_rule()
		rule_container.add_child(rule)
		
		var condition_container = rule.get_child(0)
		var action_container = rule.get_child(1)
		
		condition_container.get_child(1).select(property_options.find(rule_data["property"]))
		condition_container.get_child(2).select(ComparisonOperator.keys().find(rule_data["operator"]))
		condition_container.get_child(3).text = rule_data["value"]
		action_container.get_child(1).select(action_options.find(rule_data["action"]))
