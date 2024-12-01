@tool
extends EditorScript

const ConfigBase = preload("res://config/config_base.gd")
const PropertyCheckConfig = preload("res://config/property_check_config.gd")
const OperatorConfig = preload("res://config/operator_config.gd")
const CustomConditionConfig = preload("res://config/custom_condition_config.gd")


var conditions = {
	"AtHome": {
		"description": "Check if ant within boundary of colony radius",
		"type": "PropertyCheck",
		"evaluation": {
			"operator": "EQUALS",
			"property": "proprioception.status.at_colony",
			"type": "PropertyCheck",
			"value": true
		}
	},
	"AtTarget": {
		"description": "Check if ant at target location",
		"type": "PropertyCheck",
		"evaluation": {
			"operator": "EQUALS",
			"property": "proprioception.status.at_target",
			"type": "PropertyCheck",
			"value": true
		}
	},
	"IsCarryingFood": {
		"description": "Check if ant is carrying any food",
		"type": "PropertyCheck",
		"evaluation": {
			"operator": "EQUALS",
			"property": "storage.status.is_carrying",
			"type": "PropertyCheck",
			"value": true
		}
	},
	"IsFoodInReach": {
		"description": "Check if food is reachable by ant",
		"type": "PropertyCheck",
		"evaluation": {
			"operator": "GREATER_THAN",
			"property": "reach.foods.count",
			"type": "PropertyCheck",
			"value": 0
		}
	},
	"IsFoodInView": {
		"description": "Check if food is visible to ant",
		"type": "PropertyCheck",
		"evaluation": {
			"operator": "GREATER_THAN",
			"property": "vision.foods.count",
			"type": "PropertyCheck",
			"value": 0
		}
	},
	"IsFoodPheromoneSensed": {
		"description": "Check if food pheromones are detected",
		"type": "PropertyCheck",
		"evaluation": {
			"operator": "GREATER_THAN",
			"property": "olfaction.pheromones.food.count",
			"type": "PropertyCheck",
			"value": 0
		}
	},
	"IsHomePheromoneSensed": {
		"description": "Check if home pheromones are detected",
		"type": "PropertyCheck",
		"evaluation": {
			"operator": "GREATER_THAN",
			"property": "olfaction.pheromones.home.count",
			"type": "PropertyCheck",
			"value": 0
		}
	},
	"IsAnyPheromoneSensed": {
		"description": "Check if any pheromones are detected",
		"type": "PropertyCheck",
		"evaluation": {
			"operator": "GREATER_THAN",
			"property": "olfaction.pheromones.count",
			"type": "PropertyCheck",
			"value": 0
		}
	},
	"LowEnergy": {
		"description": "Check if ant's energy is low but not depleted",
		"type": "PropertyCheck",
		"evaluation": {
			"operator": "EQUALS",
			"property": "energy.status.is_low",
			"type": "PropertyCheck",
			"value": true
		}
	},
	"LowHealth": {
		"description": "Check if ant's health is low but not depleted",
		"type": "PropertyCheck",
		"evaluation": {
			"operator": "EQUALS",
			"property": "health.status.is_low",
			"type": "PropertyCheck",
			"value": true
		}
	},
	"HasStorageSpace": {
		"description": "Check if ant has space to store more items",
		"type": "PropertyCheck",
		"evaluation": {
			"operator": "EQUALS",
			"property": "storage.status.is_full",
			"type": "PropertyCheck",
			"value": false
		}
	},
	"OverloadedWithFood": {
		"description": "Check if ant has no more space",
		"type": "PropertyCheck",
		"evaluation": {
			"operator": "EQUALS",
			"property": "storage.status.is_full",
			"type": "PropertyCheck",
			"value": true
		}
	},
	"CanMoveAndAct": {
		"description": "Check if ant is able to move and perform actions",
		"type": "Operator",
		"evaluation": {
			"type": "Operator",
			"operator_type": "or",
			"operands": [
				{
					"type": "PropertyCheck",
					"property": "storage.status.is_full",
					"operator": "EQUALS",
					"value": false
				},
				{
					"type": "PropertyCheck",
					"property": "energy.status.is_depleted",
					"operator": "EQUALS",
					"value": false
				}
			]
		}
	}
}
func _run() -> void:
	# Create conditions directory if it doesn't exist
	DirAccess.make_dir_absolute("res://resources/conditions")
	convert_conditions_to_resources()


## Converts a dictionary of conditions into ResourceConfigs and saves them
## [param conditions] Dictionary of condition configurations to convert
func convert_conditions_to_resources() -> void:
	# Create the conditions directory if it doesn't exist
	var dir = DirAccess.open("res://resources")
	if !dir.dir_exists("conditions"):
		dir.make_dir("conditions")

	for condition_name in conditions:
		var condition_data = conditions[condition_name]
		var config: ConfigBase

		# Convert the evaluation data into the appropriate resource type
		match condition_data.type:
			"PropertyCheck":
				config = _create_property_check(condition_data.evaluation)
			"Operator":
				config = _create_operator_check(condition_data.evaluation)
			"Custom":
				config = _create_custom_condition(condition_name, condition_data)
			_:
				push_error("Unknown condition type: %s" % condition_data.type)
				continue

		# Save the resource
		if config:
			var path = "res://resources/conditions/%s.tres" % condition_name.to_snake_case()
			var error = ResourceSaver.save(config, path)
			if error != OK:
				push_error("Failed to save condition resource: %s (Error: %d)" % [path, error])

## Creates a PropertyCheckConfig resource from dictionary data
## [param data] Dictionary containing property check configuration
func _create_property_check(data: Dictionary) -> PropertyCheckConfig:
	var config = PropertyCheckConfig.new()
	config.property = Path.parse(data.property)
	config.operator = data.operator

	if data.value is String and "." in data.value: # In path.full format
		config.value = Path.parse(data.value)
	else:
		config.value = data.value
	return config

## Creates an OperatorConfig resource from dictionary data
## [param data] Dictionary containing operator configuration
func _create_operator_check(data: Dictionary) -> OperatorConfig:
	var config = OperatorConfig.new()
	config.operator_type = data.operator_type

	# Convert each operand recursively
	for operand in data.operands:
		var operand_config: ConfigBase

		match operand.type:
			"PropertyCheck":
				operand_config = _create_property_check(operand)
			"Operator":
				operand_config = _create_operator_check(operand)
			_:
				push_error("Unknown operand type: %s" % operand.type)
				continue

		if operand_config:
			config.operands.append(operand_config)

	return config

## Creates a CustomConditionConfig resource from dictionary data
## [param condition_name] Name of the custom condition
## [param data] Dictionary containing custom condition configuration
func _create_custom_condition(condition_name: String, data: Dictionary) -> CustomConditionConfig:
	var config = CustomConditionConfig.new()
	config.condition_name = condition_name

	if data.has("evaluation"):
		config.evaluation = _create_property_check(data.evaluation)

	return config
