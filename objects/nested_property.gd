class_name NestedProperty
extends RefCounted

enum Type {
	PROPERTY,  # Leaf node with a value
	CONTAINER  # Branch node with children
}

#region Member Variables
var name: String
var type: Type
var value_type: Property.Type  # Only used if type is PROPERTY
var getter: Callable
var setter: Callable
var dependencies: Array[String]
var description: String
var children: Dictionary  # name -> NestedProperty, only used if type is CONTAINER
var parent: NestedProperty
var attribute: String
#endregion

class Builder:
	var name: String
	var type: Type
	var value_type: Property.Type
	var getter: Callable
	var setter: Callable
	var dependencies: Array[String]
	var description: String
	var children: Array[NestedProperty]
	var attribute: String

	func _init(p_name: String) -> void:
		name = p_name.to_lower()

	func as_container() -> Builder:
		type = Type.CONTAINER
		return self

	func as_property(p_type: Property.Type) -> Builder:
		type = Type.PROPERTY
		value_type = p_type
		return self

	func with_getter(p_getter: Callable) -> Builder:
		getter = p_getter
		return self

	func with_setter(p_setter: Callable) -> Builder:
		setter = p_setter
		return self

	func with_attribute(p_attribute: String) -> Builder:
		attribute = p_attribute
		return self

	func with_dependencies(p_dependencies: Array[String]) -> Builder:
		dependencies = p_dependencies
		return self

	func with_child(child: NestedProperty) -> Builder:
		children.append(child)
		return self

	func described_as(p_description: String) -> Builder:
		description = p_description
		return self

	func build() -> NestedProperty:
		var prop := NestedProperty.new(name, type, value_type, attribute, getter, setter, dependencies, description)
		for child in children:
			prop.add_child(child)
		return prop

func _init(p_name: String, p_type: Type, p_value_type: Property.Type, p_attribute: String,
		p_getter: Callable = Callable(), p_setter: Callable = Callable(),
		p_dependencies: Array[String] = [], p_description: String = "") -> void:
	name = p_name
	type = p_type
	value_type = p_value_type
	getter = p_getter
	setter = p_setter
	dependencies = p_dependencies
	description = p_description
	attribute = p_attribute
	children = {}

static func create(name: String) -> Builder:
	return Builder.new(name)

func add_child(child: NestedProperty) -> void:
	if type != Type.CONTAINER:
		push_error("Cannot add child to non-container property")
		return
	child.parent = self
	children[child.name] = child

func get_child(path: String) -> NestedProperty:
	var parts = path.split(".", true, 1)
	var child_name = parts[0]

	if not children.has(child_name):
		return null

	if parts.size() == 1:
		return children[child_name]

	return children[child_name].get_child(parts[1])

func get_value() -> Variant:
	if type != Type.PROPERTY:
		push_error("Cannot get value of container property")
		return null
	return getter.call()

func set_value(value: Variant) -> Result:
	if type != Type.PROPERTY:
		return Result.new(
			Result.ErrorType.TYPE_MISMATCH,
			"Cannot set value of container property"
		)
	if not Property.is_valid_type(value, value_type):
		return Result.new(
			Result.ErrorType.TYPE_MISMATCH,
			"Invalid value type"
		)
	setter.call(value)
	return Result.new()

func get_full_path() -> String:
	if parent == null:
		return name
	return parent.get_full_path() + "." + name

#region Helper Methods
static func is_valid_getter(p_getter: Callable) -> bool:
	if not p_getter.is_valid() or not p_getter.get_object() or p_getter.get_method().is_empty():
		return false
	return p_getter.get_argument_count() == 0 and p_getter.get_object().has_method(p_getter.get_method())

static func is_valid_setter(p_setter: Callable) -> bool:
	if not p_setter.is_valid() or not p_setter.get_object() or p_setter.get_method().is_empty():
		return false
	return p_setter.get_argument_count() == 1 and p_setter.get_object().has_method(p_setter.get_method())
#endregion
