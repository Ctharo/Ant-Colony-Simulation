class_name QuadTree
extends RefCounted

class QuadTreeBounds:
	var center: Vector2
	var size: Vector2
	
	func _init(p_center: Vector2, p_size: Vector2) -> void:
		center = p_center
		size = p_size
	
	func contains(point: Vector2) -> bool:
		return (
			point.x >= center.x - size.x / 2 and
			point.x <= center.x + size.x / 2 and
			point.y >= center.y - size.y / 2 and
			point.y <= center.y + size.y / 2
		)
	
	func intersects(other: QuadTreeBounds) -> bool:
		return not (
			other.center.x - other.size.x / 2 > center.x + size.x / 2 or
			other.center.x + other.size.x / 2 < center.x - size.x / 2 or
			other.center.y - other.size.y / 2 > center.y + size.y / 2 or
			other.center.y + other.size.y / 2 < center.y - size.y / 2
		)

class QuadTreeObject:
	var position: Vector2
	var data: Variant
	
	func _init(p_position: Vector2, p_data: Variant) -> void:
		position = p_position
		data = p_data

var bounds: QuadTreeBounds
var objects: Array[QuadTreeObject] = []
var children: Array[QuadTree] = []
var max_objects: int = 10
var max_depth: int = 5
var depth: int = 0

func _init(p_bounds: QuadTreeBounds, p_depth: int = 0) -> void:
	bounds = p_bounds
	depth = p_depth

func clear() -> void:
	objects.clear()
	for child in children:
		child.clear()
	children.clear()

func subdivide() -> void:
	var half_size = bounds.size / 2
	var quarter_size = half_size / 2
	
	for x in [-1, 1]:
		for y in [-1, 1]:
			var center = bounds.center + Vector2(quarter_size.x * x, quarter_size.y * y)
			var child_bounds = QuadTreeBounds.new(center, half_size)
			children.append(QuadTree.new(child_bounds, depth + 1))

func insert(position: Vector2, data: Variant) -> void:
	if not bounds.contains(position):
		return
		
	if objects.size() < max_objects or depth >= max_depth:
		objects.append(QuadTreeObject.new(position, data))
		return
	
	if children.is_empty():
		subdivide()
		# Redistribute existing objects to children
		var existing_objects = objects.duplicate()
		objects.clear()
		for obj in existing_objects:
			_insert_to_children(obj.position, obj.data)
	
	# Insert new object to appropriate child only
	_insert_to_children(position, data)

func _insert_to_children(position: Vector2, data: Variant) -> void:
	for child in children:
		if child.bounds.contains(position):
			child.insert(position, data)
			return  # Important: only insert into one child

func query_range(range_bounds: QuadTreeBounds) -> Array:
	var found_objects: Array = []
	
	if not bounds.intersects(range_bounds):
		return found_objects
	
	for obj in objects:
		if range_bounds.contains(obj.position):
			found_objects.append(obj.data)
	
	for child in children:
		found_objects.append_array(child.query_range(range_bounds))
	
	return found_objects

func query_radius(center: Vector2, radius: float) -> Array:
	var range_bounds = QuadTreeBounds.new(
		center,
		Vector2.ONE * radius * 2
	)
	
	var found_objects: Array = []
	var candidates = query_range(range_bounds)
	
	for candidate in candidates:
		# Simply use the position stored in the candidate data
		if center.distance_to(candidate.position) <= radius:
			found_objects.append(candidate.data)
	
	return found_objects
