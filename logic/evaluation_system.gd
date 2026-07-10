extends Node

#region Properties
## Evaluation controller for batching and rate limiting
@onready var _controller: EvaluationController

## Dictionary mapping entity instance IDs to their expression states
## Structure: { entity_id: { expression_id: LogicState } }
var _entity_states: Dictionary = {}
var _evaluation_cache: Dictionary = {}

## Entity signals that EVENT-mode expressions are allowed to hook. Mirrors the
## Ant.ACTION_API whitelist philosophy: data files can't reach arbitrary code.
const TRIGGER_SIGNAL_WHITELIST: PackedStringArray = [
	"spawned", "energy_changed", "movement_completed", "died",
]

## Aggregated per-expression stats (across all entities), read by the
## Behavior Designer. expression_id -> {evals, hits, total_us, last_us}
var _stats: Dictionary = {}

## EVENT-mode trigger bookkeeping so invalidation can rewire cleanly.
## cache_key -> {entity_iid: int, conns: Array[{signal: String, callable: Callable}]}
var _connected_triggers: Dictionary = {}

const CACHE_TTL_MS = 16.0 ## 16.0 for single-frame caching

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

## Gets or creates the state dictionary for an entity
func _get_entity_states(entity: Node) -> Dictionary:
	var entity_id := str(entity.get_instance_id())
	if not _entity_states.has(entity_id):
		_entity_states[entity_id] = {}
	return _entity_states[entity_id]

## Gets or creates an expression state for a specific entity
func _get_or_create_state(expression: Logic, entity: Node) -> LogicState:
	if expression.id.is_empty():
		logger.error("Expression has empty ID: %s" % expression)
		return null

	var states := _get_entity_states(entity)
	if not states.has(expression.id):
		states[expression.id] = LogicState.new(expression, entity)

	return states[expression.id]

## Registers an expression for a specific entity context
func register_expression(expression: Logic, entity: Node) -> void:
	# Generate ID if needed
	if expression.id.is_empty():
		expression.id = str(expression.get_instance_id())

	# Create state (parsing will be done lazily when needed)
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
	
## Drops parsed state and cached values for an expression across all entities.
## Next get_value() lazily re-registers and re-parses. Used by runtime editors.
func invalidate_expression(expression_id: String) -> void:
	if expression_id.is_empty():
		return
	for entity_id in _entity_states:
		_entity_states[entity_id].erase(expression_id)

	var stale: Array = []
	for key in _evaluation_cache:
		if key.begins_with(expression_id + "_"):
			stale.append(key)
	for key in stale:
		_evaluation_cache.erase(key)

	var idx := DebugLogger.parsed_expression_strings.find(expression_id)
	if idx >= 0:
		DebugLogger.parsed_expression_strings.remove_at(idx)
	
	for key: String in _connected_triggers.keys():
		if key.begins_with(expression_id + "_"):
			_disconnect_triggers(key)
#endregion

#region Expression Evaluation
## Gets the value of an expression in the context of a specific entity
func get_value(expression: Logic, entity: Node) -> Variant:
	# Lazy registration and parsing if needed
	var states := _get_entity_states(entity)
	if not states.has(expression.id):
		logger.trace("Auto-registering expression %s for entity %s" % [
			expression.id,
			entity.name
		])
		register_expression(expression, entity)

	# Get expression state if available
	var state: LogicState = states[expression.id]
	if not state:
		logger.error("Failed to get/create state for expression %s" % expression.id)
		return null

	# Lazy parsing if needed
	if not state.is_parsed:
		var errors := LogicValidator.validate_logic(expression)
		if not errors.is_empty():
			push_error("Logic '%s' rejected by validator: %s" % [expression.id, "; ".join(errors)])
			# mark the state invalid so we don't re-validate every call,
			# and return the safe default for the declared type
			return false
		_parse_expression(expression, entity)

	# Calculate new value
	var result = _calculate(expression.id, entity)
	return result

func _parse_expression(expression: Logic, entity: Node) -> void:
	var state := _get_or_create_state(expression, entity)
	if state.is_parsed or expression.expression_string.is_empty():
		return

	var variable_names = []
	for nested in expression.nested_expressions:
		if nested.name.is_empty():
			logger.error("Nested expression missing name: %s" % nested)
			return
		if nested.id.is_empty():
			logger.error("Nested expression missing ID: %s" % nested)
			return
		variable_names.append(nested.id)

	if expression.id not in DebugLogger.parsed_expression_strings:
		if logger.is_debug_enabled():
			logger.debug("Parsing expression %s%s for entity %s" % [
				expression.id,
				" with variables: %s" % str(variable_names) if variable_names else "",
				entity.name
			])
		DebugLogger.parsed_expression_strings.append(expression.id)

	var error = state.parse(PackedStringArray(variable_names))
	if error != OK:
		logger.error('Failed to parse expression "%s": %s' % [
			expression.name,
			expression.expression_string
		])
		return

func _calculate(expression_id: String, entity: Node) -> Variant:
	var states := _get_entity_states(entity)
	var state: LogicState = states[expression_id]
	if not state.is_parsed:
		return null

	var logic: Logic = state.logic
	var cache_key := "%s_%s" % [expression_id, entity.get_instance_id()]

	# Check cache against this expression's re-evaluation policy
	if _evaluation_cache.has(cache_key) \
			and _cache_entry_valid(logic, _evaluation_cache[cache_key]):
		_record_stat(expression_id, true, 0.0)
		return _evaluation_cache[cache_key].value

	var start_time := Time.get_ticks_usec()

	logger.trace("Calculating %s for entity %s" % [expression_id, entity.name])

	# Get values from nested expressions
	var bindings = []
	for nested in state.logic.nested_expressions:
		logger.trace("Getting nested value for %s" % nested.id)
		var value = get_value(nested, entity)
		bindings.append(value)
		logger.trace("Nested %s = %s" % [nested.id, value])

	var result = state.execute(bindings)

	if state.has_error():
		logger.error('Expression execution failed: id=%s expr="%s" entity=%s' % [
			expression_id,
			state.compiled_expression,
			entity.name
		])
		return null

	var duration_us := float(Time.get_ticks_usec() - start_time)
	_record_stat(expression_id, false, duration_us)

	if _perf_monitor_enabled and logger.is_debug_enabled():
		var duration_ms := duration_us / 1000.0
		if duration_ms > _slow_threshold_ms:
			logger.warn("Slow expression calculation: id=%s entity=%s duration=%.2fms" % [
				expression_id,
				entity.name,
				duration_ms
			])

	if logger.is_debug_enabled():
		logger.debug("Final result for %s (entity %s) = %s" % [
			expression_id,
			entity.name,
			result
		])

	# Store in cache
	_evaluation_cache[cache_key] = {
		"value": result,
		"timestamp": Time.get_ticks_msec()
	}

	return result
	
## True if a cache entry may still be served under the expression's policy.
## EVENT entries are erased by their trigger signals, so mere existence means
## no trigger has fired since the last compute.
func _cache_entry_valid(logic: Logic, entry: Dictionary) -> bool:
	match logic.eval_mode:
		Logic.EvalMode.ALWAYS:
			return false
		Logic.EvalMode.STICKY, Logic.EvalMode.EVENT:
			return true
		Logic.EvalMode.TIMER:
			return Time.get_ticks_msec() - entry.timestamp < logic.eval_interval_ms
		_:
			return Time.get_ticks_msec() - entry.timestamp < CACHE_TTL_MS


## Wires EVENT-mode expressions: each whitelisted trigger signal erases the
## cache entry, so the next get_value() recomputes. Connections live on the
## entity and die with it; _connected_triggers lets invalidation rewire.
func _connect_triggers(expression: Logic, entity: Node) -> void:
	if expression.eval_mode != Logic.EvalMode.EVENT:
		return
	var cache_key := "%s_%s" % [expression.id, entity.get_instance_id()]
	if _connected_triggers.has(cache_key):
		return

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
			_evaluation_cache.erase(cache_key)
		entity.connect(sig_name, cb)
		conns.append({"signal": sig_name, "callable": cb})

	if not conns.is_empty():
		_connected_triggers[cache_key] = {
			"entity_iid": entity.get_instance_id(),
			"conns": conns,
		}


func _disconnect_triggers(cache_key: String) -> void:
	var rec: Dictionary = _connected_triggers.get(cache_key, {})
	if rec.is_empty():
		return
	var entity: Object = instance_from_id(rec.entity_iid)
	if is_instance_valid(entity):
		for conn: Dictionary in rec.conns:
			if entity.is_connected(conn.signal, conn.callable):
				entity.disconnect(conn.signal, conn.callable)
	_connected_triggers.erase(cache_key)


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


func reset_stats() -> void:
	_stats.clear()
#endregion

#region Cleanup
## Cleans up expression states for an entity when it's no longer needed
func cleanup_entity(entity: Node) -> void:
	var entity_id := str(entity.get_instance_id())
	if _entity_states.has(entity_id):
		_entity_states.erase(entity_id)
		logger.debug("Cleaned up expression states for entity %s" % entity.name)

	# Purge cached values and trigger bookkeeping for this entity. (The signal
	# connections themselves die with the entity; this just drops our records.)
	var suffix := "_%s" % entity_id
	for key: String in _evaluation_cache.keys():
		if key.ends_with(suffix):
			_evaluation_cache.erase(key)
	for key: String in _connected_triggers.keys():
		if key.ends_with(suffix):
			_connected_triggers.erase(key)
#endregion
