class_name ContextBuilder
extends RefCounted

## Reference to the ant and conditions configuration
var ant: Ant
var condition_configs: Dictionary
var context: Dictionary = {}

## Initialize with ant and conditions configuration
func _init(_ant: Ant, _condition_configs: Dictionary):
	ant = _ant
	condition_configs = _condition_configs

## Build and return the context dictionary
func build() -> Dictionary:
	if not is_instance_valid(ant):
		push_error("ContextBuilder: Invalid ant reference")
		return {}
	
	# Process each condition configuration
	for condition_name in condition_configs:
		var config = condition_configs[condition_name]
		_gather_properties_from_evaluation(config.evaluation)
	
	return context

## Recursively gather properties from evaluation configuration
## @param evaluation The evaluation configuration to process
func _gather_properties_from_evaluation(evaluation: Dictionary) -> void:
	match evaluation.type:
		"PropertyCheck":
			# Get main property
			if "property" in evaluation:
				var property = evaluation.property
				context[property] = ant.get(property)
			
			# Get comparison property if needed
			if "value_from" in evaluation:
				var value_prop = evaluation.value_from
				context[value_prop] = ant.get(value_prop)
		
		"Operator":
			# Recursively process operands for compound conditions
			for operand in evaluation.get("operands", []):
				_gather_properties_from_evaluation(operand.evaluation)
