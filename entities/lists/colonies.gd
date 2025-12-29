class_name Colonies
extends Iterator

func _init(initial_colonies: Array[Colony] = [] as Array[Colony]):
	super._init()
	for colony in initial_colonies:
		append(colony)


static func all() -> Array[Colony]:
	return ColonyManager.get_all()
