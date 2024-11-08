class_name AttributesContainer
extends RefCounted

#region Signals
signal attribute_added(info: PropertyResult.CategoryInfo)
signal attribute_removed(name: String)
signal property_changed(attribute: String, property: String, old_value: Variant, new_value: Variant)
#endregion

#region Member Variables
var _attributes: Dictionary = {}  # name -> CategoryInfo
var _owner: Object
var _property_container: PropertiesContainer
#endregion

func _init(owner: Object, property_container: PropertiesContainer) -> void:
	_owner = owner
	_property_container = property_container

#region Attribute Management
func register_attribute(attribute: Attribute) -> PropertyResult:
	if not attribute:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.TYPE_MISMATCH,
			"Attribute cannot be null"
		)
		
	var name = attribute.name
	
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
	
	var category_info = PropertyResult.CategoryInfo.new(name)
	var properties = attribute.get_properties()
	
	for property in properties:
		var prop_info = property.property_info
		category_info.add_property(prop_info)
	
	_attributes[name] = category_info
	attribute_added.emit(category_info)
	return PropertyResult.new(category_info)

func remove_attribute(name: String) -> PropertyResult:
	if not _attributes.has(name):
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.PROPERTY_NOT_FOUND,
			"Attribute '%s' doesn't exist" % name
		)
	
	_attributes.erase(name)
	attribute_removed.emit(name)
	return PropertyResult.new(null)
#endregion

#region Property Information
func get_property_info(attribute: String, property: String) -> PropertyResult.PropertyInfo:
	if not _attributes.has(attribute):
		return null
	
	var category_info = _attributes[attribute]
	for prop_info in category_info.properties:
		if prop_info.name == property:
			return prop_info
	return null

func get_attribute_metadata(attribute: String) -> Dictionary:
	if not _attributes.has(attribute):
		return {}
	return _attributes[attribute].metadata

func get_attribute_names() -> Array[String]:
	var names: Array[String] = []
	for key in _attributes.keys():
		names.append(key)
	return names

func has_attribute(attribute: String) -> bool:
	return _attributes.has(attribute)

func has_property(attribute: String, property: String) -> bool:
	return get_property_info(attribute, property) != null

func get_attribute_properties(attribute: String) -> Array[PropertyResult]:
	if not _attributes.has(attribute):
		return []
	
	var results: Array[PropertyResult] = []
	var category_info = _attributes[attribute]
	
	for prop_info in category_info.properties:
		results.append(_property_container.get_property(prop_info.name))
	
	return results
#endregion

static func create_property(name: String) -> PropertyResult.PropertyInfoBuilder:
	return PropertyResult.PropertyInfo.create(name)
