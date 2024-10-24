class_name TaskBuilder
extends RefCounted
## Task class for constructing tasks

var task: Task
var task_class: GDScript
var _priority: Behavior.Priority
var _conditions: Array[Condition] = []
var _behaviors: Array[Behavior] = []

func _init(t_class: GDScript, p: Behavior.Priority) -> void:
	task_class = t_class
	_priority = p

## Add a condition to the task
func with_condition(condition: Condition) -> TaskBuilder:
	_conditions.append(condition)
	return self

## Add a behavior with custom priority
func with_behavior(behavior: Behavior, priority: Behavior.Priority = Behavior.Priority.MEDIUM) -> TaskBuilder:
	_behaviors.append({"behavior": behavior, "priority": priority})
	return self

## Build and return the configured behavior
func build() -> Task:
	task = task_class.new(_priority)
	
	# Add behaviors
	for behavior in _behaviors:
		task.add_behavior(behavior)
				
	return task
