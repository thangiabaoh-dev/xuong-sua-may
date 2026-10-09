extends "res://tests/test_case.gd"

func _rule(id: String, cond: String) -> UnlockRule:
	var r := UnlockRule.new()
	r.id = id
	r.target_kind = "machine"
	r.target_id = id
	r.condition = cond
	return r

func run() -> void:
	var core_script = load("res://scripts/progression/unlock_core.gd")
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var gs = gs_script.new()

	# boundary knowledge (Review Focus #5)
	var c1 = core_script.new()
	c1.setup([_rule("may_co", "knowledge >= 50")])
	c1.refresh(gs)
	check_eq(c1.is_unlocked("may_co"), false, "knowledge 0 -> locked")
	gs.knowledge = 50
	c1.refresh(gs)
	check_eq(c1.is_unlocked(&"may_co"), true, "knowledge 50 -> unlocked (fresh read)")

	# boundary uy_tin rule
	var c2 = core_script.new()
	c2.setup([_rule("khach_giao_vien", "uy_tin >= 60")])
	gs.uy_tin = 59
	c2.refresh(gs)
	check_eq(c2.is_unlocked("khach_giao_vien"), false, "uy_tin 59 -> locked")
	gs.uy_tin = 60
	c2.refresh(gs)
	check_eq(c2.is_unlocked("khach_giao_vien"), true, "uy_tin 60 -> unlocked")

	# rule 2 bien: workspace tier + uy tin
	var c3 = core_script.new()
	c3.setup([_rule("khach_phong_tin", "uy_tin >= 90 and workspace_tier >= 1")])
	gs.uy_tin = 90
	gs.workspace_tier = 0
	c3.refresh(gs)
	check_eq(c3.is_unlocked("khach_phong_tin"), false, "tier 0 -> locked")
	gs.workspace_tier = 1
	c3.refresh(gs)
	check_eq(c3.is_unlocked("khach_phong_tin"), true, "tier 1 -> unlocked")

	# has_project (method call tren UnlockContext)
	var c4 = core_script.new()
	c4.setup([_rule("feature_x", 'has_project("p1")')])
	c4.refresh(gs)
	check_eq(c4.is_unlocked("feature_x"), false, "no project -> locked")
	var done: Array[StringName] = [&"p1"]
	gs.completed_projects = done
	c4.refresh(gs)
	check_eq(c4.is_unlocked("feature_x"), true, "project done -> unlocked")

	# disabled rule: condition rac khong vao parse_errors
	var c5 = core_script.new()
	var bad = _rule("off_rule", "?? bad ??")
	bad.enabled = false
	c5.setup([bad])
	check(c5.parse_errors().is_empty(), "disabled rule skipped, no parse error")

	# identifier la -> parse ok nhung execute null -> parse_errors (Review Focus #3)
	var c6 = core_script.new()
	c6.setup([_rule("typo_rule", "knowlege >= 50")])
	c6.refresh(gs)
	check(not c6.parse_errors().is_empty(), "unknown identifier reported")
	check_eq(c6.is_unlocked("typo_rule"), false, "unknown identifier -> locked")

	# parse error syntax -> parse_errors
	var c7 = core_script.new()
	c7.setup([_rule("syntax_rule", "knowledge >= 50 ??")])
	check(not c7.parse_errors().is_empty(), "syntax error reported")

	# GameState thieu field -> khong crash, fallback 0 (spec §5)
	var c8 = core_script.new()
	c8.setup([_rule("safe_rule", "knowledge >= 50")])
	c8.refresh(Node.new())
	check_eq(c8.is_unlocked("safe_rule"), false, "bare Node fallback -> locked")
	check(c8.parse_errors().is_empty(), "fallback khong tao loi gia mao")

	check_eq(c1.unlocked_ids().size(), 1, "unlocked_ids size")

	# short-circuit: operand trai false -> operand phai khong chay, khong loi
	var c9 = core_script.new()
	c9.setup([_rule("sc_rule", 'knowledge >= 50 and has_project("p1")')])
	gs.knowledge = 0
	var none: Array[StringName] = []
	gs.completed_projects = none
	c9.refresh(gs)
	check_eq(c9.is_unlocked("sc_rule"), false, "short-circuit false -> locked")
	check(c9.parse_errors().is_empty(), "short-circuit khong tao loi")
