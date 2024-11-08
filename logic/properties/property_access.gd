class_name PropertyAccess
extends RefCounted

#region Signals
signal property_changed(path: String, old_value: Variant, new_value: Variant)
#endregion

#region Member Variables
var _properties_container: PropertiesContainer
var _attributes_container: AttributesContainer
var _cache: PropertyCache
#endregion

func _init(owner: Object, use_caching: bool = true) -> void:
	_cache = PropertyCache.new() if use_caching else null
	_properties_container = PropertiesContainer.new(owner)
	_attributes_container = AttributesContainer.new(owner, _properties_container)
	
	# Connect to container signals
	_properties_container.property_changed.connect(_on_property_changed)
	_attributes_container.property_changed.connect(_on_attribute_property_changed)

#region Attribute Management
## Registers a new attribute with the system
func register_attribute(attribute: Attribute) -> PropertyResult:
	if not attribute:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.TYPE_MISMATCH,
			"Attribute cannot be null"
		)
	
	# Register the attribute
	var result = _attributes_container.register_attribute(attribute)
	
	# If successful, invalidate any cached values for this attribute's properties
	if result.success():
		_invalidate_attribute_cache(attribute.name)
	
	return result

## Removes an attribute from the system
func remove_attribute(name: String) -> PropertyResult:
	if not _attributes_container.has_attribute(name):
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.PROPERTY_NOT_FOUND,
			"Attribute '%s' doesn't exist" % name
		)
	
	_invalidate_attribute_cache(name)
	return _attributes_container.remove_attribute(name)
#endregion

#region Core Property Access
func get_property(path: String) -> PropertyResult:
	var parsed_path = PropertyResult.PropertyPath.parse(path)
	if not parsed_path:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.INVALID_PATH,
			"Invalid property path: %s" % path
		)
	
	# Check cache first if enabled
	if _cache and _cache.has_valid_cache(path):
		return PropertyResult.new(_cache.get_cached(path))
	
	# Get property based on container type
	var result: PropertyResult
	if parsed_path.container == "properties":
		result = _properties_container.get_property(parsed_path.property)
	else:  # attributes
		result = _get_attribute_property(parsed_path)
	
	# Cache successful results
	if result.success() and _cache:
		_cache.cache_value(path, result.value)
	
	return result

func set_property(path: String, value: Variant) -> PropertyResult:
	var parsed_path = PropertyResult.PropertyPath.parse(path)
	if not parsed_path:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.INVALID_PATH,
			"Invalid property path: %s" % path
		)
	
	# Set property based on container type
	var result: PropertyResult
	if parsed_path.container == "properties":
		result = _properties_container.set_property(parsed_path.property, value)
	else:  # attributes
		result = _set_attribute_property(parsed_path, value)
	
	# Invalidate cache on successful set
	if result.success() and _cache:
		_invalidate_cache(path)
		# Invalidate dependent properties
		_invalidate_dependencies(path)
	
	return result
#endregion

#region Attribute Access Methods
func get_attribute_properties(attribute: String) -> Array[PropertyResult]:
	return _attributes_container.get_attribute_properties(attribute)

func get_attribute_names() -> Array[String]:
	return _attributes_container.get_attribute_names()

func get_categorized_properties() -> PropertyResult:
	var categories = {}
	
	for attribute in get_attribute_names():
		var properties = get_attribute_properties(attribute)
		if not properties.is_empty():
			categories[attribute] = properties
			
	return PropertyResult.new(categories)
#endregion

#region Helper Methods
func _get_attribute_property(path: PropertyResult.PropertyPath) -> PropertyResult:
	if not _attributes_container.has_attribute(path.category):
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.PROPERTY_NOT_FOUND,
			"Attribute '%s' not found" % path.category
		)
	
	var prop_info = _attributes_container.get_property_info(path.category, path.property)
	if not prop_info:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.PROPERTY_NOT_FOUND,
			"Property '%s' not found in attribute '%s'" % [path.property, path.category]
		)
	
	return _properties_container.get_property(path.property)

func _set_attribute_property(path: PropertyResult.PropertyPath, value: Variant) -> PropertyResult:
	if not _attributes_container.has_attribute(path.category):
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.PROPERTY_NOT_FOUND,
			"Attribute '%s' not found" % path.category
		)
	
	var prop_info = _attributes_container.get_property_info(path.category, path.property)
	if not prop_info:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.PROPERTY_NOT_FOUND,
			"Property '%s' not found in attribute '%s'" % [path.property, path.category]
		)
	
	return _properties_container.set_property(path.property, value)

func _invalidate_cache(path: String) -> void:
	if _cache:
		_cache.invalidate(path)

func _invalidate_attribute_cache(attribute: String) -> void:
	if not _cache:
		return
		
	for property in get_attribute_properties(attribute):
		var prop_info = property.property_info
		if prop_info:
			_invalidate_cache("attributes.%s.%s" % [attribute, prop_info.name])

func _invalidate_dependencies(path: String) -> void:
	if not _cache:
		return
		
	var parsed_path = PropertyResult.PropertyPath.parse(path)
	if parsed_path:
		var dependencies = _properties_container.get_dependent_properties(
			parsed_path.property,
			path if parsed_path.container == "attributes" else ""
		)
		for dep in dependencies:
			_invalidate_cache(dep)
#endregion

#region Signal Handlers
func _on_property_changed(name: String, old_value: Variant, new_value: Variant) -> void:
	property_changed.emit("properties." + name, old_value, new_value)

func _on_attribute_property_changed(attribute: String, property: String, old_value: Variant, new_value: Variant) -> void:
	property_changed.emit("attributes.%s.%s" % [attribute, property], old_value, new_value)
#endregion
