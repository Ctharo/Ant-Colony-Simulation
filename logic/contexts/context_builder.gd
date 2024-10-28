class_name ContextBuilder
extends RefCounted

## Reference to the ant and conditions configuration
var ant: Ant
var condition_configs: Dictionary
var context: Dictionary = {}

## Initialize with ant and conditions configuration
func _init(_ant: Ant, _condition_configs: Dictionary) -> void:
	ant = _ant
	condition_configs = _condition_configs

## Build and return the context dictionary
func build() -> Dictionary:
	if not is_instance_valid(ant):
		push_error("ContextBuilder: Invalid ant reference")
		return {}
	
	# Add condition configs to context for the evaluator
	context["condition_configs"] = condition_configs
	
	# Process each condition configuration
	for condition_name in condition_configs:
		var config = condition_configs[condition_name]
		if "evaluation" in config:
			_gather_properties_from_evaluation(config.evaluation)
	
	return context

## Recursively gather properties from evaluation configuration
## @param evaluation The evaluation configuration to process
func _gather_properties_from_evaluation(evaluation: Dictionary) -> void:
	if not evaluation is Dictionary:
		return
		
	match evaluation.get("type", ""):
		"PropertyCheck":
			# Get main property
			if "property" in evaluation:
				var property = evaluation.property
				if ant.has_method("get_" + property):
					context[property] = ant.call("get_" + property)
				elif ant.has_method(property):
					context[property] = ant.call(property)
				else:
					push_error("Ant does not have method to get property: %s" % property)
			
			# Get comparison property if needed
			if "value_from" in evaluation:
				var value_prop = evaluation.value_from
				if ant.has_method("get_" + value_prop):
					context[value_prop] = ant.call("get_" + value_prop)
				elif ant.has_method(value_prop):
					context[value_prop] = ant.call(value_prop)
				else:
					push_error("Ant does not have method to get property: %s" % value_prop)
		
		"Operator":
			# Recursively process operands for compound conditions
			for operand in evaluation.get("operands", []):
				if "evaluation" in operand:
					_gather_properties_from_evaluation(operand.evaluation)
