class_name Colonies
extends Iterator

func _init(initial_colonies: Variant = []):
	super._init()
	if initial_colonies is Iterator or initial_colonies is Array:
		for colony in initial_colonies:
			self.append(colony)
	else:
		push_error("Unhandled argument for Colonies.new() call")


static func all() -> Array[Colony]:
	return ColonyManager.get_all()
