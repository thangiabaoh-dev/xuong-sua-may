class_name UnlockCore
extends RefCounted

signal unlock_changed(id: StringName)

const INPUT_NAMES := ["money", "knowledge", "uy_tin", "ky_luat", "workspace_tier"]

var _parsed: Dictionary = {}
var _errors: Array[String] = []
var _unlocked: Dictionary = {}
var _permanent: Dictionary = {}

func setup(rules: Array) -> void:
	_parsed.clear()
	_errors.clear()
	_unlocked.clear()
	_permanent.clear()
	for rule in rules:
		if not bool(rule.enabled):
			continue
		var expr := Expression.new()
		var err := expr.parse(String(rule.condition), INPUT_NAMES)
		if err != OK:
			_add_error("%s: %s" % [rule.id, expr.get_error_text()])
			continue
		_parsed[rule.id] = expr

func refresh(game_state: Node) -> void:
	var inputs: Array = []
	for prop in INPUT_NAMES:
		inputs.append(_int_field(game_state, prop))
	var ctx := UnlockContext.new()
	if game_state != null:
		var cp = game_state.get("completed_projects")
		if cp is Array:
			ctx.completed_projects = cp
	for id in _parsed:
		var expr: Expression = _parsed[id]
		var r = expr.execute(inputs, ctx, false)
		if r == null:
			_add_error("%s: evaluate null (unknown identifier?)" % id)
			continue
		if not (r is bool):
			_add_error("%s: non-boolean result (%s)" % [id, type_string(typeof(r))])
			continue
		if r == true:
			if not _unlocked.has(id):
				_unlocked[id] = true
				if not _permanent.has(id):
					_permanent[id] = true
					unlock_changed.emit(id)
		elif _unlocked.has(id) and not _permanent.has(id):
			_unlocked.erase(id)

func is_unlocked(id: StringName) -> bool:
	return _unlocked.has(id)

func unlocked_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in _unlocked:
		out.append(id)
	return out

func parse_errors() -> Array[String]:
	return _errors

func _add_error(msg: String) -> void:
	if not _errors.has(msg):
		_errors.append(msg)

func _int_field(game_state: Node, prop: String) -> int:
	if game_state == null:
		return 0
	var v = game_state.get(prop)
	if v == null:
		return 0
	return int(v)
