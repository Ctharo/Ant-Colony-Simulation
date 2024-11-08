class_name PropertyAccess
extends RefCounted
## Centralized class for handling property access across different containers
##
## Provides a unified interface for accessing properties from both PropertiesContainer
## and AttributesContainer with consistent error handling and path resolution.

## Stores which properties depend on each property
var _dependency_map: Dictionary = {}  # property_path -> Array[dependent_paths]

#region Member Variables
var _cache: PropertyCache
var _properties_container: PropertiesContainer
var _attributes_container: AttributesContainer
var _use_caching: bool
#endregion

func _init(context: Dictionary, use_caching: bool = true) -> void:
	_use_caching = use_caching
	_cache = PropertyCache.new() if use_caching else null
	_initialize_containers(context)
	_build_dependency_map()
	
# Builds reverse lookup of property dependencies
func _build_dependency_map() -> void:
	_dependency_map.clear()
	
	# Get all properties
	var all_paths = get_available_paths()
	
	# For each property, check its dependencies and build reverse lookup
	for path in all_paths:
		var info = get_property_info(path)
		if info and not info.dependencies.is_empty():
			# For each dependency, add this property as dependent
			for dependency in info.dependencies:
				if not _dependency_map.has(dependency):
					_dependency_map[dependency] = []
				_dependency_map[dependency].append(path)

## Get all properties that depend on a given property
func _get_dependent_properties(path: String) -> Array[String]:
	var dependents: Array[String] = []
	if _dependency_map.has(path):
		dependents.append_array(_dependency_map[path])
		# Recursively get properties that depend on the dependents
		for dependent in _dependency_map[path]:
			dependents.append_array(_get_dependent_properties(dependent))
	return dependents

#region Public Interface
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
	if _use_caching and result.success():
		_invalidate_cache_for_path(path)
	
	return result

## Sets cache time-to-live in seconds
func set_cache_ttl(ttl: float) -> void:
	if _cache:
		_cache.default_ttl = ttl

## Clears all cached values
func clear_cache() -> void:
	if _cache:
		_cache.clear()

## Invalidates cache for a specific path
func invalidate_cache(path: String) -> void:
	if _cache:
		_invalidate_cache_for_path(path)

#region Private Methods
func _initialize_containers(context: Dictionary) -> void:
	var ant = context.get("ant")
	if not ant:
		DebugLogger.warn(DebugLogger.Category.CONTEXT, "Tried to initialize containers without Ant")
		return
	# Initialize containers without caching since PropertyAccess handles it
	_properties_container = PropertiesContainer.new(ant, false)  
	_attributes_container = ant.attributes_container

## Override cache invalidation to handle dependencies
func _invalidate_cache_for_path(path: String) -> void:
	if not _cache:
		return
		
	# Invalidate the specific path
	_cache.invalidate(path)
	
	# Invalidate all dependent properties
	var dependents = _get_dependent_properties(path)
	for dependent in dependents:
		_cache.invalidate(dependent)
		DebugLogger.info(DebugLogger.Category.CONTEXT, "Invalidated dependent property cache: %s (depends on %s)" % [dependent, path])

func _get_related_paths(path: String) -> Array[String]:
	# Implementation depends on your path structure
	# Example: if you have wildcard paths or pattern matching
	var related: Array[String] = []
	var all_paths = get_available_paths()
	
	# Add logic to find related paths that should be invalidated
	# This is just an example - implement based on your needs
	for available_path in all_paths:
		if available_path.begins_with(path.split(".")[0]):
			related.append(available_path)
	
	return related
	
#endregion
## Gets all available property paths
## Returns: Array of valid property paths
func get_available_paths() -> Array[String]:
	var paths: Array[String] = []
	
	# Add direct properties
	if _properties_container:
		paths.append_array(_properties_container.get_properties())
	
	# Add attribute properties
	if _attributes_container:
		for attr in _attributes_container.get_attribute_names():
			var properties = _attributes_container.get_attribute_properties(attr)
			for prop in properties:
				paths.append("%s.%s" % [attr, prop])
	
	return paths

## Gets all properties for an attribute
## Returns: Array[PropertyResult]
func get_attribute_properties(category: String) -> Array[PropertyResult]:
	if not _attributes_container:
		return []
		
	var results: Array[PropertyResult] = []
	
	# Get property infos from container
	var property_infos = _attributes_container.get_attribute_property_infos(category)
	
	# For each property info, get a PropertyResult containing its current value and info
	for property_info in property_infos:
		var path = "%s.%s" % [category, property_info.name]
		var result = get_property(path)  # Use existing get_property to handle caching etc
		if result.success():
			results.append(PropertyResult.new(
				result.value,
				PropertyResult.ErrorType.NONE,
				"",
				property_info
			))
		else:
			results.append(result)  # Keep error information if get_property failed
	
	return results
#endregion

#region Private Methods
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
