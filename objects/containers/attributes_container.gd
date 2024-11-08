class_name AttributesContainer
extends RefCounted
## Container for managing attribute-based properties with dynamic access
##
## This container implements the IPropertyContainer interface and provides
## functionality for managing attributes that contain multiple properties.

#region Signals
signal attribute_added(info: PropertyResult.CategoryInfo)
signal attribute_removed(name: String)
signal property_changed(attribute: String, property: String, old_value: Variant, new_value: Variant)
#endregion

#region Member Variables
## Dictionary mapping attribute names to their category info
var _attributes: Dictionary = {}  # name -> CategoryInfo
var _cache: PropertyCache
var _owner: Object
#endregion

func _init(owner: Object, use_caching: bool = true) -> void:
	_owner = owner
	_cache = PropertyCache.new() if use_caching else null

#region Attribute Management
## Registers a new attribute by automatically collecting its exposed properties
## Returns: PropertyResult with the created attribute info
func register_attribute(attribute: Attribute) -> PropertyResult:
	# Validate input
	if not attribute:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.TYPE_MISMATCH,
			"Attribute cannot be null"
		)
		
	var name = attribute.name
	
	# Check for duplicate attributes
	if _attributes.has(name):
		var msg = "Attribute '%s' already exists" % name
		DebugLogger.error(
			DebugLogger.Category.PROPERTY,
			"Failed to register attribute %s: %s" % [name, msg]
		)
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.DUPLICATE_PROPERTY,
			msg
		)
	
	# Create category info
	var category_info = PropertyResult.CategoryInfo.new(name)
	var properties = attribute.get_properties()
	
	DebugLogger.trace(
		DebugLogger.Category.PROPERTY,
		"Adding %d properties to attribute %s" % [properties.size(), name]
	)
	
	# Add properties to category
	for property in properties:
		var prop_info = property.property_info
		var value = null
		if prop_info.getter.is_valid():
			value = get_attribute_property_value(name, prop_info.name)
		
		prop_info.value = value
		category_info.add_property(prop_info)
		
		DebugLogger.trace(
			DebugLogger.Category.PROPERTY,
			"Added property %s to attribute %s" % [prop_info.name, name]
		)
	
	_attributes[name] = category_info
	
	DebugLogger.trace(
		DebugLogger.Category.PROPERTY,
		"Successfully registered attribute %s" % name
	)
	
	attribute_added.emit(category_info)
	return PropertyResult.new(category_info)
	
## Removes an attribute and all its properties
func remove_attribute(name: String) -> PropertyResult:
	if not _attributes.has(name):
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.PROPERTY_NOT_FOUND,
			"Attribute '%s' doesn't exist" % name
		)
	
	_attributes.erase(name)
	_invalidate_attribute_cache(name)
	attribute_removed.emit(name)
	return PropertyResult.new(null)
#endregion

#region Property Access
func get_attribute_property_value(attribute: String, property: String) -> Variant:
	var result = get_attribute_property(attribute, property)
	return result.value if result.success() else null

func get_attribute_property(attribute: String, property: String) -> PropertyResult:
	var prop_info = get_property_info(attribute, property)
	if not prop_info:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.PROPERTY_NOT_FOUND,
			"Property '%s' not found in attribute '%s'" % [property, attribute]
		)
	
	# Validate getter exists and is valid
	if not prop_info.getter.is_valid():
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.INVALID_GETTER,
			"Invalid getter for property '%s' in attribute '%s'" % [property, attribute]
		)
	
	var cache_key = _get_cache_key(attribute, property)
	
	# Check cache if enabled
	if _cache and _cache.has_valid_cache(cache_key):
		return PropertyResult.new(_cache.get_cached(cache_key))
	
	# Get fresh value using getter
	var value = prop_info.getter.call()
	
	# Update cache and stored value
	if _cache:
		_cache.cache_value(cache_key, value)
	prop_info.value = value  # Keep stored value in sync
	
	return PropertyResult.new(value)

func get_attribute_properties(attribute: String) -> Array[PropertyResult]:
	if not _attributes.has(attribute):
		return []
	
	var results: Array[PropertyResult] = []
	var category_info = _attributes[attribute]
	
	for prop_info in category_info.properties:
		var value_result = get_attribute_property(attribute, prop_info.name)
		results.append(value_result)
	
	return results

func get_attribute_property_infos(
	attribute: String
) -> Array[PropertyResult.PropertyInfo]:
	# Validate input
	if attribute.is_empty():
		DebugLogger.error(
			DebugLogger.Category.PROPERTY,
			"Attribute name cannot be empty"
		)
		return []
		
	if not _attributes.has(attribute):
		DebugLogger.error(
			DebugLogger.Category.PROPERTY,
			"Attribute '%s' not found" % attribute
		)
		return []
	
	var category_info = _attributes[attribute]
	return category_info.properties

func get_property(attribute: String, property: String) -> PropertyResult:
	# Get property info first
	var prop_info = get_property_info(attribute, property)
	if not prop_info:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.PROPERTY_NOT_FOUND,
			"Property '%s' not found in attribute '%s'" % [property, attribute]
		)
	
	# Validate getter exists and is valid
	if not prop_info.getter.is_valid():
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.INVALID_GETTER,
			"Invalid getter for property '%s' in attribute '%s'" % [property, attribute]
		)
	
	var cache_key = _get_cache_key(attribute, property)
	
	# Check cache if enabled
	if _cache and _cache.has_valid_cache(cache_key):
		return PropertyResult.new(_cache.get_cached(cache_key))
	
	# Get fresh value using getter
	var value = prop_info.getter.call()
	
	# Update cache and stored value
	if _cache:
		_cache.cache_value(cache_key, value)
	prop_info.value = value  # Keep stored value in sync
	
	return PropertyResult.new(value)

## Gets information about a specific property in an attribute
func get_property_info(attribute: String, property: String) -> PropertyResult.PropertyInfo:
	if not _attributes.has(attribute):
		return null
	
	var category_info = _attributes[attribute]
	for prop_info in category_info.properties:
		if prop_info.name == property:
			return prop_info
	return null

## Gets the type of a property in an attribute
func get_property_type(attribute: String, property: String) -> Component.PropertyType:
	var info = get_property_info(attribute, property)
	return info.type if info else Component.PropertyType.UNKNOWN

## Gets metadata for an attribute
func get_attribute_metadata(attribute: String) -> Dictionary:
	if not _attributes.has(attribute):
		return {}
	return _attributes[attribute].metadata

## Gets all attribute names
func get_attribute_names() -> Array[String]:
	var a: Array[String] = []
	for key in _attributes.keys():
		a.append(key)
	return a

## Checks if an attribute exists
func has_attribute(attribute: String) -> bool:
	return _attributes.has(attribute)

## Checks if a property exists in an attribute
func has_property(attribute: String, property: String) -> bool:
	var info = get_property_info(attribute, property)
	return info != null
#endregion


#region Helper Functions
## Generates a cache key for a property
func _get_cache_key(attribute: String, property: String) -> String:
	return "%s.%s" % [attribute, property]

## Invalidates cache for a specific property
func _invalidate_property_cache(attribute: String, property: String) -> void:
	if _cache:
		_cache.invalidate(_get_cache_key(attribute, property))

## Invalidates cache for an entire attribute
func _invalidate_attribute_cache(attribute: String) -> void:
	if not _cache or not _attributes.has(attribute):
		return
	
	var category_info = _attributes[attribute]
	for prop_info in category_info.properties:
		_invalidate_property_cache(attribute, prop_info.name)

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

## Helper method to create a property builder for an attribute
static func create_property(name: String) -> PropertyResult.PropertyInfoBuilder:
	return PropertyResult.PropertyInfo.create(name)
