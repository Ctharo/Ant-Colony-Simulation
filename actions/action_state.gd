class_name ActionState

var condition: Logic
var current_cooldown: float = 0.0
var elapsed_time: float = 0.0
var influence_manager: InfluenceManager
var was_stopped: bool = false
var is_interrupted: bool = false

func _init(p_influence_manager: InfluenceManager) -> void:
	influence_manager = p_influence_manager
