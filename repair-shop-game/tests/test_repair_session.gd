extends "res://tests/test_case.gd"

func _make_order(fault_key: String = "no_power") -> RepairOrder:
	var def: MachineDef = load("res://data/machines/acer_aspire_5.tres")
	var gm := GeneratedMachine.new()
	gm.def = def
	gm.fault = StringName(fault_key)
	gm.price = def.base_price
	var o := RepairOrder.new()
	o.machine = gm
	o.fault_key = fault_key
	o.customer_key = "ban_hoc"
	o.symptom_quote = FaultCatalog.get_fault(fault_key).symptoms["ban_hoc"]
	o.deadline_min = 30 + def.difficulty * 15
	o.money_reward = def.base_price
	return o

func _state(money := 50000, uy_tin := 0):
	var s = load("res://scripts/autoload/game_state.gd").new()
	s.money = money
	s.uy_tin = uy_tin
	return s

func _rng(seed_v: int = 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return r

func run() -> void:
	# 1. Happy path: 2 checks -> dung -> mua -> thao-lap -> chay thu -> DONE
	var st = _state()
	var s := RepairSession.new(_make_order(), st, _rng())
	check_eq(int(s.state), int(RepairSession.State.OFFER), "starts OFFER")
	s.accept(); check_eq(int(s.state), int(RepairSession.State.SYMPTOM), "accept->SYMPTOM")
	s.advance_symptom(); check_eq(int(s.state), int(RepairSession.State.CHECKS), "->CHECKS")
	check(not s.can_conclude(), "need >=2 checks")
	var clue := s.do_check("do_nguon")
	check(clue != "", "do_check returns clue")
	var cell = FaultCatalog.get_fault("no_power").check_outcomes["do_nguon"]
	for ex in cell["excludes"]:
		check(not s.suspects.has(String(ex)), "excludes applied: " + String(ex))
	s.do_check("nghe_quat")
	check(s.can_conclude(), "can conclude after2")
	s.begin_conclusion(); check_eq(int(s.state), int(RepairSession.State.CONCLUSION), "->CONCLUSION")
	check(s.conclude("no_power"), "correct conclusion")
	check_eq(int(s.state), int(RepairSession.State.PARTS), "->PARTS")
	check_eq(st.money, 50000, "money untouched before buy")
	check(s.buy_part(), "buy ok")
	check_eq(st.money, 5000, "money after part45000")
	check_eq(s.spent, 45000, "spent part")
	check_eq(int(s.state), int(RepairSession.State.DISASSEMBLE), "->DISASSEMBLE")
	s.disassemble(); check_eq(int(s.state), int(RepairSession.State.TEST), "->TEST")
	s.run_test()
	check_eq(int(s.state), int(RepairSession.State.RESULT), "->RESULT")
	check_eq(int(s.result), int(RepairSession.Result.DONE), "DONE")
	check_eq(s.earned, 80000, "reward no tip")
	check_eq(st.money, 5000 + 80000, "money after handoff")

	# 2. Reject 0 phat
	var s2 := RepairSession.new(_make_order(), _state(), _rng())
	s2.reject()
	check_eq(int(s2.result), int(RepairSession.Result.REJECTED), "rejected")
	check_eq(s2.elapsed, 0, "reject no time")

	# 3. Sai -> phat + loai nghi pham + sai lan>=2 tru uy_tin
	var st3 = _state(50000, 10)
	var s3 := RepairSession.new(_make_order(), st3, _rng())
	s3.accept(); s3.advance_symptom()
	s3.do_check("do_nguon"); s3.do_check("nghe_quat")
	s3.begin_conclusion()
	check(not s3.conclude("overheat"), "wrong returns false")
	check_eq(s3.elapsed, 10 + 15, "wrong +15'")
	check_eq(st3.money, 30000, "wrong -20000")
	check(not s3.suspects.has("overheat"), "wrong suspect removed")
	check_eq(int(s3.state), int(RepairSession.State.CHECKS), "back to CHECKS")
	check_eq(s3.wrong_count, 1, "wrong_count1")
	check_eq(st3.uy_tin, 10, "uy_tin untouched at wrong1")
	s3.begin_conclusion()
	s3.conclude("loose_port")
	check_eq(s3.wrong_count, 2, "wrong_count2")
	check_eq(st3.uy_tin, 5, "uy_tin -5 at wrong>=2")

	# 4. Timeout sau do_check -> LOST_TIME
	var s4 := RepairSession.new(_make_order(), _state(), _rng())
	s4.accept(); s4.advance_symptom()
	s4.elapsed = 56
	s4.do_check("do_nguon")
	check_eq(int(s4.state), int(RepairSession.State.RESULT), "timeout -> RESULT")
	check_eq(int(s4.result), int(RepairSession.Result.LOST_TIME), "LOST_TIME")

	# 5. Money clamp khong am
	var st5 = _state(10000, 0)
	var s5 := RepairSession.new(_make_order(), st5, _rng())
	s5.accept(); s5.advance_symptom()
	s5.do_check("do_nguon"); s5.do_check("nghe_quat")
	s5.begin_conclusion(); s5.conclude("overheat")
	check_eq(st5.money, 0, "money clamp at0")
	s5.begin_conclusion(); s5.conclude("loose_port")
	check_eq(st5.money, 0, "money stays0")

	# 6. Tip boundary: elapsedx2 == deadline VAN duoc tip
	var s6 := RepairSession.new(_make_order(), _state(), _rng())
	s6.accept(); s6.advance_symptom()
	s6.do_check("do_nguon"); s6.do_check("nghe_quat")
	s6.begin_conclusion(); s6.conclude("no_power")
	s6.buy_part(); s6.disassemble()
	s6.elapsed = 20
	s6.run_test()
	check_eq(int(s6.result), int(RepairSession.Result.DONE), "done at boundary")
	check_eq(s6.earned, 80000 + 20000, "tip at boundary")

	# 7. Hoi tu: vet nghi pham bang cach sai lien tiep van toi loi that
	var s7 := RepairSession.new(_make_order("overheat"), _state(), _rng())
	s7.accept(); s7.advance_symptom()
	s7.do_check("do_nguon"); s7.do_check("nhin_bo")
	var guard := 0
	while not s7.can_conclude() and guard < 5:
		s7.do_check(s7.CHECK_KEYS[guard % 4]); guard += 1
	while s7.suspects.size() > 1 and guard < 10:
		guard += 1
		s7.begin_conclusion()
		for cand in s7.suspects:
			if cand != "overheat":
				s7.conclude(cand)
				break
	check(s7.suspects.has("overheat"), "true fault survives")
	s7.begin_conclusion()
	check(s7.conclude("overheat"), "converged to true fault")

	# 8. Het tien o PARTS -> give_up LOST_MONEY; buy false giu PARTS
	var st8 = _state(10000, 0)
	var s8 := RepairSession.new(_make_order(), st8, _rng())
	s8.accept(); s8.advance_symptom()
	s8.do_check("do_nguon"); s8.do_check("nghe_quat")
	s8.begin_conclusion(); s8.conclude("no_power")
	check(not s8.buy_part(), "buy fails with10000")
	check_eq(int(s8.state), int(RepairSession.State.PARTS), "stays PARTS")
	s8.give_up()
	check_eq(int(s8.result), int(RepairSession.Result.LOST_MONEY), "LOST_MONEY")
