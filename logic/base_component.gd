class_name BaseComponent
extends Resource

#region Properties
## Unique identifier for this component
var id: String
## Component logger instance
var logger: Logger
## Human readable name
@export var name: String:
	set(value):
		name = value
		id = name.to_snake_case()
#endregion

## Initialize core properties
func _init() -> void:
	if not logger:
		logger = Logger.new(name.to_snake_case(), DebugLogger.Category.LOGIC)

## Initialize with required dependencies
## @param p_entity: The owning entity node
## @param dependencies: Optional dictionary of additional dependencies
func initialize(dependencies: Dictionary = {}) -> void:
	if not name:
		push_error("Component name cannot be empty")
		assert(name, "Component name cannot be empty")
		return


	_setup_dependencies(dependencies)
	_post_initialize()

## Virtual method for child classes to implement additional initialization
func _post_initialize() -> void:
	pass

## Virtual method for setting up additional dependencies
func _setup_dependencies(_dependencies: Dictionary) -> void:
	pass
