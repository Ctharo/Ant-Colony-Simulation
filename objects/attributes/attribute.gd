class_name Attribute
extends Component

var name: String
var ant: Ant

func _init(_ant: Ant, _name: String) -> void:
	super._init()
	ant = _ant
	name = _name.to_snake_case() # Ensures lowercase for lookup
	# Log name set so we know if it is a case mismatch causing a lookup error
	DebugLogger.trace(DebugLogger.Category.PROGRAM, "Name for attribute set as %s" % name)
	properties_container = PropertiesContainer.new(self)
	_init_properties()

# Virtual method that derived classes will implement
func _init_properties() -> void:
	pass
