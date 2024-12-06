class_name PropertyValue
extends PropertyNode

## Type of the property value
var value_type: Property.Type

## Getter function
var getter: Callable

## Setter function
var setter: Callable

## Dependencies for this property
@export var dependencies: Array[Path]

## Initialize the property value
func _init(
	p_path: Path,
	p_entity: Node = null,
	p_value_type: Property.Type = Property.Type.UNKNOWN,
	p_getter: Callable = Callable(),
	p_setter: Callable = Callable(),
	p_dependencies: Array[String] = [],
	p_description: String = ""
) -> void:
	# Call parent constructor with VALUE type
	super._init(p_path, Type.VALUE, p_entity, p_description)

	value_type = p_value_type
	getter = p_getter
	setter = p_setter
	for dependency in p_dependencies:
		dependencies.append(validate_path(dependency))

## Get the current value
func get_value() -> Variant:
	return getter.call()

## Set a new value
func set_value(value: Variant) -> Result:
	if not Property.is_valid_type(value, value_type):
		return Result.new(
			Result.ErrorType.TYPE_MISMATCH,
			"Invalid value type for property: %s" % path.full
		)
	setter.call(value)
	return Result.new()

func validate_path(path: Variant) -> Path:
	match typeof(path):
		TYPE_STRING:
			if path.is_empty():
				return null
			return Path.parse(path)
		TYPE_OBJECT:
			if path is Path:
				return path
			return null
		_:
			return null

func has_valid_accessor() -> bool:
	return getter.is_valid()
