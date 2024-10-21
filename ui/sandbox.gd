extends Node2D

func _ready() -> void:
	spawn_ants()


func spawn_ants(num_to_spawn: int = 1) -> void:
	
	var i: int = 0
	
	while i < num_to_spawn:
		
		var config_manager = AntConfigManager.new()

		# Create a new ant
		var ant = Ant.new(config_manager)

		# Add the ant to the scene
		add_child(ant)

		i += 1
