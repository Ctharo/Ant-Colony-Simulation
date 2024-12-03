class_name StrengthResource
extends PropertyResource
## Resource for managing strength-related properties

#region Inner Classes
class LevelResource extends PropertyResource:
	func _init() -> void:
		setup(
			"level",
			PropertyNode.Type.VALUE,
			"Base strength level of the entity",
			{},
			Property.Type.INT
		)
	
	func create_getter(entity: Node) -> Callable:
		return func(): return entity.level
	
	func create_setter(entity: Node) -> Callable:
		return func(value): 
			if value <= 0:
				return
			entity.level = value

class CarryFactorResource extends PropertyResource:
	func _init() -> void:
		setup(
			"carry_factor",
			PropertyNode.Type.VALUE,
			"Base carrying capacity factor",
			{},
			Property.Type.FLOAT,
			["strength.base.level"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func():
			var level = entity.get_property_value("strength.base.level")
			return float(level) * Strength.STRENGTH_FACTOR
#endregion

func _init() -> void:
	setup(
		"strength",
		PropertyNode.Type.CONTAINER,
		"Strength management",
		{
			"base": create_base_config(),
			"derived": create_derived_config()
		}
	)

func create_base_config() -> PropertyResource:
	return PropertyResource.create_container(
		"base",
		"Base strength attributes",
		{
			"level": LevelResource.new()
		}
	)

func create_derived_config() -> PropertyResource:
	return PropertyResource.create_container(
		"derived",
		"Values derived from strength",
		{
			"carry_factor": CarryFactorResource.new()
		}
	)
