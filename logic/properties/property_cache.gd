## Caches property values for performance
class_name PropertyCache
extends RefCounted

var values: Dictionary = {}
var valid_until: Dictionary = {}
var default_ttl: float = 0.5  # Half second default TTL

func get_cached(path: Path) -> Variant:
	if not has_valid_cache(path):
		return null
	return values[path.full]

func cache_value(path: Path, value: Variant, ttl: float = -1.0) -> Result:
	values[path.full] = value
	valid_until[path.full] = Time.get_ticks_msec() + (ttl if ttl > 0 else default_ttl) * 1000
	return Result.new()

func invalidate(path: Path) -> Result:
	if values.has(path.full):
		values.erase(path.full)
	if valid_until.has(path.full):
		valid_until.erase(path.full)
	return Result.new()

func clear() -> void:
	values.clear()
	valid_until.clear()

func has_valid_cache(path: Path) -> bool:
	if not values.has(path.full) or Time.get_ticks_msec() > valid_until[path.full]:
		return false
	return true
