class_name Colonies
extends Iterator

func _init(initial_colonies: Colonies = Colonies.all()):
	super._init()
	for colony in initial_colonies:
		self.append(colony)


static func all() -> Colonies:
	return ColonyManager.get_all()
