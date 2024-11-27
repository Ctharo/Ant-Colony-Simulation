class_name ContextRegistry 
extends RefCounted
## Stores registered context values and manages their updates

var _values: Dictionary = {}
var _current_time: float = 0.0
var logger = Logger.new("context_registry", DebugLogger.Category.CONTEXT)

func register_value(key: String, frequency: Context.UpdateFrequency, collector: Callable, can_interrupt: bool = false) -> void:
	_values[key] = Value.new(key, frequency, collector, can_interrupt)
	logger.debug("Registered context value: %s (frequency: %s, can_interrupt: %s)" % 
		[key, Context.UpdateFrequency.keys()[frequency], can_interrupt])

func update(delta: float) -> Array[String]:
	_current_time += delta
	var changed_interrupt_values: Array[String] = []
	
	for value in _values.values():
		if value.should_update(_current_time):
			if value.update(_current_time) and value.can_interrupt:
				changed_interrupt_values.append(value.key)
				logger.debug("Interrupt-capable context value changed: %s" % value.key)
	
	return changed_interrupt_values

func get_context() -> Dictionary:
	var context = {}
	for key in _values:
		context[key] = _values[key].current_value
	return context

## Definition of a context value that needs to be collected
class Value extends RefCounted:
	var key: String
	var frequency: Context.UpdateFrequency
	var collector_func: Callable
	var last_update_time: float = 0.0
	var current_value: Variant
	var can_interrupt: bool
	
	func _init(p_key: String, p_frequency: Context.UpdateFrequency, p_collector: Callable, p_can_interrupt: bool) -> void:
		key = p_key
		frequency = p_frequency
		collector_func = p_collector
		can_interrupt = p_can_interrupt
	
	func should_update(current_time: float) -> bool:
		var interval = Context.UPDATE_INTERVALS[frequency]
		return current_time - last_update_time >= interval or current_time == 0.0
	
	func update(current_time: float) -> bool:
		var old_value = current_value
		current_value = collector_func.call()
		last_update_time = current_time
		return can_interrupt and old_value != current_value
