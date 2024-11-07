class_name Attribute
extends Component

var name: String

func _init(_name: String) -> void:
	name = _name.to_snake_case()
	DebugLogger.trace(DebugLogger.Category.PROGRAM, "Name for attribute set as %s" % name)
	properties_container = PropertiesContainer.new(self)
	_init_properties()

# Virtual method that derived classes will implement
func _init_properties() -> void:
	pass
