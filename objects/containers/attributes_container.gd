class_name AttributesContainer
extends RefCounted

#region Signals
signal attribute_added(attribute_name: String)
signal attribute_removed(name: String)
signal property_changed(attribute_name: String, property_name: String, old_value: Variant, new_value: Variant)
#endregion

#region Member Variables
var _attributes: Dictionary = {}  # name -> Attribute
var _dependency_map: Dictionary = {} # full path -> Array[Property]
var _owner: Object
#endregion

func _init(owner: Object) -> void:
	_owner = owner


#region Attribute Management
func register_attribute(attribute: Attribute) -> Result:
	if not attribute:
		return Result.new(
			Result.ErrorType.TYPE_MISMATCH,
			"Cannot register null attribute"
		)
	var name = attribute.name
	if _attributes.has(name):
		var msg = "Attribute '%s' already exists" % name
		DebugLogger.error(
			DebugLogger.Category.ATTRIBUTE,
			"Failed to register attribute %s: %s" % [name, msg]
		)

	_setup_property_dependencies(attribute)

	_attributes[name] = attribute
	_trace("Added attribute %s to attribute container" % name)
	attribute_added.emit(attribute)
	return Result.new()

func remove_attribute(name: String) -> Result:
	if not has_attribute(name):
		return Result.new(
			Result.ErrorType.NOT_FOUND,
			"Attribute '%s' doesn't exist" % name
		)
	_attributes.erase(name)
	attribute_removed.emit(name)
	return Result.new()
#endregion

#region Property Information
func get_attribute(attribute_name: String) -> Attribute:
	if not has_attribute(attribute_name):
		return null
	return _attributes[attribute_name]

func get_property(attribute_name: String, property_name: String) -> Property:
	if not has_property(attribute_name, property_name):
		return null
	return get_attribute(attribute_name).get_property(property_name)

func get_property_value(attribute_name: String, property_name: String) -> Variant:
	if not has_property(attribute_name, property_name):
		return null
	return get_property(attribute_name, property_name).value

func get_attribute_properties(attribute_name: String) -> Array[Property]:
	if not has_attribute(attribute_name):
		return []
	return get_attribute(attribute_name).get_properties()

func get_attribute_names() -> Array[String]:
	var names: Array[String] = []
	for key in _attributes.keys():
		names.append(key)
	return names

func has_attribute(attribute_name: String) -> bool:
	return _attributes.has(attribute_name)

func has_property(attribute_name: String, property_name: String) -> bool:
	if not has_attribute(attribute_name):
		return false
	if not get_attribute(attribute_name).has_property(property_name):
		return false
	return true
#endregion

#region Dependencies
func _setup_property_dependencies(attribute: Attribute) -> void:
	var map = _dependency_map
	for property in attribute.get_properties():
		var key: String = property.path.full
		if not map.has(key):
			map[key] = []
		for dependency in property.dependencies:
			var path: Path
			if Helper.is_full_path(dependency):
				path = Path.parse(dependency)
			else:
				# Assumes if not full path then local dependency (i.e., same attribute)
				path = Path.new(attribute.name, dependency)
			map[key].append(path.full)

func _cleanup_property_dependencies(attribute: Attribute) -> void:
	var map = _dependency_map
	for property in attribute.get_properties():
		var key: String = property.path.full
		# Remove as a dependent
		map.erase(key)
		# Remove from other properties' dependencies
		for deps in map.values():
			deps.erase(key)
#endregion

#region Helpers
func _trace(message: String) -> void:
	DebugLogger.trace(DebugLogger.Category.PROPERTY,
		message,
		{"From": "attributes_container"}
	)

func _warn(message: String) -> void:
	DebugLogger.warn(DebugLogger.Category.PROPERTY,
		message
	)

func _error(message: String) -> void:
	DebugLogger.error(DebugLogger.Category.PROPERTY,
		message
	)
#endregion
