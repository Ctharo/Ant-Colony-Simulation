## Caches property values for performance
class_name PropertyCache
extends RefCounted

var values: Dictionary = {}
var valid_until: Dictionary = {}
var default_ttl: float = 0.5  # Half second default TTL

func get_cached(path: String) -> Variant:
	if not values.has(path) or Time.get_ticks_msec() > valid_until[path]:
		return null
	return values[path]

func cache_value(path: String, value: Variant, ttl: float = -1.0) -> void:
	values[path] = value
	valid_until[path] = Time.get_ticks_msec() + (ttl if ttl > 0 else default_ttl) * 1000

func clear() -> void:
	values.clear()
	valid_until.clear()
