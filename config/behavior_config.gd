class_name BehaviorConfig
extends Resource

@export var name: String
@export var priority: String = "MEDIUM"
@export var action: ActionConfig
@export var conditions: Array[Dictionary] = []
