class_name AntPropertyGroup
extends PropertyGroup

#region Member Variables
var ant: Ant
#endregion

func _init(p_name: String, p_ant: Ant = null) -> void:
	log_from = p_name.to_snake_case() if not p_name.is_empty() else "property_group"
	log_category = DebugLogger.Category.PROPERTY
	name = p_name.to_snake_case()
	ant = p_ant
	_root = (Property.create(name)
		.as_container()
		.described_as("Property group for %s" % name)
		.build())
	_init_properties()
