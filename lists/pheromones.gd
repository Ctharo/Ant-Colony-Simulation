class_name Pheromones
extends Iterator

func _init(initial_pheromones: Pheromones = all()):
	super._init()
	for pheromone in initial_pheromones:
		self.append(pheromone)

# Filtering methods
func sensed(sensing_position: Vector2, sense_range: float) -> Pheromones:
	return Pheromones.new(self.filter(func(p): 
		return p.position.distance_to(sensing_position) <= sense_range
	))

func of_type(pheromone_type: String) -> Pheromones:
	return Pheromones.new(self.filter(func(p): return p.type == pheromone_type))

func emitted_by_colony(colony: Colony) -> Pheromones:
	return Pheromones.new(self.filter(func(p): return p.emitted_by.colony == colony))

# Sorting methods
func sort_by_concentration(descending: bool = true) -> Pheromones:
	var sorted = self.duplicate()
	sorted.sort_custom(func(a, b): 
		return a.concentration > b.concentration if descending else a.concentration < b.concentration
	)
	return Pheromones.new(sorted)

func sort_by_distance(from_position: Vector2, ascending: bool = true) -> Pheromones:
	var sorted = self.duplicate()
	sorted.sort_custom(func(a, b):
		var dist_a = a.position.distance_squared_to(from_position)
		var dist_b = b.position.distance_squared_to(from_position)
		return dist_a < dist_b if ascending else dist_a > dist_b
	)
	return Pheromones.new(sorted)

# Calculation methods
func concentration_vector(from_position: Vector2) -> Vector2:
	var vector = Vector2.ZERO
	for pheromone in self:
		var direction = from_position.direction_to(pheromone.position)
		vector += direction * pheromone.concentration
	return vector.normalized() if vector != Vector2.ZERO else Vector2.ZERO

func average_position() -> Vector2:
	if self.is_empty():
		return Vector2.ZERO
	var sum = Vector2.ZERO
	for pheromone in self:
		sum += pheromone.position
	return sum / self.size()

func total_concentration() -> float:
	return self.reduce(func(acc, p): return acc + p.concentration, 0.0)

# Utility methods
func limit(count: int) -> Pheromones:
	return Pheromones.new(self.slice(0, count))

func nearest(to_position: Vector2) -> Pheromone:
	if self.is_empty():
		return null
	return self.reduce(func(nearest, p):
		return p if p.position.distance_squared_to(to_position) < nearest.position.distance_squared_to(to_position) else nearest
	)

func furthest(from_position: Vector2) -> Pheromone:
	if self.is_empty():
		return null
	return self.reduce(func(furthest, p):
		return p if p.position.distance_squared_to(from_position) > furthest.position.distance_squared_to(from_position) else furthest
	)

static func all() -> Pheromones:
	return PheromoneManager.get_all()
