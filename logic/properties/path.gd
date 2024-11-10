class_name Path
extends RefCounted

var attribute: String
var property: String
var full: String : get = _get_full_path

func _init(attribute_name, property_name):
	attribute = attribute_name
	property = property_name

func _get_full_path() -> String:
	return attribute.to_lower() + "." + property.to_lower()

static func parse(full_path: String) -> Path:
	return Path.new(full_path.get_slice(".", 0), full_path.get_slice(".", 1))
