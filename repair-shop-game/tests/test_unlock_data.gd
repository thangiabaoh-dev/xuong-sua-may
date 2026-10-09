extends "res://tests/test_case.gd"

func run() -> void:
	var set = load("res://data/unlock_rules.tres")
	check(set != null, "unlock_rules.tres loads")
	if set == null:
		return
	check(set.rules.size() == 4, "4 rules")
	var ids: Array = []
	for r in set.rules:
		ids.append(String(r.id))
	for want in ["may_co", "may_phuc_tap", "khach_giao_vien", "khach_phong_tin"]:
		check(ids.has(want), "has rule %s" % want)

	var core_script = load("res://scripts/progression/unlock_core.gd")
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var core = core_script.new()
	core.setup(set.rules)
	check(core.parse_errors().is_empty(), "tat ca rule parse OK")

	var gs = gs_script.new()
	core.refresh(gs)
	check(core.parse_errors().is_empty(), "khong evaluate null (Review Focus #3)")
	check_eq(core.unlocked_ids().size(), 0, "mac dinh khong co gi mo khoa")
	check_eq(gs.money, 50000, "tien dau game 50000 (khong bi rule nao an)")

	# spec §6: moi rule trong .tres execute tra bool tren ctx mac dinh
	var ctx2 = load("res://scripts/progression/unlock_context.gd").new()
	var def_inputs: Array = [50000, 0, 0, 100, 0]
	for r in set.rules:
		var ex := Expression.new()
		check_eq(ex.parse(String(r.condition), core_script.INPUT_NAMES), OK, "parse %s" % r.id)
		var res = ex.execute(def_inputs, ctx2, false)
		check(res is bool, "rule %s tra bool" % r.id)
