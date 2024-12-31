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

## Minimum evaluation interval (in seconds). Default 0.05 (50ms)
@export_range(0.01, 1.0, 0.01, "or_greater") var min_eval_interval: float = 0.5:
	set(value):
		min_eval_interval = max(0.01, value)
		
## Maximum evaluation interval (in seconds). 0 means no maximum
@export_range(0.01, 1.0, 0.01, "or_greater") var max_eval_interval: float = 0.0 :
	set(value):
		max_eval_interval = max(0.00, value)
## Whether to evaluate when system has spare processing time
@export var evaluate_when_idle: bool = false
## Target node to execute action on
@export var target_node: NodePath
## Method to call on target node
@export var action_method: String
## Arguments to pass to action method
@export var action_args: Array[Variant]
## Change threshold. 0.0 means report all changes, >0 requires cumulative change to exceed threshold

@export_range(0.0, 1.0, 0.001) var change_threshold: float = 0.0:
	set(value):
		if value != change_threshold:
			change_threshold = value
			_last_value = null
			_cumulative_change = 0.0
			_cumulative_vector_change = Vector2.ZERO



var id: String
var _last_value: Variant
var _cumulative_change: float = 0.0
var _cumulative_vector_change: Vector2 = Vector2.ZERO
var _last_eval_time: float = 0.0  # Track last evaluation time locally

signal value_changed(new_value: Variant, expression_id: String)
signal significant_value_change(new_value: Variant, expression_id: String)
signal action_triggered(value: Variant, expression_id: String)
#endregion

var always_evaluate: bool:
	get:
		return nested_expressions.is_empty()

func _is_significant_change(old_value: Variant, new_value: Variant) -> bool:
	if old_value == null or change_threshold <= 0.0:
		return old_value != new_value

	# Handle different value types
	match typeof(new_value):
		TYPE_FLOAT:
			_cumulative_change += abs(new_value - old_value)
			if _cumulative_change > change_threshold:
				_cumulative_change = 0.0
				return true
			return false

		TYPE_VECTOR2:
			var old_vec := old_value as Vector2
			var new_vec := new_value as Vector2
			_cumulative_vector_change.x += abs(new_vec.x - old_vec.x)
			_cumulative_vector_change.y += abs(new_vec.y - old_vec.y)
			if _cumulative_vector_change.x > change_threshold or \
			   _cumulative_vector_change.y > change_threshold:
				_cumulative_vector_change = Vector2.ZERO
				return true
			return false

		_:
			return old_value != new_value

func set_value(new_value: Variant) -> void:
	if _is_significant_change(_last_value, new_value):
		significant_value_change.emit(new_value, id)
	_last_value = new_value

func get_value(eval_system: EvaluationSystem, force_update: bool = false) -> Variant:
	var result = eval_system.get_value(self, force_update)
	set_value(result)
	return result

func should_evaluate(current_time: float) -> bool:
	var time_since_last = current_time - _last_eval_time
	
	# Must evaluate if max interval exceeded
	if max_eval_interval > 0 and time_since_last >= max_eval_interval:
		return true
		
	# Can't evaluate if min interval not met
	if min_eval_interval > 0 and time_since_last < min_eval_interval:
		return false
		
	# Can evaluate if no min interval set
	return min_eval_interval <= 0

func is_lazy_evaluated() -> bool:
	return min_eval_interval > 0 and max_eval_interval <= 0
	
func is_forced_interval() -> bool:
	return min_eval_interval > 0 and min_eval_interval == max_eval_interval
	
func needs_immediate_eval() -> bool:
	return max_eval_interval > 0 and min_eval_interval <= 0
	
func can_eval_when_idle() -> bool:
	return evaluate_when_idle and not needs_immediate_eval()

func mark_evaluated() -> void:
	_last_eval_time = Time.get_ticks_msec() / 1000.0

func _get_property_list() -> Array:
	return [{
		"name": "_runtime_state",
		"type": TYPE_DICTIONARY,
		"usage": PROPERTY_USAGE_STORAGE
	}]
