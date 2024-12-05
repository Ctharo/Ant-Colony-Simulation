class_name PropertyNode
extends RefCounted

enum Type { VALUE, CONTAINER }

var name: String
var type: Type
var path: Path
var value_type: Property.Type
var getter: Callable
var setter: Callable
var dependencies: Array[Path]
var description: String
var children: Dictionary = {}
var parent: PropertyNode
var entity: Node
var config: PropertyResource

func _init(
	p_path: Path,
	p_type: Type,
	p_entity: Node = null,
	p_config: PropertyResource = null,
	p_value_type: Property.Type = Property.Type.UNKNOWN,
	p_getter: Callable = Callable(),
	p_setter: Callable = Callable(),
	p_dependencies: Array[Path] = [],
	p_description: String = ""
) -> void:
	path = p_path
	name = path.get_property()
	type = p_type
	entity = p_entity
	config = p_config
	value_type = p_value_type
	getter = p_getter
	setter = p_setter
	dependencies = p_dependencies
	description = p_description

func has_valid_accessor(check_setter: bool = false) -> bool:
	var has_valid = Property.is_valid_getter(getter)
	if check_setter:
		has_valid = has_valid and Property.is_valid_setter(setter)
	return has_valid

func get_value() -> Variant:
	return getter.call() if has_valid_accessor() else null

func set_value(value: Variant) -> Result:
	if not Property.is_valid_type(value, value_type):
		return Result.new(
			Result.ErrorType.TYPE_MISMATCH,
			"Invalid value type for property: %s" % path.full
		)

	setter.call(value)
	return Result.new()

func find_node(search_path: Path) -> PropertyNode:
	if search_path.equals(path):
		return self

	if not search_path.is_descendant_of(path):
		return null

	var next_part = search_path.parts[path.get_depth()]
	return children.get(next_part, null).find_node(search_path) if children.has(next_part) else null

func add_child(child: PropertyNode) -> void:
	if type != Type.CONTAINER:
		push_error("Cannot add child to value node: %s" % path.full)
		return

	if not child:
		push_error("Cannot add null child to node: %s" % path.full)
		return

	if children.has(child.name):
		push_error("Child already exists with name: %s" % child.name)
		return

	child.parent = self
	children[child.name] = child

func remove_child(child_name: String) -> void:
	if not children.has(child_name):
		push_error("No child found with name: %s" % child_name)
		return

	var child = children[child_name]
	child.parent = null
	children.erase(child_name)
