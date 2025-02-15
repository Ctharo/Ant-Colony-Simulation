class_name AntAction
extends Node

enum ACTION { 
	MOVE = 0, 
	HARVEST = 1,
	STORE = 2,
	REST = 3
}

var action_map: Dictionary[ACTION, Callable] = {
	ACTION.MOVE: Callable(Ant, "move_to")
}
