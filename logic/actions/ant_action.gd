class_name AntAction
extends Resource
## Base level action resource

@export var action_method: Callable
@export var duration: float = 1.0
@export var refractory_period: float = 0.0
@export var is_active: bool = false
@export var is_interruptable: bool = true
