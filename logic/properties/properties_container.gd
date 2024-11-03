class_name PropertiesContainer
extends RefCounted

# Add to existing signals
signal category_added(category: String)
signal category_removed(category: String)
signal property_added(name: String, type: int)
signal property_removed(name: String)
signal property_changed(name: String, old_value: Variant, new_value: Variant)

# Add category management
var _categories: Dictionary = {}  # category_name -> Array[String] (property names)

## Add a new category
func add_category(category: String) -> void:
	if not _categories.has(category):
		_categories[category] = []
		category_added.emit(category)

## Remove a category and its property assignments (does not remove properties)
func remove_category(category: String) -> void:
	if _categories.has(category):
		_categories.erase(category)
		category_removed.emit(category)

## Assign property to category
func assign_to_category(property_name: String, category: String) -> void:
	if not has_property(property_name):
		push_warning("Property '%s' doesn't exist" % property_name)
		return
		
	if not _categories.has(category):
		add_category(category)
	
	# Remove from any existing category
	for cat in _categories.keys():
		_categories[cat].erase(property_name)
	
	_categories[category].append(property_name)

## Get all categories
func get_categories() -> Array:
	return _categories.keys()

## Get properties in category
func get_properties_in_category(category: String) -> Array:
	return _categories.get(category, [])
		
## Structure to store property metadata and access methods
class PropertyData:
	var getter: Callable
	var setter: Callable
	var type: Component.PropertyType
	var description: String
	var cached_value: Variant
	var cache_valid: bool
	
	func _init(
		p_getter: Callable, 
		p_type: Component.PropertyType, 
		p_setter: Callable = Callable(),
		p_description: String = ""
	) -> void:
		getter = p_getter
		setter = p_setter
		type = p_type
		description = p_description
		cache_valid = false

var _properties: Dictionary = {}
var _owner: Object  # Reference to owning object
var _use_caching: bool = true

func _init(owner: Object, use_caching: bool = true) -> void:
	_owner = owner
	_use_caching = use_caching

#region Property Management
## Expose a new property with getter and optional setter
func expose_property(
	name: String, 
	getter: Callable, 
	type: Component.PropertyType, 
	setter: Callable = Callable(),
	description: String = "",
	category: String = ""  # Add optional category parameter
) -> void:
	if _properties.has(name):
		push_warning("Property '%s' already exists" % name)
		return
	
	# Validate the getter before adding
	if not _is_valid_getter(getter):
		push_warning("Invalid getter for property '%s'" % name)
		return
		
	# Only validate setter if one is provided
	if setter.is_valid() and not _is_valid_setter(setter):
		push_warning("Invalid setter for property '%s'" % name)
		return
		
	_properties[name] = PropertyData.new(getter, type, setter, description)
	
	# Assign to category if specified
	if not category.is_empty():
		assign_to_category(name, category)
		
	property_added.emit(name, type)

#region Validation
## Check if a getter callable is valid and properly configured
func _is_valid_getter(getter: Callable) -> bool:
	# Check if the callable has a valid object and method
	if not getter.is_valid() or not getter.get_object() or getter.get_method().is_empty():
		return false
	
	## Check argument count
	#if getter.get_argument_count() != 0:
		#push_warning("Getter must take no arguments")
		#return false
	
	# Try to get the method info
	var object = getter.get_object()
	var method = getter.get_method()
	
	# Check if the method exists on the object
	if not object.has_method(method):
		push_warning("Method '%s' not found on object" % method)
		return false
	
	return true

## Check if a setter callable is valid and properly configured
func _is_valid_setter(setter: Callable) -> bool:
	# Check if the callable has a valid object and method
	if not setter.is_valid() or not setter.get_object() or setter.get_method().is_empty():
		return false
	
	# Check argument count
	if setter.get_argument_count() != 1:
		push_warning("Setter must take exactly one argument")
		return false
	
	# Try to get the method info
	var object = setter.get_object()
	var method = setter.get_method()
	
	# Check if the method exists on the object
	if not object.has_method(method):
		push_warning("Method '%s' not found on object" % method)
		return false
	
	return true

## Debug helper to print callable information
func _debug_callable(callable: Callable) -> void:
	print("Callable Debug Info:")
	print("- Is valid: ", callable.is_valid())
	print("- Object: ", callable.get_object())
	print("- Method: ", callable.get_method())
	print("- Argument count: ", callable.get_argument_count())
	if callable.get_object():
		print("- Object class: ", callable.get_object().get_class())
		print("- Has method: ", callable.get_object().has_method(callable.get_method()))
#endregion

#region Property Management
## Remove an exposed property
func remove_property(name: String) -> void:
	if not _properties.has(name):
		push_warning("Property '%s' doesn't exist" % name)
		return
		
	_properties.erase(name)
	property_removed.emit(name)

## Check if a property exists
func has_property(name: String) -> bool:
	return _properties.has(name)

## Get list of all exposed property names
func get_property_names() -> Array:
	return _properties.keys() as Array
#endregion

#region Property Access
## Get a property's value
func get_property(name: String) -> Variant:
	if not has_property(name):
		push_warning("Property '%s' doesn't exist" % name)
		return null
		
	var prop_data: PropertyData = _properties[name]
	
	# Check cache if enabled
	if _use_caching and prop_data.cache_valid:
		return prop_data.cached_value
	
	var value = "N/A"
	# Get fresh value
	if prop_data.getter.get_argument_count() == 0:
		value = prop_data.getter.call()
	
	# Update cache
	if _use_caching:
		prop_data.cached_value = value
		prop_data.cache_valid = true
		
	return value

## Set a property's value
## Returns true if successful
func set_property(name: String, value: Variant) -> bool:
	if not has_property(name):
		push_warning("Property '%s' doesn't exist" % name)
		return false
		
	var prop_data: PropertyData = _properties[name]
	if not prop_data.setter.is_valid():
		push_warning("Property '%s' is read-only" % name)
		return false
		
	# Validate type
	if not _is_valid_type(value, prop_data.type):
		push_warning("Invalid type for property '%s'" % name)
		return false
		
	var old_value = get_property(name)
	prop_data.setter.call(value)
	
	# Invalidate cache
	if _use_caching:
		prop_data.cache_valid = false
		
	property_changed.emit(name, old_value, value)
	return true

## Invalidate cache for a specific property
func invalidate_cache(name: String) -> void:
	if has_property(name):
		_properties[name].cache_valid = false

## Invalidate all property caches
func invalidate_all_caches() -> void:
	for prop_data in _properties.values():
		prop_data.cache_valid = false
#endregion

#region Property Information
## Get property type
func get_property_type(name: String) -> Component.PropertyType:
	if not has_property(name):
		return Component.PropertyType.UNKNOWN
	return _properties[name].type

## Get property description
func get_property_description(name: String) -> String:
	if not has_property(name):
		return ""
	return _properties[name].description

## Check if property is writable
func is_property_writable(name: String) -> bool:
	if not has_property(name):
		return false
	return _properties[name].setter.is_valid()

## Get all property information
func get_properties_info() -> Dictionary:
	var info = {}
	for name in _properties:
		var prop_data: PropertyData = _properties[name]
		info[name] = {
			"type": prop_data.type,
			"description": prop_data.description,
			"writable": prop_data.setter.is_valid(),
			"value": get_property(name)
		}
	return info
#endregion

#region Helper Functions
## Validate getter callable
func _validate_getter(getter: Callable) -> void:
	if not getter.is_valid():
		push_error("Invalid getter callable")
	if getter.get_argument_count() != 0:
		push_error("Getter must take no arguments")

## Validate setter callable
func _validate_setter(setter: Callable) -> void:
	if not setter.is_valid():
		push_error("Invalid setter callable")
	if setter.get_argument_count() != 1:
		push_error("Setter must take exactly one argument")

## Check if value matches expected type
func _is_valid_type(value: Variant, expected_type: Component.PropertyType) -> bool:
	match expected_type:
		Component.PropertyType.BOOL:
			return typeof(value) == TYPE_BOOL
		Component.PropertyType.INT:
			return typeof(value) == TYPE_INT
		Component.PropertyType.FLOAT:
			return typeof(value) == TYPE_FLOAT
		Component.PropertyType.STRING:
			return typeof(value) == TYPE_STRING
		Component.PropertyType.VECTOR2:
			return value is Vector2
		Component.PropertyType.VECTOR3:
			return value is Vector3
		Component.PropertyType.ARRAY:
			return value is Array
		Component.PropertyType.DICTIONARY:
			return value is Dictionary
		Component.PropertyType.OBJECT:
			return value is Object
	return false
#endregion
