class_name BehaviorTreeManager
extends Node

var root_node: BehaviorNode
var entity: Ant
var logger: Logger

func _init() -> void:
    name = "behavior_tree_manager"
    logger = Logger.new(name, DebugLogger.Category.ENTITY)

func initialize(p_entity: Ant, p_root_node: BehaviorNode) -> void:
    entity = p_entity
    root_node = p_root_node
    root_node.initialize(entity)

func _physics_process(delta: float) -> void:
    if is_instance_valid(root_node) and is_instance_valid(entity):
        root_node.tick(delta)
