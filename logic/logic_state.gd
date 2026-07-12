class_name LogicState
extends RefCounted
## Per-(Logic, entity) evaluation state: the SINGLE source of truth for the
## cached value, freshness, dependency versions, parse state, and stats.
## Replaces both the old ExpressionState inner class in EvaluationSystem and
## the separate _evaluation_cache dictionary — there is no cache_key anymore;
## the state IS the cache entry.
##
## Division of labor:
##   Logic subclasses   — WHAT to compute (evaluate())
##   EvaluationSystem   — WHEN to compute (policies, dependency versions)
##   LogicState (here)  — everything remembered between computes
##
## SAFETY: execute() runs against `context` — the value-type AntSenses facade
## obtained via get_expression_context() — never against the raw entity.
## Executing against the Ant itself would let authored expressions reach
## mutating methods, which is exactly what the whitelist boundary forbids.

## Immutable reference back to the asset
var logic: Logic

## Entity this state belongs to
var entity: Node

## What expressions execute against: entity.get_expression_context()
## (AntSenses for ants), falling back to the entity for other node types.
var context: Object


#region Value & freshness
## Cached value from the last successful evaluation.
var cached_value: Variant

## True once cached_value holds a real result.
var has_value := false

## Set by invalidate() (EVENT triggers, editors); forces the next
## get_value() to recompute regardless of policy.
var stale := false

## Time.get_ticks_msec() of the last compute (or dependency re-check).
## Replaces the old cache entry's `timestamp` field — TIMER and FRAME
## policies measure against this.
var last_evaluation_time: int = 0

## Version of the cached VALUE. Reassigned (from the global serial below)
## only when the value actually changes; parents compare the versions they
## remembered in dependency_versions against their children's current
## versions to decide whether a pure composite must re-execute.
##
## Why a GLOBAL serial instead of a per-state counter: states get dropped
## and recreated by invalidate_expression() (library edits). A per-state
## counter restarts at 0 → 1, which can collide with a version the OLD
## state already reported to a parent — the parent would then serve a stale
## cache across a real value change. Serials are never reused, so version
## equality always means "same value as last remembered". 0 = never
## computed (the serial starts handing out values at 1).
var version: int = 0

## Child versions from the last successful evaluation.
## child_logic_id -> version
var dependency_versions: Dictionary = {}
#endregion


#region Parsing
## Expression parser. Null for PropertyLogic / SourceLogic leaves — they
## read atomic senses directly and never touch the Expression VM.
var expression: Expression

var compiled_expression: String

## True once parsed (or once determined there is nothing to parse).
var is_parsed := false

## Set when LogicValidator (or parsing) rejected this logic, so the engine
## returns the type default without re-validating on every call.
var validation_failed := false

## True when the compiled expression's inputs are ENTIRELY its children:
## every identifier is a nested id or a pure deterministic built-in — no
## direct atomic-sense reads, no randomness. Only then do unchanged
## dependency versions imply an unchanged result, so only then may
## EvaluationSystem skip execute() on the dependency-version check.
var pure_composite := false
#endregion


#region Statistics (per entity; EvaluationSystem keeps global aggregates)
var evaluations := 0
var cache_hits := 0
var total_time_us := 0.0
var last_time_us := 0.0
#endregion


## FRAME-mode window, formerly EvaluationSystem.CACHE_TTL_MS.
const FRAME_TTL_MS := 16.0

## Built-ins whose result changes between identical calls; their presence
## disqualifies an expression from dependency-version short-circuiting.
const _IMPURE_FUNCS: Array[String] = [
	"randf", "randi", "randf_range", "randi_range",
]

## Global monotonic version serial (see `version`). Shared by ALL states so
## a version number can never be reused across state drop/recreate cycles.
static var _version_serial: int = 0

## Atomic sense names, built once from AntSenses (single source of truth).
static var _sense_names: Dictionary = {}
static var _ident_regex: RegEx
static var _string_regex: RegEx


func _init(p_logic: Logic, p_entity: Node) -> void:
	logic = p_logic
	entity = p_entity
	compiled_expression = p_logic.expression_string
	context = p_entity.get_expression_context() \
		if p_entity.has_method("get_expression_context") else p_entity

	# Everything except the direct-read leaves compiles an Expression.
	# NOTE: plain Logic resources (all pre-subclass .tres files, and the
	# designer's "New expression" button) MUST get one — do not invert this
	# into an allowlist of expression subclasses.
	if not (logic is PropertyLogic or logic is SourceLogic):
		expression = Expression.new()

	# Whitelist boundary invariant: an entity that provides a value-type
	# facade must NEVER be executed against directly — the raw entity would
	# expose mutating methods to authored expressions, which is exactly what
	# gate 3 forbids. Tautological today; catches a future _init refactor
	# that breaks the facade assignment.
	assert(not p_entity.has_method("get_expression_context") or context != p_entity,
		"LogicState for '%s' bound to raw entity instead of its facade" % p_logic.id)

#region Parsing
func parse(variables: PackedStringArray) -> Error:
	if is_parsed:
		return OK

	# Direct-read leaves and empty expressions have nothing to compile.
	if expression == null or compiled_expression.is_empty():
		is_parsed = true
		return OK

	# Check for unsafe access patterns
	var unsafe_patterns := [
		" _",  # Space followed by underscore
		"._",  # Dot followed by underscore
		"@",   # Direct property access
		"$/",  # Node path traversal
		"get_node",  # Node access
		" load",      # Resource loading
		" preload"    # Resource preloading
	]

	for pattern in unsafe_patterns:
		if compiled_expression.contains(pattern):
			push_error("Unsafe expression pattern detected: %s" % pattern)
			return ERR_UNAUTHORIZED

	# Validate variables don't contain unsafe patterns
	for var_name in variables:
		for pattern in unsafe_patterns:
			if var_name.contains(pattern):
				push_error("Unsafe variable name detected: %s" % var_name)
				return ERR_UNAUTHORIZED

	var error := expression.parse(compiled_expression, variables)
	is_parsed = error == OK
	if is_parsed:
		_detect_purity()
	return error


## Determines pure_composite (see its doc). Runs once per parse.
##
## Nested ids are excluded from the sense-name scan: Expression.parse()
## binds the nested ids as input variables at PARSE time, so an identifier
## matching a nested id always resolves to the child's bound value — never
## to a same-named atomic sense on the base instance. A PropertyLogic leaf
## may therefore share its name with the sense it wraps (e.g. a leaf whose
## id is "health_level" reading the health_level sense) without poisoning
## its parents' purity. Without this exclusion, the natural leaf-naming
## convention would silently disable version gating everywhere.
func _detect_purity() -> void:
	pure_composite = false
	if logic.nested_expressions.is_empty():
		return  # A leaf's inputs are the world, not its children.

	if _sense_names.is_empty():
		for entry: Dictionary in AntSenses.get_vocabulary():
			_sense_names[entry.name] = true
	if _ident_regex == null:
		# Lookbehind skips tokens inside numbers (1e5) and after dots —
		# dot-prefixed names are pure value-type methods/components anyway.
		_ident_regex = RegEx.create_from_string("(?<![A-Za-z0-9_.])[A-Za-z_][A-Za-z0-9_]*")
		_string_regex = RegEx.create_from_string("\"[^\"]*\"")

	var nested_ids := {}
	for n: Logic in logic.nested_expressions:
		if n:
			nested_ids[n.id] = true

	# Strip string literals so pheromone names like "danger" aren't scanned.
	var stripped := _string_regex.sub(compiled_expression, "", true)
	for m: RegExMatch in _ident_regex.search_all(stripped):
		var ident := m.get_string()
		if nested_ids.has(ident):
			continue  # bound child input — shadows any same-named sense
		if _sense_names.has(ident) or ident in _IMPURE_FUNCS:
			return
	pure_composite = true
#endregion


#region Execution
func execute(bindings: Array) -> Variant:
	if expression == null or not is_parsed or compiled_expression.is_empty():
		return null
	return expression.execute(bindings, context)


func has_error() -> bool:
	return expression != null and expression.has_execute_failed()
#endregion


#region Value & versions
## Stores a computed result, taking a fresh version serial only if the VALUE
## changed — parents recompute on version changes, so spurious bumps waste
## work, and a recompute that lands on the same value must not ripple.
func cache(value: Variant) -> void:
	if not has_value or cached_value != value:
		_version_serial += 1
		# Serial monotonicity is the ENTIRE aliasing fix: version equality
		# means "same value as last remembered" only because serials are
		# never reused across state drop/recreate cycles. If this ever
		# fires, someone reintroduced a per-state counter or reset the
		# static — the stale-cache-across-recreate bug is back.
		assert(_version_serial > version,
			"LogicState version serial regressed for '%s' (aliasing bug)" % logic.id)
		version = _version_serial


## True if the cached value may still be served under this logic's
## re-evaluation policy. Formerly EvaluationSystem._cache_entry_valid();
## living here means policy freshness and the value it guards can't drift.
func is_cache_valid() -> bool:
	if not has_value or stale:
		return false
	match logic.eval_mode:
		Logic.EvalMode.ALWAYS:
			return false
		Logic.EvalMode.STICKY, Logic.EvalMode.EVENT:
			return true
		Logic.EvalMode.TIMER:
			return Time.get_ticks_msec() - last_evaluation_time < logic.eval_interval_ms
		_:
			return Time.get_ticks_msec() - last_evaluation_time < FRAME_TTL_MS


## Forces the next get_value() to recompute (EVENT triggers, editors).
## Deliberately does NOT bump version — the value hasn't changed yet, and a
## recompute that lands on the same value shouldn't ripple to parents.
func invalidate() -> void:
	stale = true


func dependency_changed(child: Logic, child_version: int) -> bool:
	return dependency_versions.get(child.id, -1) != child_version


func remember_dependency(child: Logic, child_version: int) -> void:
	dependency_versions[child.id] = child_version
#endregion
