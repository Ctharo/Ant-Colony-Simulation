class_name PropertyAccess
extends RefCounted

#region Signals
signal property_changed(path: String, old_value: Variant, new_value: Variant)
#endregion

#region Member Variables
var _attributes_container: AttributesContainer
var _cache: Cache
#endregion

func _init(owner: Object, use_caching: bool = true) -> void:
	_cache = Cache.new() if use_caching else null
	_attributes_container = AttributesContainer.new(owner)

#region Attribute Management
## Registers a new attribute with the system
func register_attribute(attribute: Attribute) -> Result:
	# Register the attribute
	var result = _attributes_container.register_attribute(attribute)
	# If successful, invalidate any cached values for this attribute's properties
	if result.success():
		_invalidate_attribute_cache(attribute.name)
	return result

## Removes an attribute from the system
func remove_attribute(name: String) -> Result:
	return _attributes_container.remove_attribute(name)
#endregion

#region Core Property Access
func get_property(path: Path) -> Property:
	return _get_attribute_property(path)

func get_property_from_str(path: String) -> Property:
	if not Helper.is_full_path(path):
		return null
	var p: Path = Path.parse(path)
	return _get_attribute_property(p)

## Must use if wanting to have caching
func get_property_value(path: Path) -> Variant:
	# Check cache first if enabled
	if _cache and _cache.has_valid_cache(path):
		return _cache.get_cached(path)
	var value: Variant = _attributes_container.get_property_value(path.attribute, path.property)
	var result = _cache.cache_value(path, value)
	if result.is_error():
		_error("Problem caching value for %s due to %s" % [path, result.error_msg])
	return value
#endregion

#region Attribute Access Methods
func get_attribute_properties(attribute: String) -> Array[Property]:
	return _attributes_container.get_attribute_properties(attribute)

func get_attribute_names() -> Array[String]:
	return _attributes_container.get_attribute_names()
#endregion

#region Helper Methods
func _get_attribute_property(path: Path) -> Property:
	return _attributes_container.get_property(path.attribute, path.property)

func _invalidate_cache(path: Path) -> void:
	if _cache:
		_cache.invalidate(path)

func _invalidate_attribute_cache(attribute: String) -> void:
	if not _cache:
		return

	for property in get_attribute_properties(attribute):
		var path: Path = property.path
		_invalidate_cache(path)
#endregion

func _trace(message: String) -> void:
	DebugLogger.trace(DebugLogger.Category.PROPERTY,
		message,
		{"From": "property_access"}
	)

func _warn(message: String) -> void:
	DebugLogger.warn(DebugLogger.Category.PROPERTY,
		message
	)

func _error(message: String) -> void:
	DebugLogger.error(DebugLogger.Category.PROPERTY,
		message
	)
