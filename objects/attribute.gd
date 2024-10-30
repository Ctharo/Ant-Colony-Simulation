class_name Attribute
extends RefCounted

# Stores property metadata and access methods
var _exposed_properties = {}

func expose_property(name: String, getter: Callable, setter: Callable = Callable()) -> void:
	_exposed_properties[name] = {
		"getter": getter,
		"setter": setter if setter.is_valid() else Callable()
	}

func get_property(name: String):
	if not _exposed_properties.has(name):
		return null
	return _exposed_properties[name]["getter"].call()

func set_property(name: String, value) -> bool:
	if not _exposed_properties.has(name) or _exposed_properties[name]["setter"].is_null():
		return false
	_exposed_properties[name]["setter"].call(value)
	return true

func get_exposed_properties() -> Dictionary:
	var result = {}
	for prop_name in _exposed_properties:
		result[prop_name] = get_property(prop_name)
	return result
