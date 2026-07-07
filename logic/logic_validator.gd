class_name LogicValidator
extends RefCounted
## Static whitelist validator enforcing the tier boundary of the behavior
## language:
##
##   Tier 0 (atomic)  — AntSenses.VOCAB: the only world-facing identifiers.
##   Tier 1 (derived) — Logic .tres: may reference ONLY atomic senses, the
##                      ids of their own nested expressions, and the safe
##                      pure built-ins listed below. Nothing else.
##
## Why this exists: Expression.execute() resolves unknown identifiers
## against the base instance, so without this gate an authored expression
## can reach AntSenses._ant (underscores are convention, not privacy) and
## from there call anything. A whitelist is the only sound enforcement —
## blacklists always miss a name.
##
## Why name-whitelisting is sufficient: atomic senses return only value
## types (bool/int/float/String/Vector2), so no object can ever be a
## receiver inside an expression; every allowed method name is therefore a
## pure value-type method with no side effects.
##
## Enforced at three gates (defense in depth):
##   1. LogicEditorPopup._validate()      — live feedback while typing
##   2. ResourceLibrary.save_resource()   — invalid expressions can't persist
##   3. EvaluationSystem (first parse)    — hand-edited .tres can't bypass
##
## AntSenses.VOCAB remains the single source of truth for Tier 0: the
## atomic set below is derived from get_vocabulary() at first use, so a new
## sense is automatically legal everywhere the moment it gets a VOCAB entry.

#region Whitelists
## Pure Expression built-in functions. Deliberately excludes anything with
## side effects or object access (print, load, instance_from_id, ...).
const BUILTIN_FUNCS: Array[String] = [
	# math
	"abs", "sign", "floor", "ceil", "round", "snapped",
	"clamp", "clampf", "clampi", "min", "minf", "mini", "max", "maxf", "maxi",
	"lerp", "lerpf", "inverse_lerp", "remap", "smoothstep",
	"sqrt", "pow", "exp", "log",
	"sin", "cos", "tan", "asin", "acos", "atan", "atan2",
	"deg_to_rad", "rad_to_deg", "wrapf", "wrapi", "fmod", "pingpong",
	"is_nan", "is_inf", "is_finite", "is_zero_approx", "is_equal_approx",
	# randomness (legitimate for behavior: wander, jitter)
	"randf", "randi", "randf_range", "randi_range",
	# conversion
	"int", "float", "str", "bool",
]

## Methods callable on values the atomic senses can produce. All pure.
const VALUE_METHODS: Array[String] = [
	# Vector2
	"distance_to", "distance_squared_to", "direction_to",
	"length", "length_squared", "normalized", "limit_length",
	"dot", "cross", "angle", "angle_to", "angle_to_point",
	"rotated", "lerp", "move_toward", "clamp", "abs", "sign",
	"is_finite", "is_zero_approx", "is_equal_approx",
	# Vector2 components
	"x", "y",
	# String (pure queries only)
	"is_empty", "to_lower", "to_upper", "contains",
	"begins_with", "ends_with", "similarity",
	# String/shared: "length" already listed above
]

## Constants and safe type constructors.
const CONSTANTS: Array[String] = [
	"true", "false", "null",
	"PI", "TAU", "INF", "NAN",
	"Vector2",
]
#endregion


## Lazily-built union of every allowed identifier except nested ids
## (those vary per expression). name -> true.
static var _static_allowed: Dictionary = {}


#region Public API
## Validates a derived expression against the closed whitelist.
## Returns an empty array when valid, else human-readable errors.
static func validate(expression_string: String, nested: Array[Logic]) -> PackedStringArray:
	var errors := PackedStringArray()
	var allowed := _build_allowed(nested)

	var unknown := PackedStringArray()
	for ident in _extract_identifiers(expression_string):
		if not allowed.has(ident) and not unknown.has(ident):
			unknown.append(ident)

	for ident in unknown:
		errors.append(
			"'%s' is not part of the behavior language — allowed: atomic senses (AntSenses), this expression's nested ids, and pure built-ins."
			% ident)
	return errors


## Convenience wrapper for a Logic resource.
static func validate_logic(logic: Logic) -> PackedStringArray:
	return validate(logic.expression_string, logic.nested_expressions)


## Full identifier whitelist for a given nested set — for tooling
## (editor autocomplete, vocabulary picker, audits). name -> true.
static func allowed_identifiers(nested: Array[Logic]) -> Dictionary:
	return _build_allowed(nested)


## Call after hot-editing AntSenses (e.g. via reload) so the atomic set
## is rebuilt on next validation.
static func invalidate_cache() -> void:
	_static_allowed.clear()
#endregion


#region Internals
static func _build_allowed(nested: Array[Logic]) -> Dictionary:
	if _static_allowed.is_empty():
		for entry: Dictionary in AntSenses.get_vocabulary():
			_static_allowed[entry.name] = true
		for n in BUILTIN_FUNCS:
			_static_allowed[n] = true
		for n in VALUE_METHODS:
			_static_allowed[n] = true
		for n in CONSTANTS:
			_static_allowed[n] = true

	var allowed := _static_allowed.duplicate()
	for logic: Logic in nested:
		if logic:
			allowed[logic.id] = true
	return allowed


## Pulls every identifier token out of an expression string.
## - String literals are stripped first, so pheromone names like
##   "danger" are never treated as identifiers.
## - The lookbehind (?<!\w) keeps the exponent of 1e3 and the x1F of a
##   hex literal from being read as identifiers, while still capturing
##   names after a '.' (method/component access), which is exactly what
##   we need to check.
static func _extract_identifiers(expression_string: String) -> PackedStringArray:
	var out := PackedStringArray()

	var strip := RegEx.new()
	strip.compile("\"(?:[^\"\\\\]|\\\\.)*\"|'(?:[^'\\\\]|\\\\.)*'")
	var cleaned := strip.sub(expression_string, " ", true)

	var ident := RegEx.new()
	ident.compile("(?<!\\w)[A-Za-z_]\\w*")
	for m in ident.search_all(cleaned):
		out.append(m.get_string())
	return out
#endregion
