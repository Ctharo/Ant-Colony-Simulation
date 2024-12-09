## Manages evaluation and caching across components
class_name EvaluationSystem
extends Resource

#region Properties
## Dictionary of cached values, keyed by component id
var _cache: Dictionary = {}

## Dictionary of evaluation timestamps, keyed by component id
var _cache_timestamps: Dictionary = {}

## Dictionary of component dependencies
var _dependencies: Dictionary = {}

## Dictionary of registered components
var _components: Dictionary = {}

## Base node for evaluations
var base_node: Node

## Logger instance
var logger: Logger
#endregion

#region Initialization
func _init() -> void:
	logger = Logger.new("evaluation_system", DebugLogger.Category.LOGIC)
#endregion

#region Public Methods
## Initialize the evaluation system
func initialize(p_base_node: Node) -> void:
	base_node = p_base_node

## Register a component with the evaluation system
func register_component(component: Resource, id: String) -> void:
	_components[id] = component
	_dependencies[id] = []
	logger.trace("Registered component: %s" % id)

## Add a dependency between components
func add_dependency(dependent_id: String, dependency_id: String) -> void:
	if not dependency_id in _dependencies[dependent_id]:
		_dependencies[dependent_id].append(dependency_id)
		logger.trace("Added dependency: %s -> %s" % [dependent_id, dependency_id])

## Get cached value for a component
func get_cached_value(id: String) -> Variant:
	if id in _cache:
		return _cache[id]
	return null

## Set cached value for a component
func set_cached_value(id: String, value: Variant) -> void:
	_cache[id] = value
	_cache_timestamps[id] = Time.get_unix_time_from_system()
	logger.trace("Cached value for %s: %s" % [id, str(value)])

## Check if component needs reevaluation
func needs_evaluation(id: String) -> bool:
	# If no cache exists, needs evaluation
	if not id in _cache:
		return true
		
	# Check if any dependencies are newer than our cache
	var our_timestamp = _cache_timestamps[id]
	for dependency_id in _dependencies[id]:
		if dependency_id in _cache_timestamps:
			if _cache_timestamps[dependency_id] > our_timestamp:
				return true
	
	return false

## Invalidate cache for a component and its dependents
func invalidate(id: String) -> void:
	logger.trace("Invalidating cache for: %s" % id)
	_invalidate_recursive(id, {})

## Get all components that depend on given component
func get_dependents(id: String) -> Array:
	var dependents = []
	for component_id in _dependencies.keys():
		if id in _dependencies[component_id]:
			dependents.append(component_id)
	return dependents
#endregion

#region Private Methods
## Recursively invalidate cache for component and dependents
func _invalidate_recursive(id: String, visited: Dictionary) -> void:
	if id in visited:
		return
		
	visited[id] = true
	_cache.erase(id)
	_cache_timestamps.erase(id)
	
	# Invalidate all dependents
	for dependent_id in get_dependents(id):
		_invalidate_recursive(dependent_id, visited)
#endregion
