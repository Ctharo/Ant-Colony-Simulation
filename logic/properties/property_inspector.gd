class_name PropertyInspector
extends RefCounted

## Structure to hold property metadata
class PropertyInfo:
	var name: String
	var type: String
	var value: Variant
	var can_write: bool
	var description: String
	var category: String
	
	func _init(
		p_name: String, 
		p_type: String, 
		p_value: Variant, 
		p_category: String = "",
		p_can_write: bool = false, 
		p_description: String = ""
	):
		name = p_name
		type = p_type
		value = p_value
		category = p_category
		can_write = p_can_write
		description = p_description
	
	func to_dict() -> Dictionary:
		return {
			"name": name,
			"type": type,
			"value": value,
			"category": category,
			"can_write": can_write,
			"description": description
		}

## Structure to hold category metadata
class CategoryInfo:
	var name: String
	var properties: Array[PropertyInfo]
	
	func _init(p_name: String):
		name = p_name
		properties = []
	
	func add_property(property: PropertyInfo) -> void:
		properties.append(property)
	
	func to_dict() -> Dictionary:
		return {
			"name": name,
			"properties": properties.map(func(p): return p.to_dict())
		}

## Structure for complete object information
class ObjectInfo:
	var direct_categories: Array[CategoryInfo]
	var attributes: Array[CategoryInfo]
	
	func _init():
		direct_categories = []
		attributes = []
	
	func add_direct_category(category: CategoryInfo) -> void:
		direct_categories.append(category)
	
	func add_attribute_category(category: CategoryInfo) -> void:
		attributes.append(category)
	
	func to_dict() -> Dictionary:
		return {
			"direct_categories": direct_categories.map(func(c): return c.to_dict()),
			"attributes": attributes.map(func(c): return c.to_dict())
		}

## Get complete object information using containers
static func get_object_info(ant: Ant) -> ObjectInfo:
	if ant == null:
		return null
	
	var info = ObjectInfo.new()
	
	# Process properties from PropertiesContainer
	process_properties_container(ant.properties_container, info)
	
	# Process attributes from AttributesContainer
	process_attributes_container(ant.attributes_container, info)
	
	return info

## Process properties from PropertiesContainer
static func process_properties_container(container: PropertiesContainer, info: ObjectInfo) -> void:
	if not container:
		return
	
	for category_name in container.get_categories():
		var category_info = _process_category(
			container,
			category_name,
			func(prop_name: String) -> Dictionary:
				return {
					"type": container.get_property_type(prop_name),
					"value": container.get_property(prop_name),
					"can_write": container.is_property_writable(prop_name),
					"description": container.get_property_description(prop_name)
				}
		)
		info.add_direct_category(category_info)

## Process attributes from AttributesContainer
static func process_attributes_container(container: AttributesContainer, info: ObjectInfo) -> void:
	if not container:
		return
	
	var attributes = container.get_attributes()
	for attr_name in attributes:
		var category_info = _process_category(
			container,
			attr_name,
			func(prop_name: String) -> Dictionary:
				var prop_info = container.get_attribute_properties(attr_name)[prop_name]
				return {
					"type": container.get_property_type(attr_name, prop_name),
					"value": prop_info["value"],
					"can_write": prop_info.get("writable", true),
					"description": prop_info.get("description", "")
				}
		)
		info.add_attribute_category(category_info)

## Helper function to process a category's properties
static func _process_category(
	container: Object,
	category_name: String,
	property_info_getter: Callable
) -> CategoryInfo:
	var category_info = CategoryInfo.new(category_name)
	var properties = []
	
	# Get the appropriate list of properties based on container type
	if container is PropertiesContainer:
		properties = container.get_properties_in_category(category_name)
	elif container is AttributesContainer:
		properties = container.get_attribute_properties(category_name).keys()
	
	# Process each property
	for prop_name in properties:
		var info = property_info_getter.call(prop_name)
		
		category_info.add_property(_create_property_info(
			prop_name,
			info["type"],
			info["value"],
			category_name,
			info["can_write"],
			info["description"]
		))
	
	return category_info

## Helper function to create PropertyInfo from common parameters
static func _create_property_info(
	name: String,
	prop_type: int,
	value: Variant,
	category: String,
	can_write: bool,
	description: String = ""
) -> PropertyInfo:
	return PropertyInfo.new(
		name,
		type_to_string(prop_type),
		value,
		category,
		can_write,
		description
	)

## Convert PropertyType to string
static func type_to_string(type: Component.PropertyType) -> String:
	return Component.type_to_string(type)
