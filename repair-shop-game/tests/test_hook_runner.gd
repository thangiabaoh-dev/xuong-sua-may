extends "res://tests/test_case.gd"

func run() -> void:
	var hr = load("res://scripts/data/hook_runner.gd")
	check(hr != null, "hook_runner loads")
	if hr == null:
		return
	var gs = load("res://scripts/autoload/game_state.gd").new()

	# hook rỗng -> {} + state giu nguyen (spec 6)
	var g = hr.apply(gs, "", 135)
	check_eq(g.size(), 0, "empty hook -> empty gains")
	check_eq(int(gs.knowledge), 0, "empty hook: knowledge unchanged")

	# rate x phut: 0.03 x 135 = 4.05 -> +4, remainder 0.05
	g = hr.apply(gs, "knowledge_rate:0.03", 135)
	check_eq(int(g.get("knowledge", -1)), 4, "0.03x135 -> +4")
	check_eq(int(gs.knowledge), 4, "knowledge = 4")
	check_near(float(gs.knowledge_remainder), 0.05, 0.001, "remainder 0.05")

	# remainder cong don (RF2): 0.06 x 10 = 0.6 -> lan 1 +0, lan 2 +1 (rem 0.65 -> 0.25)
	g = hr.apply(gs, "knowledge_rate:0.06", 10)
	check_eq(g.size(), 0, "sub-unit gain -> no knowledge key")
	check_eq(int(gs.knowledge), 4, "first 0.6: no int gain")
	check_near(float(gs.knowledge_remainder), 0.65, 0.001, "rem 0.05+0.6")
	g = hr.apply(gs, "knowledge_rate:0.06", 10)
	check_eq(int(g.get("knowledge", -1)), 1, "second 0.6 -> +1")
	check_eq(int(gs.knowledge), 5, "knowledge 5")
	check_near(float(gs.knowledge_remainder), 0.25, 0.001, "rem 0.25")

	# key la -> warn + bo qua, pair tot ke ben van chay (spec 6)
	var k0 := int(gs.knowledge)
	g = hr.apply(gs, "foo:1,knowledge_rate:0.01", 100)
	check_eq(int(g.get("knowledge", -1)), 1, "good pair runs despite bad key")
	check_eq(int(gs.knowledge), k0 + 1, "knowledge from good pair")

	# rate am -> warn + khong doi (spec 6)
	k0 = int(gs.knowledge)
	var r0 := float(gs.knowledge_remainder)
	g = hr.apply(gs, "knowledge_rate:-0.5", 100)
	check_eq(g.size(), 0, "negative rate -> no gains")
	check_eq(int(gs.knowledge), k0, "negative rate: knowledge unchanged")
	check_near(float(gs.knowledge_remainder), r0, 0.001, "negative rate: remainder unchanged")

	# value rac -> warn + khong doi (spec 6)
	g = hr.apply(gs, "knowledge_rate:abc", 100)
	check_eq(g.size(), 0, "bad value -> no gains")
	check_eq(int(gs.knowledge), k0, "bad value: knowledge unchanged")

	# RF2: begin_new_day KHONG reset remainder (spec 3.2)
	gs.knowledge_remainder = 0.7
	gs.begin_new_day()
	check_near(float(gs.knowledge_remainder), 0.7, 0.001, "remainder survives begin_new_day")

	# source pin: push_warning ton tai (spec 8)
	var f = FileAccess.open("res://scripts/data/hook_runner.gd", FileAccess.READ)
	check(f != null and f.get_as_text().contains("push_warning"), "bad hook warns (source pin)")
	gs.free()
