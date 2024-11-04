class_name PropertiesContainer
extends RefCounted

#region Signals
signal property_added(info: PropertyResult.PropertyInfo)
signal property_removed(name: String)
signal property_changed(name: String, old_value: Variant, new_value: Variant)
signal category_added(info: PropertyResult.CategoryInfo)
signal category_removed(name: String)
#endregion

#region Member Variables
var _properties: Dictionary = {}  # name -> PropertyInfo
var _categories: Dictionary = {}  # name -> CategoryInfo
var _owner: Object
var _cache: PropertyCache
#endregion

func _init(owner: Object, use_caching: bool = true) -> void:
	_owner = owner
	_cache = PropertyCache.new() if use_caching else null

#region Property Management

func expose_properties(properties: Array[PropertyResult.PropertyInfo]) -> Array[PropertyResult]:
	var results: Array[PropertyResult] = []
	for prop in properties:
		results.append(expose_property(
			prop.name,
			prop.getter,
			prop.type,
			prop.setter,
			prop.description,
			prop.category
		))
	return results
	
## Exposes a new property with the given configuration
func expose_property(
	name: String, 
	getter: Callable, 
	type: Component.PropertyType, 
	setter: Callable = Callable(),
	description: String = "",	
	category: String = ""
) -> PropertyResult:
	# Validate property doesn't exist
	if _properties.has(name):
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.DUPLICATE_PROPERTY,
			"Property '%s' already exists" % name
		)
	
	# Validate getter
	if not _is_valid_getter(getter):
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.INVALID_GETTER,
			"Invalid getter for property '%s'" % name
		)
	
	# Validate setter if provided
	if setter.is_valid() and not _is_valid_setter(setter):
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.INVALID_SETTER,
			"Invalid setter for property '%s'" % name
		)
	
	# Get initial value
	var initial_value = getter.call()
	
	# Create property info
	var prop_info = PropertyResult.PropertyInfo.new(
		name,
		type,
		initial_value,
		getter,
		setter,
		category,
		description
	)
	
	# Store property
	_properties[name] = prop_info
	
	# Add to category if specified
	if not category.is_empty():
		_ensure_category(category).add_property(prop_info)
	
	property_added.emit(prop_info)
	return PropertyResult.new(prop_info)

## Removes a property from the container
func remove_property(name: String) -> PropertyResult:
	if not _properties.has(name):
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.PROPERTY_NOT_FOUND,
			"Property '%s' doesn't exist" % name
		)
	
	# Remove from categories
	for category in _categories.values():
		category.properties = category.properties.filter(
			func(p): return p.name != name
		)
	
	_properties.erase(name)
	_invalidate_cache(name)
	property_removed.emit(name)
	return PropertyResult.new(null)

## Gets the value of a property
func get_property_value(name: String) -> PropertyResult:
	# Validate property exists
	if not _properties.has(name):
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.PROPERTY_NOT_FOUND,
			"Property '%s' doesn't exist" % name
		)
	
	var prop_info = _properties[name]
	
	# Check cache if enabled
	if _cache and _cache.has_valid_cache(name):
		return PropertyResult.new(_cache.get_cached(name))
	
	# Get fresh value
	var value = prop_info.getter.call()
	
	# Update cache
	if _cache:
		_cache.cache_value(name, value)
		prop_info.value = value  # Update stored value
	
	return PropertyResult.new(value)

## Sets the value of a property
func set_property_value(name: String, value: Variant) -> PropertyResult:
	# Validate property exists
	if not _properties.has(name):
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.PROPERTY_NOT_FOUND,
			"Property '%s' doesn't exist" % name
		)
	
	var prop_info = _properties[name]
	
	# Validate property is writable
	if not prop_info.writable:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.INVALID_SETTER,
			"Property '%s' is read-only" % name
		)
	
	# Validate value type
	if not _is_valid_type(value, prop_info.type):
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.TYPE_MISMATCH,
			"Invalid type for property '%s'" % name
		)
	
	# Get old value and set new value
	var old_value = get_property_value(name).value
	prop_info.setter.call(value)
	prop_info.value = value  # Update stored value
	
	# Invalidate cache
	_invalidate_cache(name)
	
	property_changed.emit(name, old_value, value)
	return PropertyResult.new(value)
#endregion

#region Property Information
## Gets information about a specific property
func get_property_info(name: String) -> PropertyResult.PropertyInfo:
	return _properties.get(name)

## Gets all property names
func get_properties() -> Array:
	return _properties.keys()

## Checks if a property exists
func has_property(name: String) -> bool:
	return _properties.has(name)
#endregion

#region Category Management
## Gets information about a specific category
func get_category_info(name: String) -> PropertyResult.CategoryInfo:
	return _categories.get(name)

## Gets all category names
func get_categories() -> Array[String]:
	return _categories.keys()

## Gets properties in a specific category
func get_properties_in_category(category: String) -> Array[String]:
	if not _categories.has(category):
		return []
	return _categories[category].properties.map(func(p): return p.name)

## Assigns a property to a category
func assign_to_category(property_name: String, category: String) -> PropertyResult:
	# Validate property exists
	if not has_property(property_name):
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.PROPERTY_NOT_FOUND,
			"Property '%s' doesn't exist" % property_name
		)
	
	# Remove from existing category
	for cat in _categories.values():
		cat.properties = cat.properties.filter(
			func(p): return p.name != property_name
		)
	
	# Add to new category
	var prop_info = get_property_info(property_name)
	_ensure_category(category).add_property(prop_info)
	
	return PropertyResult.new(null)
#endregion

#region Cache Management
## Sets the cache time-to-live in seconds
func set_cache_ttl(ttl: float) -> void:
	if _cache:
		_cache.default_ttl = ttl

## Invalidates the cache for a specific property
func invalidate_cache(name: String) -> void:
	_invalidate_cache(name)

## Invalidates all property caches
func invalidate_all_caches() -> void:
	if _cache:
		_cache.clear()
#endregion

#region Helper Functions
## Gets the category a property belongs to
func _get_property_category(property_name: String) -> String:
	for category_name in _categories:
		var category = _categories[category_name]
		if category.properties.any(func(p): return p.name == property_name):
			return category_name
	return ""

## Ensures a category exists, creating it if necessary
func _ensure_category(name: String) -> PropertyResult.CategoryInfo:
	if not _categories.has(name):
		var category = PropertyResult.CategoryInfo.new(name)
		_categories[name] = category
		category_added.emit(category)
	return _categories[name]

## Invalidates cache for a property
func _invalidate_cache(name: String) -> void:
	if _cache and _properties.has(name):
		_cache.invalidate(name)

## Validates a getter callable
func _is_valid_getter(getter: Callable) -> bool:
	if not getter.is_valid() or not getter.get_object() or getter.get_method().is_empty():
		return false
	return getter.get_argument_count() == 0 and getter.get_object().has_method(getter.get_method())

## Validates a setter callable
func _is_valid_setter(setter: Callable) -> bool:
	if not setter.is_valid() or not setter.get_object() or setter.get_method().is_empty():
		return false
	return setter.get_argument_count() == 1 and setter.get_object().has_method(setter.get_method())

## Validates a value matches the expected type
func _is_valid_type(value: Variant, expected_type: Component.PropertyType) -> bool:
	match expected_type:
		Component.PropertyType.BOOL:
			return typeof(value) == TYPE_BOOL
		Component.PropertyType.INT:
			return typeof(value) == TYPE_INT
		Component.PropertyType.FLOAT:
			return typeof(value) == TYPE_FLOAT
		Component.PropertyType.STRING:
			return typeof(value) == TYPE_STRING
		Component.PropertyType.VECTOR2:
			return value is Vector2
		Component.PropertyType.VECTOR3:
			return value is Vector3
		Component.PropertyType.ARRAY:
			return value is Array
		Component.PropertyType.DICTIONARY:
			return value is Dictionary
		Component.PropertyType.OBJECT:
			return value is Object
	return false
#endregion
