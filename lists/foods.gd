class_name Foods
extends Iterator

func _init(initial_foods: Foods = Foods.all()):
	super._init()
	for food in initial_foods:
		self.append(food)

func mass() -> float:
	return 0.0
	
func locations() -> Array[Vector2]:
	return [] as Array[Vector2]

func are_available() -> Foods:
	return Foods.new(reduce(func (food): return food.is_available))

func reachable(ant: Ant) -> Foods:
	return Foods.new(reduce(func (food): return food.distance_to(ant) < ant.reach.distance))

static func all() -> Foods:
	return FoodManager.get_all()
