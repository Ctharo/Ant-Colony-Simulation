class_name Colony
extends Node2D
## TODO: Add Behaviors such as spawning x number of ants if Condition


@onready var collision_area: Area2D = $CollisionArea
@export var dirt_color = Color(Color.SADDLE_BROWN, 0.8)  # Earthy brown
@export var darker_dirt = Color(Color.BROWN, 0.9)   # Darker brown for depth

#region Member Variables
## Colony radius in units
@export var radius: float = 60.0:
	set(value):
		radius = value
		queue_redraw()  # Redraw when radius changes

var ants_in_colony: Array[Ant] = []
## Inner radius as a ratio of the main radius
var inner_radius_ratio: float = 0.33
## Collection of food resources
var foods: Foods = Foods.new()
## Ants belonging to this colony
var ants: Ants = Ants.new([])
## Whether this colony is highlighted
var is_highlighted: bool = false
## Whether to highlight all ants belonging to this colony
var highlight_ants_enabled: bool = false

## Whether to show navigation agent debug visualization
var nav_debug_enabled: bool = false
var heatmap_enabled: bool = false :
	set(value):
		heatmap_enabled = value
		heatmap.debug_draw(self, value)

#endregion

var logger: Logger
var heatmap: HeatmapManager
#region Initialization
func _init() -> void:
	logger = Logger.new("colony", DebugLogger.Category.ENTITY)

func _ready() -> void:
	heatmap = get_tree().get_first_node_in_group("heatmap")
	heatmap.register_entity(self)


func _physics_process(delta: float) -> void:
	for ant in ants_in_colony:
		if ant.energy_level < ant.energy_max:
			ant.energy_level += 10 * delta

func _exit_tree() -> void:
	heatmap.unregister_entity(self)
	delete_all()

func delete_all():
	for ant in ants:
		if ant != null:
			AntManager.remove_ant(ant)

func get_ants() -> Array:
	return ants.to_array()

func _draw() -> void:
	# Rich brown/dirt color with some transparency
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
	add_child(ant)
	return Result.new()

func store_food(food: Food) -> void:
	food.reparent(self)
	food.stored = true
	food.carried = false
	foods.add_food(food)
	

func spawn_ants(num: int, physics_at_spawn: bool = true) -> Array[Ant]:
	var _ants: Array[Ant] = AntManager.spawn_ants(self, num, physics_at_spawn)
	for ant in _ants:
		randomize()
		add_ant(ant)
		ant.global_rotation = randf_range(-PI, PI)
		var wiggle_x: float = randf_range(-15,15)
		var wiggle_y: float = randf_range(-15,15)
		ant.global_position = global_position + Vector2(wiggle_x, wiggle_y)
	logger.info("Spawned %s %s from %s" % [_ants.size(), "ant" if _ants.size() == 1 else "ants", name])
	return _ants
#endregion


func _on_collision_area_body_entered(body: Node2D) -> void:
	if body is Ant and body.colony == self:
		ants_in_colony.append(body)


func _on_collision_area_body_exited(body: Node2D) -> void:
	if body is Ant and body.colony == self and body in ants_in_colony:
		ants_in_colony.erase(body)
