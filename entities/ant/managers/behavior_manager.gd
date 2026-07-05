class_name BehaviorManager
extends Node
## Evaluates data-driven AntRule resources each physics tick, replacing the
## hardcoded decision tree that lived in Ant._physics_process().
##
## Design mirrors InfluenceManager: created by the Ant, initialized with an
## entity reference, and driven from the ant's _physics_process. Conditions
## are evaluated through EvaluationSystem (same pipeline as influences), so
## everything a Logic expression can reference is available to rules.

signal rule_fired(rule: AntRule)
signal rules_changed

#region Properties
## The ant this manager acts on
var entity: Ant

## Per-ant rule overrides. Keys are AntRule, value true = locally disabled.
## Never mutates the shared resource — profile-level enabled stays authoritative
## for all ants; this only subtracts for this specific ant.
var _local_disabled: Dictionary = {}

## Active rules, kept sorted by descending priority
var rules: Array[AntRule] = []

var logger: iLogger
#endregion

func _init() -> void:
	name = "behavior_manager"
	logger = iLogger.new(name, DebugLogger.Category.LOGIC)

func initialize(p_entity: Ant) -> void:
	if not p_entity:
		push_error("Cannot initialize BehaviorManager with null entity")
		return
	entity = p_entity

#region Rule Management
func add_rule(rule: AntRule) -> void:
	if not rule:
		push_error("Cannot add null rule")
		return
	if rule in rules:
		return
	rules.append(rule)
	_sort_rules()
	rules_changed.emit()

func add_rules(p_rules: Array[AntRule]) -> void:
	for rule: AntRule in p_rules:
		if rule and rule not in rules:
			rules.append(rule)
	_sort_rules()
	rules_changed.emit()

func remove_rule(rule: AntRule) -> void:
	if rule in rules:
		rules.erase(rule)
		rules_changed.emit()

func clear_rules() -> void:
	rules.clear()
	rules_changed.emit()

## Public re-sort hook for runtime rule editing
func resort() -> void:
	_sort_rules()

func _sort_rules() -> void:
	rules.sort_custom(func(a: AntRule, b: AntRule) -> bool:
		return a.priority > b.priority
	)
	
func set_rule_enabled_local(rule: AntRule, enabled: bool) -> void:
	if enabled:
		_local_disabled.erase(rule)
	else:
		_local_disabled[rule] = true


func is_rule_enabled_local(rule: AntRule) -> bool:
	return not _local_disabled.get(rule, false)
	
## Replaces the full rule set (used when a profile's rules are edited live).
## Local overrides for rules that survive the swap are preserved.
func set_rules(p_rules: Array[AntRule]) -> void:
	rules.clear()
	add_rules(p_rules)
	# Drop overrides for rules no longer present
	for rule: AntRule in _local_disabled.keys():
		if rule not in rules:
			_local_disabled.erase(rule)
#endregion

#region Evaluation
## Evaluates rules in priority order. Executes the first rule whose condition
## passes and returns true; returns false if no rule fired (caller falls
## through to default movement processing).
func process_rules() -> bool:
	if not is_instance_valid(entity) or entity.is_dead:
		return false

	for rule: AntRule in rules:
		if not rule.enabled or _local_disabled.get(rule, false) or not rule.action:
			continue

		if rule.condition:
			var result: Variant = rule.condition.get_value(entity)
			if not result:
				continue

		if _execute(rule.action):
			rule_fired.emit(rule)
			return true

	return false

## Executes an action against the entity. Returns false if the action was
## rejected (not whitelisted / missing method) so a bad rule doesn't
## swallow the tick and starve lower-priority rules.
func _execute(action: AntAction) -> bool:
	if action.method.is_empty():
		logger.error("Action '%s' has no method set" % action.name)
		return false

	if action.method not in Ant.ACTION_API:
		logger.error("Action '%s' uses non-whitelisted method '%s'" % [
			action.name, action.method
		])
		return false

	if not entity.has_method(action.method):
		logger.error("Entity is missing action method '%s'" % action.method)
		return false

	var args: Array = []
	for param: Logic in action.params:
		args.append(EvaluationSystem.get_value(param, entity))

	entity.callv(action.method, args)
	return true
#endregion
