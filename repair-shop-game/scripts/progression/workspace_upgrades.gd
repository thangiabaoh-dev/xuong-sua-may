class_name WorkspaceUpgrades
extends RefCounted

static func try_upgrade(game_state: Node, defs: Array) -> String:
	var tier := _int(game_state, "workspace_tier")
	var def = null
	for d in defs:
		if int(d.to_tier) == tier + 1:
			def = d
			break
	if def == null:
		return "max_tier"
	if _int(game_state, "money") < int(def.cost):
		return "no_money"
	if _int(game_state, "uy_tin") < int(def.uy_tin_req):
		return "low_uy_tin"
	if String(def.condition) != "" and not _eval(String(def.condition), game_state):
		return "condition"
	game_state.set("money", _int(game_state, "money") - int(def.cost))
	game_state.set("workspace_tier", int(def.to_tier))
	return ""

static func _eval(cond: String, game_state: Node) -> bool:
	var expr := Expression.new()
	if expr.parse(cond, UnlockCore.INPUT_NAMES) != OK:
		return false
	var inputs: Array = []
	for prop in UnlockCore.INPUT_NAMES:
		inputs.append(_int(game_state, prop))
	var ctx := UnlockContext.new()
	if game_state != null:
		var cp = game_state.get("completed_projects")
		if cp is Array:
			ctx.completed_projects = cp
	var r = expr.execute(inputs, ctx, false)
	return r == true

static func _int(game_state: Node, prop: String) -> int:
	if game_state == null:
		return 0
	var v = game_state.get(prop)
	if v == null:
		return 0
	return int(v)
