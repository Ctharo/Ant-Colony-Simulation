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
var _attributes: Dictionary = {}  # name -> CategoryInfo
var _cache: PropertyCache
var _owner: Object
#endregion

func _init(owner: Object, use_caching: bool = true) -> void:
	_owner = owner
	_cache = PropertyCache.new() if use_caching else null

#region Attribute Management
## Registers a new attribute with properties using PropertyInfo builders
## Returns: PropertyResult with the created attribute info
## Registers a new attribute by automatically collecting its exposed properties
func register_attribute(attribute: Attribute) -> PropertyResult:
	var name = attribute.attribute_name
	
	# Validate attribute doesn't exist
	if _attributes.has(name):
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.DUPLICATE_PROPERTY,
			"Attribute '%s' already exists" % name
		)
	
	# Create category info for the attribute
	var category_info = PropertyResult.CategoryInfo.new(name)
	
	# Get properties exposed by the attribute
	var properties = attribute.get_exposed_properties()
	
	# Add all properties to the category
	for prop_info in properties:
		category_info.add_property(prop_info)
	
	_attributes[name] = category_info
	attribute_added.emit(category_info)
	return PropertyResult.new(category_info)

### Alternative registration method using dictionary format for backward compatibility
#func register_attribute_from_dict(
	#name: String,
	#properties: Dictionary,
	#metadata: Dictionary = {}
#) -> PropertyResult:
	#var prop_infos: Array[PropertyResult.PropertyInfo] = []
	#
	#for prop_name in properties:
		#var prop_data = properties[prop_name]
		#
		#var builder = PropertyResult.PropertyInfo.create(prop_name)\
			#.of_type(prop_data.get("type", Component.PropertyType.UNKNOWN))\
			#.in_category(name)\
			#.described_as(prop_data.get("description", ""))
			#
		#if prop_data.get("writable", true):
			#builder.with_setter(Callable())
			#
		#prop_infos.append(builder.build(prop_data.get("value")))
	#
	#return register_attribute(name, prop_infos, metadata)	
	
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
## Gets a property value from an attribute
func get_property_value(attribute: String, property: String) -> PropertyResult:
	# Get property info first
	var prop_info = get_property_info(attribute, property)
	if not prop_info:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.PROPERTY_NOT_FOUND,
			"Property '%s' not found in attribute '%s'" % [property, attribute]
		)
	
	var cache_key = _get_cache_key(attribute, property)
	
	# Check cache if enabled
	if _cache and _cache.has_valid_cache(cache_key):
		return PropertyResult.new(_cache.get_cached(cache_key))
	
	# Update cache
	if _cache:
		_cache.cache_value(cache_key, prop_info.value)
	
	return PropertyResult.new(prop_info.value)

## Sets a property value in an attribute
func set_property_value(attribute: String, property: String, value: Variant) -> PropertyResult:
	# Get property info first
	var prop_info = get_property_info(attribute, property)
	if not prop_info:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.PROPERTY_NOT_FOUND,
			"Property '%s' not found in attribute '%s'" % [property, attribute]
		)
	
	# Validate property is writable
	if not prop_info.writable:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.INVALID_SETTER,
			"Property '%s' in attribute '%s' is read-only" % [property, attribute]
		)
	
	# Validate value type
	if not _is_valid_type(value, prop_info.type):
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.TYPE_MISMATCH,
			"Invalid type for property '%s' in attribute '%s'" % [property, attribute]
		)
	
	var old_value = prop_info.value
	prop_info.value = value
	
	# Invalidate cache
	_invalidate_property_cache(attribute, property)
	
	property_changed.emit(attribute, property, old_value, value)
	return PropertyResult.new(value)
#endregion

#region Property Information
## Gets information about all properties in an attribute
func get_attribute_properties(attribute: String) -> Dictionary:
	if not _attributes.has(attribute):
		return {}
	
	var result = {}
	var category_info = _attributes[attribute]
	
	for prop_info in category_info.properties:
		result[prop_info.name] = prop_info.to_dict()
	
	return result

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
func get_attributes() -> Array[String]:
	return _attributes.keys()

## Checks if an attribute exists
func has_attribute(attribute: String) -> bool:
	return _attributes.has(attribute)

## Checks if a property exists in an attribute
func has_property(attribute: String, property: String) -> bool:
	var info = get_property_info(attribute, property)
	return info != null
#endregion

#region Cache Management
## Sets the cache time-to-live in seconds
func set_cache_ttl(ttl: float) -> void:
	if _cache:
		_cache.default_ttl = ttl

## Invalidates cache for a specific property in an attribute
func invalidate_property_cache(attribute: String, property: String) -> void:
	_invalidate_property_cache(attribute, property)

## Invalidates cache for all properties in an attribute
func invalidate_attribute_cache(attribute: String) -> void:
	_invalidate_attribute_cache(attribute)

## Invalidates all caches
func invalidate_all_caches() -> void:
	if _cache:
		_cache.clear()
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
