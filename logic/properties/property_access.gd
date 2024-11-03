class_name PropertyAccess
extends RefCounted
## Centralized class for handling property access across different containers
##
## Provides a unified interface for accessing properties from both PropertiesContainer
## and AttributesContainer with consistent error handling and path resolution.

#region Member Variables
var _cache: PropertyCache
var _properties_container: PropertiesContainer
var _attributes_container: AttributesContainer
#endregion

func _init(context: Dictionary) -> void:
	_cache = PropertyCache.new()
	_initialize_containers(context)

#region Public Interface
## Gets a property value using a property path
## Returns: PropertyResult with value or error information
func get_property(path: String) -> PropertyResult:
	# Parse and validate path
	var parsed_path = PropertyResult.PropertyPath.parse(path)
	if not parsed_path:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.INVALID_PATH,
			"Invalid property path format: %s" % path
		)
	
	# Check cache first
	if _cache.has_valid_cache(path):
		return PropertyResult.new(_cache.get_cached(path))
	
	# Get property value based on path type
	var result = _get_property_value(parsed_path)
	
	# Cache successful results
	if result.success():
		_cache.cache_value(path, result.value)
	
	return result

## Sets a property value using a property path
## Returns: PropertyResult indicating success or error
func set_property(path: String, value: Variant) -> PropertyResult:
	# Parse and validate path
	var parsed_path = PropertyResult.PropertyPath.parse(path)
	if not parsed_path:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.INVALID_PATH,
			"Invalid property path format: %s" % path
		)
	
	# Set property value based on path type
	var result = _set_property_value(parsed_path, value)
	
	# Invalidate cache on successful set
	if result.success():
		_cache.invalidate(path)
	
	return result

## Gets property information using a property path
## Returns: PropertyInfo or null if not found
func get_property_info(path: String) -> PropertyResult.PropertyInfo:
	var parsed_path = PropertyResult.PropertyPath.parse(path)
	if not parsed_path:
		return null
	
	if parsed_path.container == "properties":
		return _properties_container.get_property_info(parsed_path.property)
	else:
		return _attributes_container.get_property_info(
			parsed_path.category,
			parsed_path.property
		)

## Gets all available property paths
## Returns: Array of valid property paths
func get_available_paths() -> Array[String]:
	var paths: Array[String] = []
	
	# Add direct properties
	if _properties_container:
		paths.append_array(_properties_container.get_properties())
	
	# Add attribute properties
	if _attributes_container:
		for attr in _attributes_container.get_attributes():
			var properties = _attributes_container.get_attribute_properties(attr)
			for prop in properties:
				paths.append("%s.%s" % [attr, prop])
	
	return paths

## Gets categorized property information
## Returns: Dictionary mapping categories to property information
func get_categorized_properties() -> Dictionary:
	var result = {}
	
	# Add direct properties by category
	if _properties_container:
		for category in _properties_container.get_categories():
			result[category] = {
				"type": "properties",
				"properties": _properties_container.get_properties_in_category(category)
			}
	
	# Add attribute properties
	if _attributes_container:
		for attr in _attributes_container.get_attributes():
			result[attr] = {
				"type": "attributes",
				"properties": _attributes_container.get_attribute_properties(attr).keys()
			}
	
	return result

## Sets cache time-to-live in seconds
func set_cache_ttl(ttl: float) -> void:
	_cache.default_ttl = ttl

## Clears all cached values
func clear_cache() -> void:
	_cache.clear()
#endregion

#region Private Methods
## Initializes property containers from context
func _initialize_containers(context: Dictionary) -> void:
	var ant = context.get("ant")
	if ant:
		_properties_container = ant.properties_container
		_attributes_container = ant.attributes_container

## Gets a property value based on parsed path
func _get_property_value(path: PropertyResult.PropertyPath) -> PropertyResult:
	# Handle direct properties
	if path.container == "properties":
		if not _properties_container:
			return PropertyResult.new(
				null,
				PropertyResult.ErrorType.NO_CONTAINER,
				"Properties container not available"
			)
		return _properties_container.get_property_value(path.property)
	
	# Handle attribute properties
	if not _attributes_container:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.NO_CONTAINER,
			"Attributes container not available"
		)
	
	return _attributes_container.get_property_value(
		path.category,
		path.property
	)

## Sets a property value based on parsed path
func _set_property_value(path: PropertyResult.PropertyPath, value: Variant) -> PropertyResult:
	# Handle direct properties
	if path.container == "properties":
		if not _properties_container:
			return PropertyResult.new(
				null,
				PropertyResult.ErrorType.NO_CONTAINER,
				"Properties container not available"
			)
		return _properties_container.set_property_value(path.property, value)
	
	# Handle attribute properties
	if not _attributes_container:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.NO_CONTAINER,
			"Attributes container not available"
		)
	
	return _attributes_container.set_property_value(
		path.category,
		path.property,
		value
	)

## Formats property information for display or debugging
static func format_property_info(info: PropertyResult.PropertyInfo) -> String:
	if not info:
		return "<null>"
	
	var formatted = "%s: %s" % [
		info.name,
		PropertyResult.format_value(info.value)
	]
	
	if not info.description.is_empty():
		formatted += " (%s)" % info.description
	
	return formatted
#endregion

#region Error Handling
## Creates a "not found" error result
static func _error_not_found(path: String) -> PropertyResult:
	return PropertyResult.new(
		null,
		PropertyResult.ErrorType.PROPERTY_NOT_FOUND,
		"Property not found: %s" % path
	)

## Creates a "container not available" error result
static func _error_no_container(container_type: String) -> PropertyResult:
	return PropertyResult.new(
		null,
		PropertyResult.ErrorType.NO_CONTAINER,
		"%s container not available" % container_type
	)
#endregion
