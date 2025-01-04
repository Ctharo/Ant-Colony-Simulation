class_name Logic
extends Resource

#region Properties
## Name of the logic expression, used to generate ID
@export var name: String:
	set(value):
		name = value
		id = name.to_snake_case()

## The actual expression to evaluate
@export_multiline var expression_string: String

## Nested logic expressions used within this expression
@export var nested_expressions: Array[Logic]

## Description of what this logic does
@export var description: String

## Expected return type of the expression
@export var type: Variant.Type = TYPE_FLOAT

## Minimum evaluation interval (in seconds). Default 0.016 (16ms)
@export_range(0.016, 1.0, 0.001, "or_greater") var min_eval_interval: float = 0.016:
	set(value):
		min_eval_interval = max(0.001, value)

## Maximum evaluation interval (in seconds). 0 means no maximum
@export_range(0.00, 1.0, 0.01, "or_greater") var max_eval_interval: float = 0.5:
	set(value):
		max_eval_interval = max(0.00, value)

## Whether to evaluate when system has spare processing time
@export var evaluate_when_idle: bool = false

## Change threshold. 0.0 means report all changes, >0 requires cumulative change to exceed threshold
@export_range(0.0, 1.0, 0.001) var change_threshold: float = 0.0

## Unique identifier for this logic expression
var id: String

## Signals for value changes and actions
@warning_ignore("unused_signal")
signal value_changed(new_value: Variant, expression_id: String)
@warning_ignore("unused_signal")
signal significant_value_change(new_value: Variant, expression_id: String)
@warning_ignore("unused_signal")
signal action_triggered(value: Variant, expression_id: String)
#endregion

## Always evaluate if no nested expressions
var always_evaluate: bool:
	get:
		return nested_expressions.is_empty()

## Checks if this logic should be evaluated based on timing constraints
func should_evaluate(current_time: float, last_eval_time: float) -> bool:
	var time_since_last = current_time - last_eval_time
	
	# Must evaluate if max interval exceeded
	if max_eval_interval > 0 and time_since_last >= max_eval_interval:
		return true
		
	# Can't evaluate if min interval not met
	if min_eval_interval > 0 and time_since_last < min_eval_interval:
		return false
		
	# Can evaluate if no min interval set
	return min_eval_interval <= 0

## Determines if a change in value is significant enough to report
func is_significant_change(old_value: Variant, new_value: Variant, cumulative_change: float, 
		cumulative_vector_change: Vector2) -> Dictionary:
	if old_value == null or change_threshold <= 0.0:
		return {
			"is_significant": old_value != new_value,
			"cumulative_change": 0.0,
			"cumulative_vector_change": Vector2.ZERO
		}
	
	# Handle different value types
	match typeof(new_value):
		TYPE_FLOAT:
			var new_cumulative = cumulative_change + abs(new_value - old_value)
			return {
				"is_significant": new_cumulative > change_threshold,
				"cumulative_change": 0.0 if new_cumulative > change_threshold else new_cumulative,
				"cumulative_vector_change": cumulative_vector_change
			}
			
		TYPE_VECTOR2:
			var old_vec := old_value as Vector2
			var new_vec := new_value as Vector2
			var new_vector_change = Vector2(
				cumulative_vector_change.x + abs(new_vec.x - old_vec.x),
				cumulative_vector_change.y + abs(new_vec.y - old_vec.y)
			)
			var is_significant = new_vector_change.x > change_threshold or \
							   new_vector_change.y > change_threshold
			return {
				"is_significant": is_significant,
				"cumulative_change": cumulative_change,
				"cumulative_vector_change": Vector2.ZERO if is_significant else new_vector_change
			}
			
		_:
			return {
				"is_significant": old_value != new_value,
				"cumulative_change": cumulative_change,
				"cumulative_vector_change": cumulative_vector_change
			}

## Check if this logic uses lazy evaluation
func is_lazy_evaluated() -> bool:
	return min_eval_interval > 0 and max_eval_interval <= 0

## Check if this logic has a forced evaluation interval
func is_forced_interval() -> bool:
	return min_eval_interval > 0 and min_eval_interval == max_eval_interval

## Check if this logic needs immediate evaluation
func needs_immediate_eval() -> bool:
	return max_eval_interval > 0 and min_eval_interval <= 0

## Check if this logic can be evaluated during idle time
func can_eval_when_idle() -> bool:
	return evaluate_when_idle and not needs_immediate_eval()

## Get value with evaluation system
func get_value(eval_system: EvaluationSystem, force_update: bool = false) -> Variant:
	return eval_system.get_value(self, force_update)
