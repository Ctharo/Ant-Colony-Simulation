class_name Colony
extends Node2D
## The ant colony node that manages colony-wide properties and resources

#region Member Variables
## Colony radius in units
var radius: float = 10.0 : get = _get_radius, set = _set_radius
## Collection of food resources
var foods: Foods
## Ants belonging to this colony
var ants: Ants = Ants.new([])
## Property access system
var _property_access: PropertyAccess:
	get:
		return _property_access
#endregion


var logger: Logger

#region Initialization
func _init() -> void:
	logger = Logger.new("colony", DebugLogger.Category.ENTITY)
	_init_property_access()
	_init_property_nodes()

func add_ant(ant: Ant) -> Result:
	if not ant:
		return Result.new(Result.ErrorType.INVALID_ARGUMENT, "Invalid ant")

	ants.append(ant)
	ant.set_colony(self)
	return Result.new()
#endregion

#region Property System
func _init_property_access() -> void:
	_property_access = PropertyAccess.new(self)
	logger.debug("Property access system initialized")

func _init_property_nodes() -> void:
	logger.debug("Initializing property nodes...")

	if not _property_access:
		_init_property_access()

	var nodes = [
		Reach.new(self)
	]

	for node in nodes:
		logger.debug("Registering property node: %s" % node.name)
		var result = _property_access.register_node(node)
		if not result.success():
			logger.error("Failed to register property node %s: %s" % [
				node.name,
				result.get_error()
			])
		else:
			logger.debug("Successfully registered property node: %s" % node.name)

	set_property_value("reach.range", 50.0)

	logger.debug("Property node initialization complete")

## Get colony as a property node tree
func get_as_node() -> PropertyNode:
	var builder = PropertyNode.create_tree(self)
	var root = builder\
		.container("colony", "Colony root properties")\
		.value("position", Property.Type.VECTOR2, get_position, Callable(), [], "Colony position in world space")\
		.value("radius", Property.Type.FLOAT, _get_radius, _set_radius, ["reach.range"], "Colony radius")\
		.value("area", Property.Type.FLOAT, _get_area, Callable(), ["radius"], "Colony area")\
		.value("perimeter", Property.Type.FLOAT, _get_perimeter, Callable(), ["radius"], "Colony perimeter")\
		.container("food", "Food management properties")\
			.value("count", Property.Type.INT, _get_food_count, Callable(), [], "Number of food items")\
			.value("total_mass", Property.Type.FLOAT, _get_total_food_mass, Callable(), [], "Total mass of all food")\
		.up()\
		.container("population", "Population statistics")\
			.value("count", Property.Type.INT, _get_ant_count, Callable(), [], "Number of ants")\
			.value("average_energy", Property.Type.FLOAT, _get_average_ant_energy, Callable(), [], "Average ant energy")\
		.build()

	# Add existing root nodes as children
	var root_names = get_root_names()
	for root_name in root_names:
		var node = _property_access.find_property_node(Path.parse(root_name))
		if node:
			root.add_child(node)

	return root
#endregion

#region Property Access Interface
## Find a property node by path
func find_property_node(path: String) -> PropertyNode:
	return _property_access.find_property_node(Path.parse(path))

## Get a root node by name
func get_root_node(_name: String) -> PropertyNode:
	return _property_access.get_root_node(_name)

## Get a property value by path
func get_property_value(path: String) -> Variant:
	return _property_access.get_property_value(Path.parse(path))

## Set a property value by path
func set_property_value(path: String, value: Variant) -> Result:
	return _property_access.set_property_value(Path.parse(path), value)

## Get all values in a root node
func get_root_values(root_name: String) -> Array[PropertyNode]:
	return _property_access.get_root_values(root_name)

## Get all registered root names
func get_root_names() -> Array[String]:
	return _property_access.get_root_names()

## Get all containers under a root node
func get_root_containers(root_name: String) -> Array[PropertyNode]:
	return _property_access.get_root_containers(root_name)
#endregion

#region Property Getters and Setters
func _get_radius() -> Variant:
	return get_property_value("reach.range")

func _set_radius(value: float) -> void:
	if value <= 0:
		logger.error("Colony radius must be positive")
		return

	var old_value = radius
	radius = value

	if old_value != radius:
		logger.debug("Colony radius updated: %.2f -> %.2f" % [old_value, radius])

func _get_area() -> float:
	return PI * radius * radius

func _get_perimeter() -> float:
	return 2 * PI * radius

func _get_food_count() -> int:
	return foods.size() if foods else 0

func _get_total_food_mass() -> float:
	return foods.total_mass() if foods else 0.0

func _get_foods() -> Foods:
	return foods if foods else Foods.new([])

func _get_ants() -> Ants:
	return ants if ants else Ants.new([])

func _get_ant_count() -> int:
	return ants.size()

func _get_average_ant_energy() -> float:
	if ants.is_empty():
		return 0.0
	var total_energy := 0.0
	for ant in ants:
		var ant_energy = ant.get_property_value(Path.parse("energy.levels.current"))
		if ant_energy:
			total_energy += ant_energy
	return total_energy / ants.size()
#endregion
