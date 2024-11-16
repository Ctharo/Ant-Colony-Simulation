class_name Colony
extends Node2D
## The ant colony node that manages colony-wide properties and resources

#region Member Variables
## Colony radius in units
var _radius: float = 10.0
## Collection of food resources
var foods: Foods
## Ants belonging to this colony
var ants: Ants = Ants.new([])
## Property access system
var _property_access: PropertyAccess:
	get:
		if not _property_access:
			_init_property_access()
		return _property_access
#endregion

## Default category for logging
@export var log_category: DebugLogger.Category = DebugLogger.Category.ENTITY

## Source identifier for logging
@export var log_from: String :
	set(value):
		log_from = value
		_configure_logger()

## Array of additional categories this node can log to
@export var additional_log_categories: Array[DebugLogger.Category] = []

func _ready() -> void:
	log_from = "colony"
	_init_property_groups()

func add_ant(_ant: Ant) -> Result:
	if _ant is Ant and not _ant == null:
		ants.append(_ant)
		_ant.set_colony(self)
		return Result.new()
	else:
		return Result.new(Result.ErrorType.INVALID_ARGUMENT, "ant argument is unexpected type")

#region Property System
func _init_property_access() -> void:
	_property_access = PropertyAccess.new(self)
	_trace("Property access system initialized")

func _init_property_groups() -> void:
	_debug("Initializing property groups...")
	
	if not _property_access:
		_init_property_access()
		
	var groups = [
		Vision.new(self),
		Storage.new(self),
		Strength.new(self)
		# Add other property groups as needed
	]
	
	for group in groups:
		_trace("Registering property group: %s" % group.name)
		var result = _property_access.register_group(group)
		if not result.success():
			_error("Failed to register property group %s: %s" % [
				group.name, 
				result.get_error()
			])
		else:
			_debug("Successfully registered property group: %s" % group.name)
	
	_debug("Property group initialization complete")

#region Property Access Interface
func get_property(path: String) -> NestedProperty:
	return _property_access.get_property(Path.parse(path))

func get_property_group(group_name: String) -> PropertyGroup:
	return _property_access.get_group(group_name)

func get_property_value(path: String) -> Variant:
	return _property_access.get_property_value(Path.parse(path))

func set_property_value(path: String, value: Variant) -> Result:
	return _property_access.set_property_value(Path.parse(path), value)

#region Property Group Access
func get_group_properties(group_name: String) -> Array[NestedProperty]:
	return _property_access.get_group_properties(group_name)

func get_group_names() -> Array[String]:
	return _property_access.get_group_names()
#endregion

#region Property Getters and Setters
func _get_position() -> Vector2:
	return global_position

func _get_radius() -> float:
	return _radius

func _set_radius(value: float) -> void:
	if value <= 0:
		_error("Colony radius must be positive")
		return

	var old_value = _radius
	_radius = value

	if old_value != _radius:
		_trace("Colony radius updated: %.2f -> %.2f" % [old_value, _radius])

func _get_area() -> float:
	return PI * _radius * _radius

func _get_perimeter() -> float:
	return 2 * PI * _radius

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
		total_energy += ant.get_property_value("energy.levels.current")
	return total_energy / ants.size()	

#endregion

#region Logging Methods
func _configure_logger() -> void:
	var categories = [log_category] as Array[DebugLogger.Category]
	categories.append_array(additional_log_categories)
	DebugLogger.configure_source(log_from, true, categories)

func _trace(message: String, category: DebugLogger.Category = log_category) -> void:
	DebugLogger.trace(category, message, {"from": log_from})

func _debug(message: String, category: DebugLogger.Category = log_category) -> void:
	DebugLogger.debug(category, message, {"from": log_from})

func _info(message: String, category: DebugLogger.Category = log_category) -> void:
	DebugLogger.info(category, message, {"from": log_from})

func _warn(message: String, category: DebugLogger.Category = log_category) -> void:
	DebugLogger.warn(category, message, {"from": log_from})

func _error(message: String, category: DebugLogger.Category = log_category) -> void:
	DebugLogger.error(category, message, {"from": log_from})
#endregion
