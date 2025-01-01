class_name Logic
extends Resource

#region Properties
@export var name: String:
	set(value):
		name = value
		id = name.to_snake_case()

@export_multiline var expression_string: String
@export var nested_expressions: Array[Logic]
@export var description: String
@export var type: Variant.Type = TYPE_BOOL

## Minimum evaluation interval (in seconds)
@export_range(0.016, 1.0, 0.001, "or_greater") var min_eval_interval: float = 0.05:
	set(value):
		min_eval_interval = max(0.016, value)  # Minimum 16ms (roughly 1 frame)

## Maximum evaluation interval (in seconds). 0 means lazy evaluation
@export_range(0.00, 1.0, 0.001, "or_greater") var max_eval_interval: float = 0.1:
	set(value):
		max_eval_interval = max(min_eval_interval, value)

## Whether to evaluate when system has spare processing time
@export var evaluate_when_idle: bool = false

## Forces evaluation on every check, overriding intervals
@export var force_evaluation: bool = false

## Change threshold for significant value changes
@export_range(0.0, 1.0, 0.001) var change_threshold: float = 0.0

var id: String

signal value_changed(new_value: Variant, expression_id: String)
signal significant_value_change(new_value: Variant, expression_id: String)
signal action_triggered(value: Variant, expression_id: String)
#endregion

func is_lazy_evaluated() -> bool:
	return min_eval_interval > 0 and max_eval_interval <= 0 and not force_evaluation

func is_forced_interval() -> bool:
	return min_eval_interval > 0 and min_eval_interval == max_eval_interval

func needs_immediate_eval() -> bool:
	return force_evaluation or (max_eval_interval > 0 and min_eval_interval <= 0)

func can_eval_when_idle() -> bool:
	return evaluate_when_idle and not needs_immediate_eval()
