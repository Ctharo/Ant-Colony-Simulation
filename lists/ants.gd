class_name Ants
extends Iterator

func _init(initial_ants: Ants = get_all()):
	super._init()
	for ant in initial_ants:
		self.append(ant)

static func get_all() -> Ants:
	return AntManager.get_all()
