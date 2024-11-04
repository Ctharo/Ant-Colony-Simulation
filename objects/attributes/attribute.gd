class_name Attribute
extends Component

var attribute_name: String

func _init(name: String) -> void:
	attribute_name = name
	properties_container = PropertiesContainer.new(self)
	_init_properties()

# Virtual method that derived classes will implement
func _init_properties() -> void:
	pass
