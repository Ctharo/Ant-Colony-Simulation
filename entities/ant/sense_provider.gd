class_name SenseProvider
extends Resource

var _ant: Ant
var _cache: Dictionary = {}
var _cache_valid: bool = false

func _init(ant: Ant) -> void:
	_ant = ant

func invalidate_cache() -> void:
	_cache_valid = false

func get_food_in_view() -> Array:
	if not _cache_valid or not _cache.has("food_in_view"):
		_cache.food_in_view = _collect_food_in_view()
	return _cache.food_in_view

func _collect_food_in_view() -> Array:
	var foods = []
	for food in _ant.sight_area.get_overlapping_bodies():
		if food is Food and food.is_available:
			foods.append(food)
	return foods
