class_name Ants
extends Iterator

func _init(initial_ants: Array[Ant] = []):
	super._init()
	for ant in initial_ants:
		self.append(ant)

static func in_view(location: Vector2, view_distance: float) -> Ants:
	var a: Ants = Ants.new()
	for ant: Ant in all():
		if ant.get_position().distance_to(location) <= view_distance:
			a.append(ant)
	return a
	
static func in_reach(location: Vector2, reach_distance: float) -> Ants:
	var a: Ants = Ants.new()
	for ant: Ant in all():
		if ant.get_position().distance_to(location) <= reach_distance:
			a.append(ant)
	return a

static func all() -> Ants:
	return AntManager.get_all()
