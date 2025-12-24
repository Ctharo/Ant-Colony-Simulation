class_name AntBehaviorManager
extends Node

var behaviors: Array[AntBehavior] = []
var active_behavior: AntBehavior
var ant: Ant
var logger: iLogger

func _init() -> void:
	logger = iLogger.new("behavior_manager", DebugLogger.Category.ENTITY)

func initialize(p_ant: Ant) -> void:
	ant = p_ant
	logger.debug("Initialized behavior manager for " + ant.name)

func _physics_process(delta: float) -> void:
	update_behaviors()

func add_behavior(behavior: AntBehavior) -> void:
	behavior.initialize(ant)
	behaviors.append(behavior)
	# Sort by priority (highest first)
	behaviors.sort_custom(func(a, b): return a.priority > b.priority)
	logger.debug("Added behavior: " + behavior.name)

func update_behaviors() -> void:
	# Find highest priority behavior that should be active
	var next_behavior: AntBehavior = null

	for behavior in behaviors:
		if behavior.should_be_active():
			next_behavior = behavior
			break

	# Handle behavior change if needed
	if next_behavior != active_behavior:
		logger.debug("Behavior changing from " +
					(active_behavior.name if active_behavior else "none") +
					" to " +
					(next_behavior.name if next_behavior else "none"))

		if active_behavior:
			active_behavior.deactivate()

		active_behavior = next_behavior

		if active_behavior:
			active_behavior.activate()
