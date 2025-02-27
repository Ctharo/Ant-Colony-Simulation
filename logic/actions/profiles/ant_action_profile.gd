class_name AntActionProfile
extends Resource

## Name of this action profile
@export var name: String:
	set(value):
		name = value
		id = name.to_snake_case()
var id: String

## Actions included in this profile
@export var actions: Array[AntAction]

## Condition that must be true for this profile to be active
@export var activation_condition: Logic

## Priority of this profile (higher values take precedence)
@export var priority: int = 0

## Logger instance
var logger: Logger

func _init() -> void:
	logger = Logger.new("ant_action_profile", DebugLogger.Category.ENTITY)

## Check if this profile is active for the given ant
func is_active_for(ant: Ant) -> bool:
	if not is_instance_valid(ant):
		return false

	if activation_condition:
		return activation_condition.get_value(ant)

	return true

## Apply this profile to an ant's action manager
func apply_to(ant: Ant) -> void:
	if not is_instance_valid(ant) or not is_instance_valid(ant.action_manager):
		logger.error("Cannot apply profile to invalid ant or action manager")
		return

	for action in actions:
		if is_instance_valid(action):
			# Create a duplicate so each ant has its own instance
			var action_instance = action.duplicate()
			ant.action_manager.add_action(action_instance)

	logger.debug("Applied action profile '" + name + "' to " + ant.name)

## Remove this profile from an ant's action manager
func remove_from(ant: Ant) -> void:
	if not is_instance_valid(ant) or not is_instance_valid(ant.action_manager):
		logger.error("Cannot remove profile from invalid ant or action manager")
		return

	for action in actions:
		if is_instance_valid(action):
			var existing_action = ant.action_manager.get_action_by_name(action.name)
			if existing_action:
				ant.action_manager.remove_action(existing_action)

	logger.debug("Removed action profile '" + name + "' from " + ant.name)

## Get debug information about this profile
func get_debug_info() -> String:
	var info = "Profile: " + name + " (Priority: " + str(priority) + ")\n"
	info += "Actions: " + str(actions.size()) + "\n"

	for i in range(actions.size()):
		var action = actions[i]
		info += "  " + str(i+1) + ". " + action.name
		if action.description:
			info += " - " + action.description
		info += "\n"

	return info
