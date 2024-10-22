class_name AdvancedObjectDefinitions

class Property:
	var name: String
	var type: String  # "number", "boolean", "string", "object", "method"
	var return_type: String  # Used for methods and objects to specify what they return or reference

	func _init(p_name: String, p_type: String, p_return_type: String = ""):
		name = p_name
		type = p_type
		return_type = p_return_type

class ObjectType:
	var name: String
	var properties: Array[Property]
	var is_multiple: bool

	func _init(p_name: String, p_properties: Array[Property], p_is_multiple: bool = false):
		name = p_name
		properties = p_properties
		is_multiple = p_is_multiple

static var object_types: Dictionary = {
	"Foods": ObjectType.new("Foods", [
		Property.new("in_view", "method", "Foods"),
		Property.new("in_reach", "method", "Foods"),
		Property.new("mass", "method", "number"),
		Property.new("positions", "method", "Array[Vector2]"),
		Property.new("carried_by", "object", "Array[Ant]")
	], true),
	"Food": ObjectType.new("Food", [
		Property.new("is_in_view", "method", "bool"),
		Property.new("is_in_reach", "method", "bool"),
		Property.new("mass", "method", "number"),
		Property.new("position", "method", "Vector2"),
		Property.new("carried_by", "object", "Ant")
	], true),
	"Pheromones": ObjectType.new("Pheromones", [
		Property.new("sensed", "method", "Pheromones"),
		Property.new("concentration_vectors", "method", "Array[Vector2]"),
		Property.new("positions", "method", "Array[Vector2]"),
		Property.new("types", "method", "Array[String]"),
		Property.new("emitted_by", "object", "Ants")
	], true),
	"Pheromone": ObjectType.new("Pheromone", [
		Property.new("is_sensed", "method", "bool"),
		Property.new("concentration", "method", "number"),
		Property.new("position", "method", "Vector2"),
		Property.new("type", "method", "String"),
		Property.new("emitted_by", "object", "Ant")
	], true),
	"Ants": ObjectType.new("Ants", [
		Property.new("positions", "object", "Array[Vector2]"),
		Property.new("types", "object", "Array[Vector2]")
	]),
	"Ant": ObjectType.new("Ant", [
		Property.new("position", "object", "Vector2"),
		Property.new("colony", "object", "Colony"),
		Property.new("energy", "object", "Energy"),
		Property.new("health", "object", "Health"),
		Property.new("type", "string")
	]),
	"Energy": ObjectType.new("Energy", [
		Property.new("current", "number"),
		Property.new("max", "number"),
		Property.new("percentage", "method", "number")
	]),
	"Health": ObjectType.new("Health", [
		Property.new("current", "number"),
		Property.new("max", "number"),
		Property.new("percentage", "method", "number")
	])
}

static func get_object_types() -> Array[String]:
	return object_types.keys()

static func get_properties_for_type(object_type: String) -> Array[Property]:
	return object_types[object_type].properties if object_types.has(object_type) else []

static func is_multiple(object_type: String) -> bool:
	return object_types[object_type].is_multiple if object_types.has(object_type) else false

static func get_return_type(object_type: String, property_name: String) -> String:
	var properties = get_properties_for_type(object_type)
	for prop in properties:
		if prop.name == property_name:
			return prop.return_type
	return ""
