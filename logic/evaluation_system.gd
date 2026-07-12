extends Node
## Execution engine for the behavior language.
##
## WHAT to compute lives in the Logic subclasses (each overrides
## Logic.evaluate()); WHEN to compute lives here. Per get_value() the engine
## only:
##   1. gets (or lazily creates, validates, and parses) the LogicState
##   2. applies the re-evaluation policy — a valid cache returns immediately,
##      without touching the subtree (root policies gate entire trees)
##   3. resolves nested expressions and checks dependency versions —
##      pure composites skip execution when no child value changed
##   4. calls logic.evaluate(state, bindings)
##   5. updates version, dependency versions, and cache — all on the state
##
## LogicState is the single source of truth per (Logic, entity): cached
## value, freshness timestamp, versions, parse state, and per-entity stats
## all live there. The old inner ExpressionState class and the separate
## _evaluation_cache dictionary (with its "%s_%s" cache keys) are gone.

#region Properties
## Evaluation controller for batching and rate limiting
@onready var _controller: EvaluationController

## Per-entity LogicStates.
## Structure: { entity_iid (String): { logic_id: LogicState } }
var _entity_states: Dictionary = {}

## Entity signals that EVENT-mode expressions are allowed to hook. Mirrors the
## Ant.ACTION_API whitelist philosophy: data files can't reach arbitrary code.
const TRIGGER_SIGNAL_WHITELIST: PackedStringArray = [
	"spawned", "energy_changed", "movement_completed", "died",
]

## Aggregated per-expression stats (across all entities), read by the
## Behavior Designer. Kept here (not summed from LogicStates on demand) so
## the designer's counters survive invalidate_expression(), which drops
## states. expression_id -> {evals, hits, total_us, last_us}
var _stats: Dictionary = {}

## EVENT-mode trigger bookkeeping so invalidation can rewire cleanly.
## trigger_key ("id_iid") -> {entity_iid: int, conns: Array[{signal, callable}]}
var _connected_triggers: Dictionary = {}

## Logger instance
var logger: iLogger

## Performance monitoring enabled state
var _perf_monitor_enabled := false

## Threshold for logging slow evaluations (ms)
var _slow_threshold_ms := 1.0
#endregion


#region Initialization
func _init() -> void:
	logger = iLogger.new("expr_mgr", DebugLogger.Category.LOGIC)
	_controller = EvaluationController.new()
#endregion


#region State access
## Gets or creates the state dictionary for an entity
func _get_entity_states(entity: Node) -> Dictionary:
	var entity_id := str(entity.get_instance_id())
	if not _entity_states.has(entity_id):
		_entity_states[entity_id] = {}
	return _entity_states[entity_id]


## Gets or creates the LogicState for a (logic, entity) pair
func _get_or_create_state(logic: Logic, entity: Node) -> LogicState:
	if logic.id.is_empty():
		logger.error("Expression has empty ID: %s" % logic)
		return null

	var states := _get_entity_states(entity)
	if not states.has(logic.id):
		states[logic.id] = LogicState.new(logic, entity)
	return states[logic.id]
#endregion


#region Registration & invalidation
## Registers an expression for a specific entity context
func register_expression(expression: Logic, entity: Node) -> void:
	# Generate ID if needed
	if expression.id.is_empty():
		expression.id = str(expression.get_instance_id())

	# Create state (validation and parsing happen lazily on first use)
	var state := _get_or_create_state(expression, entity)
	if not state:
		logger.error("Failed to create state for expression %s" % expression.id)
		return

	_connect_triggers(expression, entity)

	# Register nested expressions and their dependencies
	for nested in expression.nested_expressions:
		register_expression(nested, entity)

	logger.trace("Completed registration of %s for entity %s" % [
		expression.id,
		entity.name
	])


## Drops the LogicStates for an expression across all entities — value,
## versions, and parse state go with them, since the state IS the cache.
## Next get_value() lazily re-registers and re-parses. Used by runtime editors.
func invalidate_expression(expression_id: String) -> void:
	if expression_id.is_empty():
		return
	for entity_id in _entity_states:
		_entity_states[entity_id].erase(expression_id)

	var idx := DebugLogger.parsed_expression_strings.find(expression_id)
	if idx >= 0:
		DebugLogger.parsed_expression_strings.remove_at(idx)

	for key: String in _connected_triggers.keys():
		if key.begins_with(expression_id + "_"):
			_disconnect_triggers(key)
#endregion


#region Expression Evaluation
## Gets the value of an expression in the context of a specific entity.
## This function is the WHOLE engine: policy gate → children → dependency
## gate → logic.evaluate() → bookkeeping. What each Logic type computes is
## its own business.
func get_value(expression: Logic, entity: Node) -> Variant:
	# Lazy registration if needed
	var states := _get_entity_states(entity)
	if not states.has(expression.id):
		logger.trace("Auto-registering expression %s for entity %s" % [
			expression.id,
			entity.name
		])
		register_expression(expression, entity)

	var state: LogicState = states.get(expression.id)
	if not state:
		logger.error("Failed to get/create state for expression %s" % expression.id)
		return null

	# Lazy validation + parsing (gate 3 of the whitelist boundary)
	if not _ensure_ready(state):
		return _default_for_type(expression.type)

	# 1. Policy gate — a valid cache short-circuits the entire subtree.
	#    Children are never consulted while the parent's policy holds, which
	#    is what makes root-level STICKY/TIMER policies a performance lever.
	if state.is_cache_valid():
		state.cache_hits += 1
		_record_stat(expression.id, true, 0.0)
		return state.cached_value

	logger.trace("Calculating %s for entity %s" % [expression.id, entity.name])

	# 2. Children first — each enforces its own policy on the way down.
	var bindings: Array = []
	var deps_changed := false
	for nested in expression.nested_expressions:
		logger.trace("Getting nested value for %s" % nested.id)
		bindings.append(get_value(nested, entity))
		var child_state: LogicState = states.get(nested.id)
		if child_state == null \
				or state.dependency_changed(nested, child_state.version):
			deps_changed = true

	# 3. Dependency gate — only sound for pure composites (expressions whose
	#    inputs are ENTIRELY their children; see LogicState.pure_composite).
	#    An expression reading atomic senses directly must always re-run.
	if state.has_value and state.pure_composite and not deps_changed:
		state.cache_hits += 1
		state.last_evaluation_time = Time.get_ticks_msec()  # re-arm TIMER/FRAME
		_record_stat(expression.id, true, 0.0)
		return state.cached_value

	# 4. Evaluate — the Logic subclass decides what that means.
	var start_time := Time.get_ticks_usec()
	var result: Variant = expression.evaluate(state, bindings)

	if state.has_error():
		logger.error('Expression execution failed: id=%s expr="%s" entity=%s' % [
			expression.id,
			state.compiled_expression,
			entity.name
		])
		return null  # errors are never cached

	# 5. Bookkeeping — all on the state, the single source of truth.
	state.cache(result)  # bumps version only if the value changed
	for nested in expression.nested_expressions:
		var child_state: LogicState = states.get(nested.id)
		if child_state:
			state.remember_dependency(nested, child_state.version)

	var duration_us := float(Time.get_ticks_usec() - start_time)
	state.evaluations += 1
	state.total_time_us += duration_us
	state.last_time_us = duration_us
	_record_stat(expression.id, false, duration_us)

	if _perf_monitor_enabled and logger.is_debug_enabled():
		var duration_ms := duration_us / 1000.0
		if duration_ms > _slow_threshold_ms:
			logger.warn("Slow expression calculation: id=%s entity=%s duration=%.2fms" % [
				expression.id,
				entity.name,
				duration_ms
			])

	if logger.is_debug_enabled():
		logger.debug("Final result for %s (entity %s) = %s" % [
			expression.id,
			entity.name,
			result
		])

	return result


## Validates (whitelist gate 3) and parses lazily; both outcomes are
## remembered on the state so neither runs more than once per state.
func _ensure_ready(state: LogicState) -> bool:
	if state.validation_failed:
		return false
	if state.is_parsed:
		return true

	var errors := LogicValidator.validate_logic(state.logic)
	if not errors.is_empty():
		logger.error("Logic '%s' rejected by validator: %s" % [
			state.logic.id, "; ".join(errors)
		])
		state.validation_failed = true
		return false

	var variable_names := PackedStringArray()
	for nested in state.logic.nested_expressions:
		if nested.name.is_empty():
			logger.error("Nested expression missing name: %s" % nested)
			return false
		if nested.id.is_empty():
			logger.error("Nested expression missing ID: %s" % nested)
			return false
		variable_names.append(nested.id)

	if state.logic.id not in DebugLogger.parsed_expression_strings:
		if logger.is_debug_enabled():
			logger.debug("Parsing expression %s%s for entity %s" % [
				state.logic.id,
				" with variables: %s" % str(variable_names) if variable_names else "",
				state.entity.name
			])
		DebugLogger.parsed_expression_strings.append(state.logic.id)

	var error := state.parse(variable_names)
	if error != OK:
		logger.error('Failed to parse expression "%s": %s' % [
			state.logic.name,
			state.logic.expression_string
		])
		state.validation_failed = true  # don't re-parse (and re-log) every call
		return false
	return true


## Safe fallback when validation or parsing rejected a logic: authored
## consumers get a neutral value of the declared type instead of null.
func _default_for_type(t: Variant.Type) -> Variant:
	match t:
		TYPE_BOOL:
			return false
		TYPE_INT:
			return 0
		TYPE_FLOAT:
			return 0.0
		TYPE_STRING:
			return ""
		TYPE_VECTOR2:
			return Vector2.ZERO
		_:
			return null
#endregion


#region EVENT triggers
## Wires EVENT-mode expressions: each whitelisted trigger signal marks the
## LogicState stale, so the next get_value() recomputes. Connections live on
## the entity and die with it; _connected_triggers lets invalidation rewire.
func _connect_triggers(expression: Logic, entity: Node) -> void:
	if expression.eval_mode != Logic.EvalMode.EVENT:
		return
	var trigger_key := "%s_%s" % [expression.id, entity.get_instance_id()]
	if _connected_triggers.has(trigger_key):
		return

	# Captured by value so the lambda holds no entity reference.
	var entity_key := str(entity.get_instance_id())
	var expression_id := expression.id

	var conns: Array = []
	for sig_name: String in expression.retrigger_signals:
		if sig_name not in TRIGGER_SIGNAL_WHITELIST:
			logger.warn("Expression %s requests non-whitelisted trigger '%s'" % [
				expression.id, sig_name
			])
			continue
		if not entity.has_signal(sig_name):
			continue
		# Default args absorb whatever payload the signal carries (0-2 args)
		var cb := func(_a: Variant = null, _b: Variant = null) -> void:
			var states: Dictionary = _entity_states.get(entity_key, {})
			var st: LogicState = states.get(expression_id)
			if st:
				st.invalidate()
		entity.connect(sig_name, cb)
		conns.append({"signal": sig_name, "callable": cb})

	if not conns.is_empty():
		_connected_triggers[trigger_key] = {
			"entity_iid": entity.get_instance_id(),
			"conns": conns,
		}


func _disconnect_triggers(trigger_key: String) -> void:
	var rec: Dictionary = _connected_triggers.get(trigger_key, {})
	if rec.is_empty():
		return
	var entity: Object = instance_from_id(rec.entity_iid)
	if is_instance_valid(entity):
		for conn: Dictionary in rec.conns:
			if entity.is_connected(conn.signal, conn.callable):
				entity.disconnect(conn.signal, conn.callable)
	_connected_triggers.erase(trigger_key)
#endregion


#region Statistics
func _record_stat(expression_id: String, hit: bool, duration_us: float) -> void:
	if not _stats.has(expression_id):
		_stats[expression_id] = {"evals": 0, "hits": 0, "total_us": 0.0, "last_us": 0.0}
	var s: Dictionary = _stats[expression_id]
	if hit:
		s.hits += 1
	else:
		s.evals += 1
		s.total_us += duration_us
		s.last_us = duration_us


## Per-expression stats for the Behavior Designer. Empty dict if never touched.
func get_expression_stats(expression_id: String) -> Dictionary:
	return _stats.get(expression_id, {})


## Aggregate across all expressions (designer footer).
func get_stats_totals() -> Dictionary:
	var totals := {"evals": 0, "hits": 0, "total_us": 0.0}
	for s: Dictionary in _stats.values():
		totals.evals += s.evals
		totals.hits += s.hits
		totals.total_us += s.total_us
	return totals
#endregion
