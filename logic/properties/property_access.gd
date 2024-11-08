class_name PropertyAccess
extends RefCounted
## Centralized class for handling property access across different containers
##
## Provides a unified interface for accessing properties from both PropertiesContainer
## and AttributesContainer with consistent error handling and path resolution.

#region Signals
signal attribute_registered(info: PropertyResult.CategoryInfo)
signal attribute_removed(name: String)
signal property_changed(path: String, old_value: Variant, new_value: Variant)
#endregion

#region Member Variables
## Cache instance for property values
var _cache: PropertyCache

## Container for direct properties
var _properties_container: PropertiesContainer

## Container for attribute-based properties
var _attributes_container: AttributesContainer

## Whether to use caching for property access
var _use_caching: bool

## Maps property paths to their dependent properties
var _dependency_map: Dictionary = {}  # property_path -> Array[dependent_paths]

## Category-specific cache durations
var _category_cache_ttl: Dictionary = {}

## Reference to owner object
var _owner: Object
#endregion

#region Initialization
func _init(ant: Ant, use_caching: bool = true) -> void:
	_owner = ant
	if not _owner:
		DebugLogger.error(DebugLogger.Category.CONTEXT, "PropertyAccess initialized without owner")
		return
		
	_use_caching = use_caching
	_cache = PropertyCache.new() if use_caching else null
	_initialize_containers()
	_build_dependency_map()

## Initialize property containers
func _initialize_containers() -> void:
	_properties_container = PropertiesContainer.new(_owner)
	_attributes_container = AttributesContainer.new(_owner)
	
	if _attributes_container:
		# Connect to attribute container signals
		_attributes_container.attribute_added.connect(
			func(info): attribute_registered.emit(info)
		)
		_attributes_container.attribute_removed.connect(
			func(name): attribute_removed.emit(name)
		)
		_attributes_container.property_changed.connect(
			func(attr, prop, old_val, new_val):
				property_changed.emit(
					"%s.%s" % [attr, prop],
					old_val,
					new_val
				)
		)
#endregion

#region Property Access
## Gets the actual value of a property
## Returns: Variant - The direct value of the property
func get_property_value(path: String) -> Variant:
	var result = get_property(path)
	return result.value if result.success() else null

## Gets property with full result information
## Returns: PropertyResult containing value and error information
func get_property(path: String) -> PropertyResult:
	var parsed_path = PropertyResult.PropertyPath.parse(path)
	if not parsed_path:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.INVALID_PATH,
			"Invalid property path format: %s" % path
		)
	
	if parsed_path.container == "properties":
		if not _properties_container:
			return _error_no_container("Properties")
		return _properties_container.get_property(parsed_path.property)
	else:
		if not _attributes_container:
			return _error_no_container("Attributes")
		return _attributes_container.get_attribute_property(
			parsed_path.category,
			parsed_path.property
		)

## Sets a property value and handles cache invalidation
func set_property(path: String, value: Variant) -> PropertyResult:
	var parsed_path = PropertyResult.PropertyPath.parse(path)
	if not parsed_path:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.INVALID_PATH,
			"Invalid property path format: %s" % path
		)
	
	var result = _set_property_value(parsed_path, value)
	
	if _use_caching and result.success():
		_invalidate_cache_for_path(path)
	
	return result

## Gets property metadata and definition
## Returns: PropertyResult.PropertyInfo or null if not found
func get_property_info(path: String) -> PropertyResult.PropertyInfo:
	var parsed_path = PropertyResult.PropertyPath.parse(path)
	if not parsed_path:
		return null
	
	if parsed_path.container == "properties":
		if not _properties_container:
			return null
		return _properties_container.get_property_info(parsed_path.property)
	else:
		if not _attributes_container:
			return null
		return _attributes_container.get_property_info(
			parsed_path.category,
			parsed_path.property
		)
#endregion

#region Property Discovery
## Gets all available property paths
## Returns: Array of valid property paths
func get_available_paths() -> Array[String]:
	var paths: Array[String] = []
	
	if _properties_container:
		paths.append_array(_properties_container.get_properties())
	
	if _attributes_container:
		for attr in _attributes_container.get_attribute_names():
			var properties = _attributes_container.get_attribute_properties(attr)
			for prop in properties:
				paths.append("%s.%s" % [attr, prop])
	
	return paths

## Gets all properties for an attribute
## Returns: Array[PropertyResult]
func get_attribute_properties(category: String) -> Array[PropertyResult]:
	# Validate inputs
	if category.is_empty():
		return [PropertyResult.new(
			null,
			PropertyResult.ErrorType.PROPERTY_NOT_FOUND,
			"Category name cannot be empty"
		)]
		
	if not _attributes_container:
		return [PropertyResult.new(
			null,
			PropertyResult.ErrorType.NO_CONTAINER,
			"Attributes container not configured"
		)]
		
	var property_infos = _attributes_container.get_attribute_property_infos(category)
	var results: Array[PropertyResult] = []
	
	DebugLogger.trace(
		DebugLogger.Category.PROPERTY,
		"Retrieving %d properties for category %s" % [
			property_infos.size(),
			category
		]
	)
	
	for property_info in property_infos:
		var path = "%s.%s" % [category, property_info.name]
		var result = get_property(path)
		results.append(
			PropertyResult.new(
				result.value if result.success() else null,
				result.error_type,
				result.error_message,
				property_info
			)
		)
	
	return results
#endregion

#region Attribute Registration
## Register a new attribute
## Returns: PropertyResult with the created attribute info
func register_attribute(attribute: Attribute) -> PropertyResult:
	# Validate input
	if not attribute:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.TYPE_MISMATCH,
			"Attribute cannot be null"
		)
		
	if not _attributes_container:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.NO_CONTAINER,
			"Attributes container not configured"
		)
	
	DebugLogger.trace(
		DebugLogger.Category.PROPERTY,
		"Registering attribute %s" % attribute.name
	)
	
	var result = _attributes_container.register_attribute(attribute)
	
	if result.success():
		_build_dependency_map()
		
	return result

## Remove an attribute
## Returns: PropertyResult
func remove_attribute(name: String) -> PropertyResult:
	if not _attributes_container:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.NO_CONTAINER,
			"Attributes container not available"
		)
		
	var result = _attributes_container.remove_attribute(name)
	
	if result.success():
		_build_dependency_map()  # Rebuild dependency map after removal
		
	return result

## Get all registered attributes
func get_attribute_names() -> Array[String]:
	if not _attributes_container:
		return []
	return _attributes_container.get_attribute_names()

## Check if an attribute is registered
func has_attribute(name: String) -> bool:
	if not _attributes_container:
		return false
	return _attributes_container.has_attribute(name)
#endregion

#region Dependency Management
## Builds reverse lookup of property dependencies
func _build_dependency_map() -> void:
	_dependency_map.clear()
	
	var all_paths = get_available_paths()
	for path in all_paths:
		var info = get_property_info(path)
		if info and not info.dependencies.is_empty():
			for dependency in info.dependencies:
				if not _dependency_map.has(dependency):
					_dependency_map[dependency] = []
				_dependency_map[dependency].append(path)

## Get all properties that depend on a given property
func _get_dependent_properties(path: String) -> Array[String]:
	var dependents: Array[String] = []
	var parts = path.split(".")
	
	if parts.size() != 2:
		return dependents
		
	var container = parts[0]
	var property_name = parts[1]
	
	if _properties_container:
		var property_dependents = _properties_container.get_dependent_properties(
			property_name,
			path
		)
		for dependent in property_dependents:
			dependents.append("properties.%s" % dependent)
	
	if _attributes_container:
		var attribute_dependents = _attributes_container.get_dependent_properties(
			container,
			property_name,
			path
		)
		dependents.append_array(attribute_dependents)
	
	var indirect_dependents: Array[String] = []
	for dependent in dependents:
		indirect_dependents.append_array(_get_dependent_properties(dependent))
	dependents.append_array(indirect_dependents)
	
	return dependents

## Validates that all cross-container dependencies exist
func _validate_cross_dependencies() -> void:
	if not _properties_container or not _attributes_container:
		return
		
	for dependency in _properties_container.get_external_dependencies():
		if not _path_exists(dependency):
			DebugLogger.warn(
				DebugLogger.Category.PROPERTY,
				"Cross-property dependency not found: %s" % dependency
			)
	
	for dependency in _attributes_container.get_external_dependencies():
		if not _path_exists(dependency):
			DebugLogger.warn(
				DebugLogger.Category.PROPERTY,
				"Cross-property dependency not found: %s" % dependency
			)
#endregion

#region Cache Configuration
## Sets default cache time-to-live in seconds
func set_cache_ttl(ttl: float) -> void:
	if _cache:
		_cache.default_ttl = ttl
		
## Set cache TTL for a specific category
func set_category_cache_ttl(category: String, ttl: float) -> void:
	_category_cache_ttl[category] = ttl
	
## Get cache TTL for a category
func get_category_cache_ttl(category: String) -> float:
	return _category_cache_ttl.get(category, _cache.default_ttl if _cache else 0.0)

## Clear category-specific cache settings
func clear_category_cache_settings() -> void:
	_category_cache_ttl.clear()

## Invalidates cache for a specific path
func invalidate_cache(path: String) -> void:
	if _cache:
		_invalidate_cache_for_path(path)

## Override cache invalidation to handle dependencies
func _invalidate_cache_for_path(path: String) -> void:
	if not _cache:
		return
		
	_cache.invalidate(path)
	
	var dependents = _get_dependent_properties(path)
	for dependent in dependents:
		_cache.invalidate(dependent)
		DebugLogger.info(
			DebugLogger.Category.CONTEXT,
			"Invalidated dependent property cache: %s (depends on %s)" % [dependent, path]
		)

## Gets all related paths that should be invalidated
func _get_related_paths(path: String) -> Array[String]:
	var related: Array[String] = []
	var all_paths = get_available_paths()
	
	for available_path in all_paths:
		if available_path.begins_with(path.split(".")[0]):
			related.append(available_path)
	
	return related
#endregion

#region Helper Methods
## Sets a property value based on parsed path
func _set_property_value(path: PropertyResult.PropertyPath, value: Variant) -> PropertyResult:
	if path.container == "properties":
		if not _properties_container:
			return PropertyResult.new(
				null,
				PropertyResult.ErrorType.NO_CONTAINER,
				"Properties container not available"
			)
		return _properties_container.set_property_value(path.property, value)
	
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
## Create cache key for property
func _get_cache_key(path: String) -> String:
	return path

## Get category from property path
func _get_category_from_path(path: String) -> String:
	var parts = path.split(".")
	return parts[0] if parts.size() > 0 else ""

## Check if path exists
func _path_exists(path: String) -> bool:
	var parsed_path = PropertyResult.PropertyPath.parse(path)
	if not parsed_path:
		return false
		
	if parsed_path.container == "properties":
		return _properties_container.has_property(parsed_path.property)
	else:
		return _attributes_container.has_attribute_property(
			parsed_path.category,
			parsed_path.property
		)
#endregion

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
