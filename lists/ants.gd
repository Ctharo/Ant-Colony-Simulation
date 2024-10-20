class_name Ants
extends Iterator

func _init(initial_ants: Ants = all()):
	super._init()
	for ant in initial_ants:
		self.append(ant)

static func all() -> Ants:
	return AntManager.get_all()
