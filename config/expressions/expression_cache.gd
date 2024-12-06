## Cache manager for expression results
class_name ExpressionCache
extends Resource

var _cache: Dictionary = {}
var _dependencies: Dictionary = {}

## Cache an expression result
func cache_result(expression_id: String, result: Variant) -> void:
	_cache[expression_id] = result

## Get cached result
func get_cached_result(expression_id: String) -> Variant:
	return _cache.get(expression_id)

## Clear cache for an expression and its dependents
func invalidate_cache(expression_id: String) -> void:
	_cache.erase(expression_id)
	# Invalidate dependent expressions
	if _dependencies.has(expression_id):
		for dependent in _dependencies[expression_id]:
			invalidate_cache(dependent)

## Register dependency relationship
func register_dependency(dependent_id: String, dependency_id: String) -> void:
	if not _dependencies.has(dependency_id):
		_dependencies[dependency_id] = []
	_dependencies[dependency_id].append(dependent_id)

## Clear all cached results
func clear_cache() -> void:
	_cache.clear()
