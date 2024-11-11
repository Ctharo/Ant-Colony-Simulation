class_name PropertyGroup
extends RefCounted

#region Member Variables
var ant: Ant
var name: String
var metadata: Dictionary = {}
var _root: NestedProperty
#endregion

func _init(_name: String, _ant: Ant = null) -> void:
	name = _name.to_snake_case()
	ant = _ant

	_root = (Property.create(name)
		.as_container()
		.described_as("Property group for %s" % name)
		.build())

	DebugLogger.trace(
		DebugLogger.Category.PROGRAM,
		"Property group initialized: %s" % name,
		{"From": "property_group"}
	)

	_init_properties()

#region Property Management
## Virtual method that derived classes will implement to define their properties
func _init_properties() -> void:
	DebugLogger.warn(
		DebugLogger.Category.PROPERTY,
		"Property group %s did not initialize properties" % [name]
	)

## Registers a new property in this group
func register_property(property: NestedProperty) -> Result:
	if not property:
		return Result.new(
			Result.ErrorType.TYPE_MISMATCH,
			"Cannot register null property"
		)
	_root.add_child(property)
	return Result.new()

## Gets a property by its path relative to this group
func get_property(path: String) -> NestedProperty:
	return _root.get_child_by_path(Path.parse(name + "." + path))

## Gets a property value by its path relative to this group
func get_property_value(path: String) -> Variant:
	var property = get_property(path)
	if property and property.type == NestedProperty.Type.PROPERTY:
		return property.get_value()
	return null

## Sets a property value by its path relative to this group
func set_property_value(path: String, value: Variant) -> Result:
	var property = get_property(path)
	if not property:
		return Result.new(
			Result.ErrorType.NOT_FOUND,
			"Property '%s' doesn't exist" % path
		)
	return property.set_value(value)

## Gets all leaf (value) properties in this group
func get_properties() -> Array[NestedProperty]:
	return _root.get_properties()

## Checks if a property exists at the given path
func has_property(path: String) -> bool:
	return get_property(path) != null

## Gets the root property container for this group
func get_root() -> NestedProperty:
	return _root
#endregion

#region Helper Methods
func _trace(message: String) -> void:
	DebugLogger.trace(
		DebugLogger.Category.PROPERTY,
		message,
		{"From": "property_group"}
	)
#endregion
