extends Node2D

func _ready() -> void:
	spawn_ants()


func spawn_ants(num_to_spawn: int = 1) -> void:
	
	var i: int = 0
	
	while i < num_to_spawn:
		
		# Create a new ant
		var ant = Ant.new()

		# Add the ant to the scene
		add_child(ant)

		i += 1
