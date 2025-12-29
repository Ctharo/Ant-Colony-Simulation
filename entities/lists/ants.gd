class_name Ants
extends Iterator

func _init(initial_ants: Array[Ant] = [] as Array[Ant]):
	super._init()
	for ant in initial_ants:
		self.append(ant)

func as_array() -> Array[Ant]:
	var a: Array[Ant]
	for ant in elements:
		a.append(ant)
	return a

## Pass ant so we can exclude the caller from the list of other ants
static func in_range(_entity: Node, _range: float) -> Ants:
	var a: Ants = Ants.new()
	for ant: Ant in Ants.all():
		if ant.global_position.distance_to(_entity.global_position) <= _range:
			if ant != _entity: # Exclude the ant calling
				a.append(ant)
	return a

static func all() -> Array[Ant]:
	return AntManager.get_all()
