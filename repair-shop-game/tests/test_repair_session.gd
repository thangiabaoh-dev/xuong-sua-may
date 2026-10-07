extends "res://tests/test_case.gd"

func _make_order(fault_key: String = "no_power", customer_key: String = "ban_hoc") -> RepairOrder:
	var def: MachineDef = load("res://data/machines/acer_aspire_5.tres")
	var gm := GeneratedMachine.new()
	gm.def = def
	gm.fault = StringName(fault_key)
	gm.price = def.base_price
	var o := RepairOrder.new()
	o.machine = gm
	o.fault_key = fault_key
	o.customer_key = customer_key
	o.symptom_quote = FaultCatalog.get_fault(fault_key).symptoms[customer_key]
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

func _rng42() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 42
	return r

func _rng_seed(v: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = v
	return r

func _flow_to_disassemble(s: RepairSession) -> void:
	s.accept(); s.advance_symptom()
	s.do_check("do_nguon"); s.do_check("nghe_quat")
	s.begin_conclusion(); s.conclude("no_power")
	s.buy_part()

func _flow_to_test(s: RepairSession) -> void:
	_flow_to_disassemble(s)
	s.disassemble()

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
	check_eq(int(s.state), int(RepairSession.State.TONE), "run_test -> TONE")
	check(s.choose_tone("trung_tinh"), "neutral tone")
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
	check_eq(st3.uy_tin, 8, "uy_tin -2 at wrong1")
	s3.begin_conclusion()
	s3.conclude("loose_port")
	check_eq(s3.wrong_count, 2, "wrong_count2")
	check_eq(st3.uy_tin, 1, "uy_tin -7 at wrong>=2")

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
	check_eq(int(s6.state), int(RepairSession.State.TONE), "boundary -> TONE")
	check(s6.choose_tone("trung_tinh"), "neutral tone")
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

	# 11. TONE: neutral ban_hoc DONE khong tip them
	var s11 := RepairSession.new(_make_order(), _state(), _rng())
	_flow_to_test(s11)
	s11.run_test()
	check_eq(int(s11.state), int(RepairSession.State.TONE), "run_test -> TONE")
	check(not s11.choose_tone("xxx"), "invalid tone no-op")
	check_eq(int(s11.state), int(RepairSession.State.TONE), "still TONE")
	check(s11.choose_tone("trung_tinh"), "neutral ok")
	check_eq(int(s11.result), int(RepairSession.Result.DONE), "neutral DONE")
	check_eq(s11.earned, 80000, "neutral no extra tip")

	# 12. LOST_TONE: ban_hoc kho khong tra
	var st12 = _state(50000, 0)
	var s12 := RepairSession.new(_make_order(), st12, _rng())
	_flow_to_test(s12)
	s12.run_test()
	check(s12.choose_tone("kho"), "kho accepted")
	check_eq(int(s12.result), int(RepairSession.Result.LOST_TONE), "LOST_TONE")
	check_eq(s12.earned, 0, "lost no earn")
	check_eq(st12.money, 5000, "lost no pay (only part cost 45000)")
	check(s12.tone_reaction != "", "reaction recorded")

	# 13. Tip cong don: than + early = 80000 + 20000 + 8000
	var st13 = _state(50000, 0)
	var s13 := RepairSession.new(_make_order(), st13, _rng())
	_flow_to_test(s13)
	s13.elapsed = 0
	s13.run_test()
	check(s13.choose_tone("than"), "than ok")
	check_eq(s13.earned, 80000 + 20000 + 8000, "tip stacked")
	check_eq(st13.money, 5000 + 108000, "money with stacked tips (after part)")

	# 14. uy_tin clamp: giao_vien kho tai uy_tin=0 van 0
	var st14 = _state(50000, 0)
	var o14 := _make_order("no_power", "giao_vien")
	var s14 := RepairSession.new(o14, st14, _rng())
	_flow_to_test(s14)
	s14.run_test()
	check(s14.choose_tone("kho"), "giao_vien kho")
	check_eq(int(s14.result), int(RepairSession.Result.DONE), "giao_vien kho still DONE")
	check_eq(st14.uy_tin, 6, "tone -3 clamp0 + gv done6")

	# 15. Timeout trong run_test -> LOST_TIME bo qua TONE
	var s15 := RepairSession.new(_make_order(), _state(), _rng())
	_flow_to_test(s15)
	s15.elapsed = s15.order.deadline_min - 4
	s15.run_test()
	check_eq(int(s15.state), int(RepairSession.State.RESULT), "timeout skips TONE")
	check_eq(int(s15.result), int(RepairSession.Result.LOST_TIME), "LOST_TIME")
	check(not s15.choose_tone("than"), "tone guard after result")

	# 16. uy_tin clamp ≤100 (spec §1 range 0-100)
	var st16 = _state(50000, 98)
	var o16 := _make_order("no_power", "giao_vien")
	var s16 := RepairSession.new(o16, st16, _rng())
	_flow_to_test(s16)
	s16.run_test()
	check(s16.choose_tone("than"), "giao_vien than ok")
	check_eq(st16.uy_tin, 100, "uy_tin clamped at 100")

	# 17. effect positive + story append (spec §8 hoai_niem than)
	var st17 = _state(50000, 0)
	var o17 := _make_order("no_power", "hoai_niem")
	var s17 := RepairSession.new(o17, st17, _rng())
	_flow_to_test(s17)
	s17.run_test()
	check(s17.choose_tone("than"), "hoai_niem than ok")
	check_eq(st17.uy_tin, 5, "tone3 + done2")
	check(s17.tone_reaction.contains("chợ Lớn"), "story appended")

	# 18. begin_minigame: guard state + đúng kind/difficulty + idempotent
	var s18 := RepairSession.new(_make_order(), _state(), _rng())
	check(s18.begin_minigame() == null, "begin null sai state")
	_flow_to_disassemble(s18)
	check_eq(int(s18.state), int(RepairSession.State.DISASSEMBLE), "at DISASSEMBLE")
	var c18 := s18.begin_minigame()
	check(c18 != null, "begin ok")
	check(c18 == s18.begin_minigame(), "idempotent")
	check_eq(c18.kind, int(MinigameController.Kind.VAN_OC), "no_power -> van_oc")
	check_eq(c18.difficulty, 2, "difficulty từ máy")

	# 19. fail: +2 phút, reset, không trừ tiền, vẫn DISASSEMBLE
	var st19 = _state()
	var s19 := RepairSession.new(_make_order(), st19, _rng())
	check(not s19.minigame_fail(), "fail guard null")
	_flow_to_disassemble(s19)
	var c19 := s19.begin_minigame()
	c19.needle_pos = c19.zone_lo - 0.01
	c19.press()
	check(c19.failed, "attempt failed")
	check(s19.minigame_fail(), "fail applied")
	check_eq(int(s19.state), int(RepairSession.State.DISASSEMBLE), "stay DISASSEMBLE")
	check_eq(s19.elapsed, 20 + 2, "elapsed 20 + fail2")
	check_eq(int(st19.money), 5000, "fail không trừ tiền")
	check(not c19.failed, "controller reset")
	check_eq(c19.progress, 0, "progress reset")

	# 20. fail qua hạn -> LOST_TIME (không kẹt DISASSEMBLE)
	var st20 = _state()
	var s20 := RepairSession.new(_make_order(), st20, _rng())
	_flow_to_disassemble(s20)
	s20.begin_minigame()
	s20.elapsed = s20.order.deadline_min - 1
	check(s20.minigame_fail(), "fail consumed")
	check_eq(int(s20.state), int(RepairSession.State.RESULT), "->RESULT")
	check_eq(int(s20.result), int(RepairSession.Result.LOST_TIME), "LOST_TIME")
	check(not s20.minigame_fail(), "fail guard sau RESULT")

	# 21. pass: phí giữ nguyên 5×difficulty, minigame clear
	var st21 = _state()
	var s21 := RepairSession.new(_make_order(), st21, _rng())
	_flow_to_disassemble(s21)
	s21.begin_minigame()
	s21.disassemble()
	check_eq(int(s21.state), int(RepairSession.State.TEST), "pass -> TEST")
	check_eq(s21.elapsed, 20 + 5 * 2, "phí 5×difficulty")
	check(s21.minigame == null, "minigame cleared")

	# 22. DONE bonus: +2 thuong / +6 giao_vien / LOST_TONE khong bonus
	var st22 = _state(50000, 0)
	var s22 := RepairSession.new(_make_order(), st22, _rng())
	_flow_to_test(s22)
	s22.run_test()
	check(s22.choose_tone("trung_tinh"), "neutral ok")
	check_eq(int(st22.uy_tin), 2, "ban_hoc DONE +2")
	var o23 := _make_order("no_power", "giao_vien")
	var st23 = _state(50000, 0)
	var s23 := RepairSession.new(o23, st23, _rng())
	_flow_to_test(s23)
	s23.run_test()
	check(s23.choose_tone("trung_tinh"), "gv neutral")
	check_eq(int(st23.uy_tin), 6, "giao_vien DONE +6")
	var o24 := _make_order("no_power", "giao_vien")
	var st24 = _state(50000, 0)
	var s24 := RepairSession.new(o24, st24, _rng())
	_flow_to_test(s24)
	s24.run_test()
	check(s24.choose_tone("than"), "gv than")
	check_eq(int(st24.uy_tin), 9, "gv than = tone3 + done6")
	var st25 = _state(50000, 10)
	var s25 := RepairSession.new(_make_order(), st25, _rng())
	_flow_to_test(s25)
	s25.run_test()
	check(s25.choose_tone("kho"), "ban_hoc kho -> LOST_TONE")
	check_eq(int(st25.uy_tin), 10, "LOST_TONE khong bonus")

	# 23. roll_event: guard state + guard event_active + chinh rng
	var s26 := RepairSession.new(_make_order(), _state(), _rng())
	s26.accept()
	check(not s26.roll_event(), "roll bi chan khi SYMPTOM")
	s26.advance_symptom()
	check_eq(int(s26.state), int(RepairSession.State.CHECKS), "at CHECKS")
	s26.event_active = true
	check(not s26.roll_event(), "roll bi chan khi event dang mo")
	s26.event_active = false
	var probe := RandomNumberGenerator.new()
	probe.seed = 42
	var v42 := probe.randf()
	var s27 := RepairSession.new(_make_order(), _state(), _rng42())
	s27.accept()
	s27.advance_symptom()
	check_eq(s27.roll_event(), v42 < 0.15, "roll theo chinh rng")
	check_eq(s27.event_active, v42 < 0.15, "event_active theo rng")
	var fire_seed := -1
	for si in 100:
		var pr2 := RandomNumberGenerator.new()
		pr2.seed = si
		if pr2.randf() < 0.15:
			fire_seed = si
			break
	check(fire_seed > 0, "tim duoc seed ban")
	var s28 := RepairSession.new(_make_order(), _state(), _rng_seed(fire_seed))
	s28.accept()
	s28.advance_symptom()
	check(s28.roll_event(), "event ban duoc voi seed tim duoc")
	check(s28.event_active, "event_active true")

	# 24. resolve 3 lua chon + invalid + guard
	var st29 = _state(50000, 0)
	st29.ky_luat = 100
	var s29 := RepairSession.new(_make_order(), st29, _rng())
	_flow_to_disassemble(s29)
	check(not s29.resolve_event("kiem_cheu"), "resolve khi chua co event")
	s29.event_active = true
	check(not s29.resolve_event("xxx"), "invalid choice false")
	check(s29.event_active, "invalid giu event")
	var e0: int = s29.elapsed
	check(s29.resolve_event("kiem_cheu"), "kiem che ok")
	check(not s29.event_active, "event dong")
	check_eq(s29.elapsed, e0 + 5, "kiem che +5")
	check_eq(int(st29.uy_tin), 0, "kiem che khong uy_tin")
	s29.event_active = true
	var e1: int = s29.elapsed
	st29.uy_tin = 10
	check(s29.resolve_event("cai_lai"), "cai lai ok")
	check_eq(s29.elapsed, e1 + 10, "cai lai +10")
	check_eq(int(st29.uy_tin), 8, "cai lai uy_tin -2")
	s29.event_active = true
	var e2: int = s29.elapsed
	st29.uy_tin = 50
	check(s29.resolve_event("danh_nhau"), "danh nhau ok")
	check_eq(s29.elapsed, e2 + 15, "danh nhau +15")
	check_eq(int(st29.uy_tin), 40, "danh nhau uy_tin -10")
	check_eq(int(st29.ky_luat), 80, "danh nhau ky_luat -20")
	st29.ky_luat = 10
	s29.elapsed = 0
	s29.event_active = true
	check(s29.resolve_event("danh_nhau"), "danh nhau lan 2")
	check_eq(int(st29.ky_luat), 0, "ky_luat clamp 0")

	# 25. resolve qua han -> LOST_TIME, event_active xoa
	var st30 = _state(50000, 0)
	var s30 := RepairSession.new(_make_order(), st30, _rng())
	_flow_to_disassemble(s30)
	s30.event_active = true
	s30.elapsed = s30.order.deadline_min - 3
	check(s30.resolve_event("danh_nhau"), "resolve consumed")
	check_eq(int(s30.state), int(RepairSession.State.RESULT), "->RESULT")
	check_eq(int(s30.result), int(RepairSession.Result.LOST_TIME), "LOST_TIME")
	check(not s30.event_active, "event xoa sau timeout")
	check(not s30.resolve_event("kiem_cheu"), "resolve guard sau RESULT")

	#9. Stock: lay tu kho 0dong/0 phut, tru count; het stock -> buy ngay
	var st9 = _state(50000, 0)
	var s9 := RepairSession.new(_make_order(), st9, _rng())
	check(s9.has_method("stock_available"), "has stock_available")
	check(s9.has_method("take_part_from_stock"), "has take_part_from_stock")
	if not s9.has_method("stock_available") or not s9.has_method("take_part_from_stock"):
		return
	check(not s9.stock_available(), "stock check fails outside PARTS")
	s9.accept(); s9.advance_symptom()
	s9.do_check("do_nguon"); s9.do_check("nghe_quat")
	s9.begin_conclusion(); s9.conclude("no_power")
	var part9 = FaultCatalog.get_fault("no_power").part_id
	st9.inventory[part9] = 1
	check(s9.stock_available(), "stock available at PARTS")
	check(s9.take_part_from_stock(), "take from stock ok")
	check_eq(int(st9.inventory[part9]), 0, "stock decremented")
	check_eq(st9.money, 50000, "stock costs 0 money")
	check_eq(s9.elapsed, 10, "stock costs 0 minutes")
	check_eq(int(s9.state), int(RepairSession.State.DISASSEMBLE), "stock -> DISASSEMBLE")
	var s10 := RepairSession.new(_make_order(), _state(50000, 0), _rng())
	s10.accept(); s10.advance_symptom()
	s10.do_check("do_nguon"); s10.do_check("nghe_quat")
	s10.begin_conclusion(); s10.conclude("no_power")
	check(not s10.stock_available(), "no stock")
	check(s10.buy_part(), "buy when no stock")
	check_eq(s10.elapsed, 10 + 10, "buy +10 minutes")
