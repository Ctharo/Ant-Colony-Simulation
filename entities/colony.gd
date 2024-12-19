class_name Colony
extends Node2D

#region Member Variables
## Colony radius in units
@export var radius: float = 30.0:
	set(value):
		radius = value
		queue_redraw()  # Redraw when radius changes
		
## Inner radius as a ratio of the main radius
var inner_radius_ratio: float = 0.33
## Collection of food resources
var foods: Foods
## Ants belonging to this colony
var ants: Ants = Ants.new([])
#endregion

var logger: Logger

#region Initialization
func _init() -> void:
	logger = Logger.new("colony", DebugLogger.Category.ENTITY)

func _ready() -> void:
	HeatmapManager.register_colony(self)
	HeatmapManager.set_debug_draw(self, true)


func _exit_tree() -> void:
	HeatmapManager.unregister_colony(self)
	
func get_navigation_map() -> RID:
	return NavigationServer2D.get_maps()[0]

func get_ants() -> Array:
	return AntManager.by_colony(self).as_array()
	
func _draw() -> void:
	# Rich brown/dirt color with some transparency
	var dirt_color = Color(0.55, 0.27, 0.07, 0.8)  # Earthy brown
	var darker_dirt = Color(0.4, 0.2, 0.05, 0.9)   # Darker brown for depth
	var inner_radius = radius * inner_radius_ratio
	
	# Draw the darker rim first
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, darker_dirt, 3.0)
	draw_arc(Vector2.ZERO, inner_radius, 0, TAU, 32, darker_dirt, 2.0)
	
	# Create points for the filled area
	var points_outer = []
	var points_inner = []
	var num_points = 32
	
	# Create outer circle points
	for i in range(num_points + 1):
		var angle = i * TAU / num_points
		points_outer.append(Vector2(cos(angle), sin(angle)) * radius)
	
	# Create inner circle points (in reverse order)
	for i in range(num_points + 1):
		var angle = (num_points - i) * TAU / num_points
		points_inner.append(Vector2(cos(angle), sin(angle)) * inner_radius)
	
	# Combine points and draw filled polygon
	var points = points_outer + points_inner
	draw_colored_polygon(points, dirt_color)

func add_ant(ant: Ant) -> Result:
	if not ant:
		return Result.new(Result.ErrorType.INVALID_ARGUMENT, "Invalid ant")
	ants.append(ant)
	ant.set_colony(self)
	return Result.new()

func spawn_ants(num: int, physics_at_spawn: bool = false) -> Array[Ant]:
	var _ants: Array[Ant] = AntManager.spawn_ants(self, num, physics_at_spawn)
	for ant in _ants:
		randomize()
		add_ant(ant)
		ant.global_rotation = randf_range(-PI, PI)
		var wiggle_x: float = randf_range(-15,15)
		var wiggle_y: float = randf_range(-15,15)
		ant.global_position = global_position + Vector2(wiggle_x, wiggle_y)
	return _ants
#endregion
