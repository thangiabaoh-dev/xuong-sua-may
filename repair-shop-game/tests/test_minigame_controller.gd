extends "res://tests/test_case.gd"

func run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# create + kind
	var voc := MinigameController.create("van_oc", 2, rng)
	check(voc != null and voc.kind == int(MinigameController.Kind.VAN_OC), "kind mapping")
	check(MinigameController.create("xxx", 1, rng) == null, "unknown key null")
	check_eq(voc.beats_needed, 4, "beats = difficulty*2")
	check_eq(voc.difficulty, 2, "difficulty kept")
	# van_oc: trong vùng +1 nhịp
	voc.needle_pos = (voc.zone_lo + voc.zone_hi) * 0.5
	check(voc.press(), "in-zone press true")
	check_eq(voc.progress, 1, "progress 1")
	check(not voc.passed and not voc.failed, "not done")
	# van_oc: ngoài vùng -> failed
	voc.needle_pos = voc.zone_lo - 0.01
	check(not voc.press(), "out-zone press false")
	check(voc.failed, "failed flag")
	# reset không carry-over
	voc.reset()
	check(not voc.failed and not voc.passed, "reset flags")
	check_eq(voc.progress, 0, "reset progress")
	# van_oc: đủ nhịp -> passed
	for i in voc.beats_needed:
		voc.needle_pos = (voc.zone_lo + voc.zone_hi) * 0.5
		voc.press()
	check(voc.passed, "passed after all beats")
	check(not voc.press(), "press after done false")
	# tick di chuyển kim (0.8*0.5 = 0.4)
	var moc := MinigameController.create("van_oc", 1, rng)
	moc.tick(0.5)
	check_eq(moc.needle_pos, 0.4, "needle moves")
	# han_mach
	var hmc := MinigameController.create("han_mach", 1, rng)
	check_eq(hmc.hold_need, 1.0, "hold_need = difficulty")
	hmc.hold(0.4); hmc.hold(0.4)
	check(not hmc.passed, "not enough hold")
	hmc.hold(0.3)
	check(hmc.passed, "passed >= need")
	var hmc2 := MinigameController.create("han_mach", 2, rng)
	hmc2.hold(1.0); hmc2.release()
	check_eq(hmc2.held, 0.0, "release resets")
	hmc2.hold(1.5)
	check(not hmc2.passed, "streak broken")
	# cam_cap
	var ccc := MinigameController.create("cam_cap", 1, rng)
	check_eq(ccc.port_count, 3, "d<=2 3 ports")
	var ccc4 := MinigameController.create("cam_cap", 3, rng)
	check_eq(ccc4.port_count, 4, "d>2 4 ports")
	check(not ccc.select((ccc.correct_port + 1) % ccc.port_count, ccc.correct_orientation), "wrong port false")
	check(ccc.failed, "wrong -> failed")
	var ccc3 := MinigameController.create("cam_cap", 2, rng)
	check(not ccc3.select(ccc3.correct_port, 5), "invalid orientation false")
	check(not ccc3.failed, "invalid input khong set failed")
	var c2 := MinigameController.create("cam_cap", 4, rng)
	check(c2.select(c2.correct_port, c2.correct_orientation), "correct true")
	check(c2.passed, "correct -> passed")
	# lau_bui
	var lbc := MinigameController.create("lau_bui", 1, rng)
	check(not lbc.wipe(999), "invalid cell false")
	for i in 80:
		check(lbc.wipe(i), "cell %d new" % i)
	check_eq(lbc.wiped, 80, "80 cells")
	check(lbc.passed, "80% pass")
	check(not lbc.wipe(0), "duplicate ignored")
	var lb2 := MinigameController.create("lau_bui", 1, rng)
	for i in 100:
		lb2.wipe_random()
	check_eq(lb2.wiped, 80, "dung o 80 khi passed")
	check(lb2.passed, "random pass")
