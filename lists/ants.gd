class_name Ants
extends Iterator

func _init(initial_ants: Array[Ant] = []):
	super._init()
	for ant in initial_ants:
		self.append(ant)

func as_array() -> Array[Ant]:
	var a: Array[Ant]
	for ant in elements:
		a.append(ant)
	return a

## Pass ant so we can exclude the caller from the list of other ants
static func in_range(_ant: Ant, range: float) -> Ants:
	var a: Ants = Ants.new()
	for ant: Ant in Ants.all():
		if ant.global_position.distance_to(_ant.global_position) <= range:
			if ant != _ant: # Exclude the ant calling
				a.append(ant)
	return a

static func all() -> Ants:
	return AntManager.get_all()
