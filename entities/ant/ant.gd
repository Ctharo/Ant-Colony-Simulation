@icon("res://assets/entities/Ant.svg")
class_name Ant
extends CharacterBody2D
## A single colony member: senses the world, follows data-driven behavior
## rules, and falls back to influence-driven wandering.
##
## Architecture overview:
## - [BehaviorManager] evaluates AntRule resources each physics tick; the
##   first matching rule invokes one of the whitelisted ACTION_API methods.
## - [InfluenceManager] provides the default movement when no rule fires.
## - [AntPerception] (own file) owns every spatial/sensor query — area
##   overlaps, nearest-item searches, colony proximity, pheromone sampling.
## - [AntSenses] is the read-only, value-type facade Logic expressions
##   evaluate against (see get_expression_context()); it reads from
##   AntPerception, never from this script's mutating surface.
## - [PheromoneMemory] (own file) accumulates heatmap samples for gradient
##   following; owned by AntPerception.
##
## This script deliberately contains NO derived behavior logic: conditions
## live in Logic resources under user://behavior, and the only hardcoded
## checks left are engine glue (e.g. "is recovery complete" inside
## rest_until_full — a physical fact, not an authored decision).

#region Signals
signal spawned
signal energy_changed
signal died(ant: Ant)
## Emitted when navigation completes (true) or is cancelled (false).
signal movement_completed(success: bool)
#endregion


#region Constants
## Methods that AntAction resources are allowed to invoke. Anything not in
## this list is rejected by BehaviorManager — the safety boundary that makes
## runtime/UI-authored behavior safe.
const ACTION_API: Array[String] = [
	"harvest_food",
	"store_food",
	"rest_until_full",
	"move_to",
	"stop_movement",
]

## Fallback rules (by ResourceLibrary id) preserving default behavior for
## profiles that don't define their own behavior_rules. These are seeded
## into user://behavior by DefaultLibrarySeeder on first run; if the user
## has deleted one, it is simply skipped.
const DEFAULT_RULE_IDS: Array[String] = [
	"harvest_rule",
	"store_rule",
	"rest_rule",
]

const ENERGY_MAX: float = 100.0
const HEALTH_MAX: float = 100.0
const CARRY_MAX: int = 1
## Energy drained per unit of velocity per second while outside the colony.
const ENERGY_DRAIN_FACTOR: float = 0.015
## Extra drain per unit of velocity while carrying food.
const CARRY_DRAIN_FACTOR: float = 0.01
## Smoothing factor for velocity interpolation each physics tick.
const VELOCITY_LERP_WEIGHT: float = 0.15
#endregion


#region Exports
@export var pheromones: Array[Pheromone]
#endregion


#region Identity
## Unique identifier, assigned by AntManager. Re-derives the logger name so
## log lines carry the final id (the _init logger is a pre-assignment fallback).
var id: int:
	set(value):
		id = value
		logger = iLogger.new("ant_%d" % id, DebugLogger.Category.ENTITY)

## Role within the colony, derived from the profile name.
var role: String
var profile: AntProfile
var colony: Colony: set = set_colony
var logger: iLogger
#endregion


#region Vitals
var health_level: float = HEALTH_MAX:
	set(value):
		health_level = clampf(value, 0.0, HEALTH_MAX)
		if health_level == 0.0:
			die()

var energy_level: float = ENERGY_MAX:
	set(value):
		var previous: int = int(energy_level)
		energy_level = clampf(value, 0.0, ENERGY_MAX)
		# Only signal on whole-unit changes to avoid per-frame emission spam.
		if previous != int(energy_level):
			energy_changed.emit()
		if energy_level == 0.0:
			die()

## Health/energy recovered per second while resting.
var resting_rate: float = 20.0
var is_dead: bool = false
## True while rest_until_full() is in progress (read by AntSenses).
var is_resting: bool = false
#endregion


#region Movement & Perception Stats
var movement_rate: float = 25.0

var vision_range: float = 100.0:
	set(value):
		vision_range = value
		if is_inside_tree() and sight_area:
			var shape: CollisionShape2D = sight_area.get_node("CollisionShape2D")
			if shape and shape.shape is CircleShape2D:
				shape.shape.radius = vision_range
#endregion


#region Task State
## True while a blocking action (harvest/store/rest) is running; suspends
## rule evaluation and influence movement in _physics_process.
var doing_task: bool = false

var _carried_food: Food
var is_carrying_food: bool:
	get: return is_instance_valid(_carried_food)

## Profile stored before _ready() when init_profile() is called too early.
var _profile_pending: AntProfile = null
#endregion


#region Components
@onready var influence_manager: InfluenceManager = $InfluenceManager
@onready var nav_agent: NavigationAgent2D = %NavigationAgent2D
@onready var sight_area: Area2D = %SightArea
@onready var reach_area: Area2D = %ReachArea
@onready var mouth_marker: Marker2D = %MouthMarker
var behavior_manager: BehaviorManager
## All spatial/sensor queries (see AntPerception). Created in _init so it is
## always valid; individual queries guard on tree membership themselves.
var perception: AntPerception
## Lazily created read-only facade for Logic expressions.
var _senses: AntSenses
#endregion


#region Lifecycle
func _init() -> void:
	# Fallback logger; replaced with the id-tagged one once id is assigned.
	logger = iLogger.new("ant_unassigned", DebugLogger.Category.ENTITY)
	perception = AntPerception.new(self)


func _ready() -> void:
	_duplicate_area_shapes()

	influence_manager.initialize(self)

	# Apply profile now that influence_manager exists; init_profile() may
	# have run before we entered the tree.
	if _profile_pending:
		_apply_profile_internal(_profile_pending)
		_profile_pending = null
	elif profile:
		_apply_profile_internal(profile)

	_setup_behavior_manager()
	register_to_heatmap()
	_calibrate_reach_radius()

	spawned.emit()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_process_carrying()
	_consume_energy(delta)

	# A blocking action (harvest/store/rest) owns this ant until it clears.
	if doing_task:
		return

	# Data-driven behavior: first matching rule (by priority) acts this tick.
	if behavior_manager and behavior_manager.process_rules():
		return

	# Default fall-through: influence-driven movement.
	_process_movement(delta)


## CircleShape2D resources are shared between scene instances; mutating the
## radius on one ant (e.g. via vision_range) would resize every ant unless
## each instance gets its own copy.
func _duplicate_area_shapes() -> void:
	for area: Area2D in [sight_area, reach_area]:
		var shape_node: CollisionShape2D = area.get_node("CollisionShape2D")
		shape_node.shape = shape_node.shape.duplicate()


func _setup_behavior_manager() -> void:
	behavior_manager = BehaviorManager.new()
	add_child(behavior_manager)
	behavior_manager.initialize(self)
	for rule_id: String in DEFAULT_RULE_IDS:
		var rule: AntRule = ResourceLibrary.get_by_id(ResourceLibrary.KIND_RULE, rule_id)
		if rule:
			behavior_manager.add_rule(rule)
		else:
			logger.warn("Default rule '%s' not found in library (deleted?)" % rule_id)


## Shrinks the reach radius so that food carried at the mouth marker still
## counts as "in reach". Measures a throwaway Food instance because food
## size lives on the scene, not a constant.
func _calibrate_reach_radius() -> void:
	var food: Food = load("res://entities/food/food.tscn").instantiate()
	var reach_shape: CollisionShape2D = reach_area.get_node("CollisionShape2D")
	reach_shape.shape.radius = mouth_marker.position.x - food.get_size()
	food.queue_free()
#endregion


#region Profile
## Applies an [AntProfile]. Safe to call before or after _ready(); if the
## node isn't in the tree yet, application is deferred until _ready().
func init_profile(p_profile: AntProfile) -> void:
	profile = p_profile
	if not is_inside_tree() or not influence_manager:
		_profile_pending = p_profile
		return
	_apply_profile_internal(p_profile)


func _apply_profile_internal(p_profile: AntProfile) -> void:
	if not influence_manager:
		push_error("Cannot apply profile - influence_manager not ready")
		return

	for influence: InfluenceProfile in p_profile.movement_influences:
		influence_manager.add_profile(influence)

	# Profile-defined rules replace the defaults; empty means keep defaults.
	if behavior_manager and not p_profile.behavior_rules.is_empty():
		behavior_manager.clear_rules()
		behavior_manager.add_rules(p_profile.behavior_rules)
#endregion


#region Actions (ACTION_API)
## Picks up the nearest available food within reach, if any.
func harvest_food() -> void:
	doing_task = true

	var food: Food = perception.get_nearest_food_in_reach()
	if is_instance_valid(food) and food.is_available:
		food.set_state(Food.State.CARRIED)
		food.global_position = mouth_marker.global_position
		_carried_food = food

	doing_task = false


## Deposits the carried food at the colony after a fixed delay.
func store_food() -> void:
	if not is_carrying_food:
		return

	doing_task = true
	await get_tree().create_timer(1.0).timeout

	# Validity guard: the ant may have died or left the tree during the await.
	if is_dead or not is_inside_tree():
		doing_task = false
		return

	if is_instance_valid(_carried_food):
		if is_instance_valid(colony):
			colony.store_food(_carried_food)
		else:
			# No colony to store in — release the food rather than orphaning
			# it in the CARRIED state forever.
			_carried_food.set_state(Food.State.AVAILABLE)
	_carried_food = null
	doing_task = false


## Rests in place, recovering health and energy until both are full.
## The completion check is engine glue (a physical fact about recovery), not
## authored behavior — the *decision to start* resting is what belongs in a
## rule condition, and does.
func rest_until_full() -> void:
	doing_task = true
	is_resting = true

	while energy_level < ENERGY_MAX or health_level < HEALTH_MAX:
		await get_tree().create_timer(0.5).timeout
		# Validity guard after await.
		if is_dead or not is_inside_tree():
			break
		_recover_while_resting(0.5)

	is_resting = false
	doing_task = false


## Sets a new navigation target. Returns true (kept for AntAction callers
## that expect a success value).
func move_to(target_pos: Vector2) -> bool:
	nav_agent.set_target_position(target_pos)
	return true


## Cancels the current movement.
func stop_movement() -> void:
	velocity = Vector2.ZERO
	movement_completed.emit(false)
#endregion


#region Per-tick Processing
## Keeps carried food glued to the mouth marker.
func _process_carrying() -> void:
	if is_instance_valid(_carried_food):
		_carried_food.global_position = mouth_marker.global_position
		_carried_food.rotation = rotation


## Drains energy from movement; resting inside the colony is free.
func _consume_energy(delta: float) -> void:
	if not perception.is_colony_in_range():
		energy_level -= calculate_energy_cost(delta)


func calculate_energy_cost(delta: float) -> float:
	var drain: float = ENERGY_DRAIN_FACTOR
	if is_carrying_food:
		drain += CARRY_DRAIN_FACTOR
	return drain * velocity.length() * delta


func _recover_while_resting(delta: float) -> void:
	health_level += resting_rate * delta
	energy_level += resting_rate * delta


## Influence-driven movement: recalculate the target when needed, then steer
## toward the next path position with velocity smoothing.
func _process_movement(delta: float) -> void:
	if not is_instance_valid(nav_agent):
		return

	_process_pheromones(delta)

	if influence_manager.should_recalculate_target():
		influence_manager.update_movement_target()

	var next_pos: Vector2 = nav_agent.get_next_path_position()
	var move_direction: Vector2 = (next_pos - global_position).normalized()
	var target_velocity: Vector2 = move_direction * movement_rate

	target_velocity = velocity.lerp(target_velocity, VELOCITY_LERP_WEIGHT)
	if nav_agent.avoidance_enabled:
		nav_agent.velocity = target_velocity  # agent emits velocity_computed
	else:
		_on_navigation_agent_2d_velocity_computed(target_velocity)


## Each pheromone checks its own emission condition.
func _process_pheromones(delta: float) -> void:
	for pheromone: Pheromone in pheromones:
		pheromone.check_and_emit(self, delta)
#endregion


#region Navigation Callbacks
func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	if safe_velocity.length() > 0.0:
		global_rotation = safe_velocity.angle()
	move_and_slide()


func _on_navigation_agent_2d_target_reached() -> void:
	if velocity != Vector2.ZERO:
		movement_completed.emit(true)


func _on_navigation_agent_2d_path_changed() -> void:
	if nav_agent.debug_enabled:
		show_nav_path(true)


func _on_nav_agent_navigation_finished() -> void:
	pass


func is_navigation_finished() -> bool:
	return nav_agent.is_navigation_finished()


func show_nav_path(enabled: bool) -> void:
	nav_agent.debug_enabled = enabled
#endregion


#region Sensing
## Expressions evaluate against this facade instead of the ant itself, so
## UI-authored Logic can only reach read-only state (see AntSenses).
## All node-returning spatial queries live on [member perception]; code that
## needs Food/Ant/Colony nodes goes through it directly.
func get_expression_context() -> Object:
	if not _senses:
		_senses = AntSenses.new(self)
	return _senses


## Registers self and pheromone heatmap types with [HeatmapManager].
func register_to_heatmap() -> void:
	HeatmapManager.register_entity(self)
	for pheromone: Pheromone in pheromones:
		HeatmapManager.create_heatmap_type(pheromone)
#endregion


#region Colony
func set_colony(p_colony: Colony) -> void:
	if colony != p_colony:
		colony = p_colony
#endregion


#region Death
## Kills this ant. Releases carried food, marks state, and emits [signal died];
## AntManager handles removal from all tracking and frees the node.
func die() -> void:
	if is_dead:
		return
	if is_carrying_food:
		_carried_food.set_state(Food.State.AVAILABLE)
	is_dead = true
	doing_task = false
	died.emit(self)
#endregion
