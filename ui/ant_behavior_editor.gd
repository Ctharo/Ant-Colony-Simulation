class_name AntBehaviorEditor
extends Control

var rule_container: VBoxContainer
var add_rule_button: Button
var property_browser: PropertyBrowser
var property_browser_button: Button
var selected_value_field: LineEdit
var condition_button: Button
var conditions: Dictionary = {}
var condition_manager: ConditionManager
var selected_rule_row: RuleRow

# Map of operators that work with different types
const TYPE_OPERATORS = {
	"Boolean": ["EQUALS", "NOT_EQUALS"],
	"Integer": ["EQUALS", "NOT_EQUALS", "GREATER_THAN", "LESS_THAN", "GREATER_THAN_EQUAL", "LESS_THAN_EQUAL"],
	"Float": ["EQUALS", "NOT_EQUALS", "GREATER_THAN", "LESS_THAN", "GREATER_THAN_EQUAL", "LESS_THAN_EQUAL"],
	"String": ["EQUALS", "NOT_EQUALS"],
	"Array": ["IS_EMPTY", "NOT_EMPTY"],
	"Dictionary": ["IS_EMPTY", "NOT_EMPTY"],
	"Property": ["EQUALS", "NOT_EQUALS", "GREATER_THAN", "LESS_THAN", "GREATER_THAN_EQUAL", "LESS_THAN_EQUAL"]
}

static var action_options = [
	"move_to_nearest_food",
	"harvest_nearest_food",
	"return_home",
	"store_food"
]

class RuleRow:
	var container: VBoxContainer
	var property_field: LineEdit
	var operator_button: OptionButton
	var value_field: LineEdit
	var action_button: OptionButton
	var condition_dropdown: OptionButton
	var parent: Control  # Store reference to parent

	func _init(parent: Control):
		self.parent = parent
		container = VBoxContainer.new()
		container.set_meta("rule_row", self)  # Store reference to RuleRow in container
		container.add_theme_constant_override("separation", 10)
		setup_condition_row(parent)
		setup_action_row()
		setup_remove_button(parent)

	func setup_condition_row(parent: Control):
		var condition_container = HBoxContainer.new()
		container.add_child(condition_container)

		var if_label = Label.new()
		if_label.text = "If"
		condition_container.add_child(if_label)

		condition_dropdown = OptionButton.new()
		condition_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_update_condition_options(parent.conditions)
		condition_container.add_child(condition_dropdown)

	func _update_condition_options(conditions: Dictionary) -> void:
		condition_dropdown.clear()
		for condition_name in conditions:
			condition_dropdown.add_item(condition_name)

	func setup_action_row():
		var action_container = HBoxContainer.new()
		container.add_child(action_container)

		var then_label = Label.new()
		then_label.text = "Then"
		action_container.add_child(then_label)

		action_button = OptionButton.new()
		for option in AntBehaviorEditor.action_options:
			action_button.add_item(option)
		action_container.add_child(action_button)

	func setup_remove_button(parent: Control):
		var remove_button = Button.new()
		remove_button.text = "Remove Rule"
		remove_button.connect("pressed", Callable(parent, "_on_remove_rule_pressed").bind(container))
		container.add_child(remove_button)

func _ready():
	create_ui()
	load_conditions()

	# Setup condition manager
	condition_manager = ConditionManager.new()
	condition_manager.visible = false
	condition_manager.condition_updated.connect(_on_conditions_updated)
	add_child(condition_manager)

func create_ui():
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	add_child(main_container)

	var title = Label.new()
	title.text = "Ant Logic Editor"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	main_container.add_child(title)

	# Toolbar
	var toolbar = HBoxContainer.new()
	main_container.add_child(toolbar)

	condition_button = Button.new()
	condition_button.text = "Manage Conditions"
	condition_button.connect("pressed", Callable(self, "_on_manage_conditions_pressed"))
	toolbar.add_child(condition_button)

	rule_container = VBoxContainer.new()
	main_container.add_child(rule_container)

	var button_container = HBoxContainer.new()
	main_container.add_child(button_container)

	add_rule_button = Button.new()
	add_rule_button.text = "Add New Rule"
	add_rule_button.connect("pressed", Callable(self, "_on_add_rule_pressed"))
	button_container.add_child(add_rule_button)

	# Create property browser
	property_browser = PropertyBrowser.new()
	property_browser.visible = false
	property_browser.property_selected.connect(_on_property_selected)
	add_child(property_browser)

	# Test ant for property browser
	var test_ant = Ant.new()
	property_browser.show_ant(test_ant)

func load_conditions() -> void:
	var file = FileAccess.open("res://conditions.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			conditions = json.data.get("conditions", {})

func save_conditions() -> void:
	var file = FileAccess.open("res://conditions.json", FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify({"conditions": conditions}, "\t")
		file.store_string(json_str)

func _on_manage_conditions_pressed() -> void:
	condition_manager.set_conditions(conditions)
	condition_manager.popup_centered()

func _on_conditions_updated() -> void:
	conditions = condition_manager.conditions
	save_conditions()
	# Update all condition dropdowns
	for rule_node in rule_container.get_children():
		var rule_row = rule_node.get_meta("rule_row")
		if rule_row:
			rule_row._update_condition_options(conditions)

func _on_condition_saved(condition_name: String, condition_data: Dictionary) -> void:
	conditions[condition_name] = condition_data
	save_conditions()
	# Update all condition dropdowns
	for rule in rule_container.get_children():
		rule.condition_dropdown._update_condition_options(conditions)

func _on_browse_property_pressed(rule_row: RuleRow):
	selected_rule_row = rule_row
	property_browser.visible = true
	property_browser.popup_centered(Vector2(800, 600))

func _on_property_selected(property_path: String):
	if selected_rule_row:
		selected_rule_row.property_field.text = property_path
		_update_operators_for_property(property_path, selected_rule_row.operator_button)
	property_browser.visible = false

func _update_operators_for_property(property_path: String, operator_button: OptionButton):
	operator_button.clear()
	var property_type = _get_property_type(property_path)
	if property_type in TYPE_OPERATORS:
		for op in TYPE_OPERATORS[property_type]:
			operator_button.add_item(op)

func _get_property_type(property_path: String) -> String:
	# This would need to query the property browser or ant to get the actual type
	# For now, return a default
	return "Property"

func _on_add_rule_pressed():
	var rule = create_rule()
	rule_container.add_child(rule)

func get_rules() -> Array:
	var rules = []
	for rule_node in rule_container.get_children():
		var rule_row = rule_node.get_meta("rule_row")
		if not rule_row:
			continue

		var condition_name = rule_row.condition_dropdown.get_item_text(
			rule_row.condition_dropdown.selected
		)
		rules.append({
			"condition": conditions[condition_name],
			"action": rule_row.action_button.get_item_text(
				rule_row.action_button.selected
			)
		})
	return rules

func set_rules(rules: Array):
	# Clear existing rules
	for child in rule_container.get_children():
		child.queue_free()

	# Add loaded rules
	for rule_data in rules:
		var rule_row = RuleRow.new(self)
		rule_container.add_child(rule_row.container)

		var condition = rule_data["condition"]
		rule_row.property_field.text = condition["property"]

		_update_operators_for_property(condition["property"], rule_row.operator_button)
		var op_idx = rule_row.operator_button.get_item_index(condition["operator"])
		rule_row.operator_button.select(op_idx)

		rule_row.value_field.text = str(condition["value"])

		var action_idx = action_options.find(rule_data["action"])
		rule_row.action_button.select(action_idx)

func create_rule() -> VBoxContainer:
	var rule_row = RuleRow.new(self)
	return rule_row.container

func _on_remove_rule_pressed(container: VBoxContainer):
	container.queue_free()
