extends "res://tests/test_case.gd"

func run() -> void:
	var gs = load("res://scripts/autoload/game_state.gd").new()
	var core = load("res://scripts/schedule_core.gd")
	var gscript = load("res://scripts/autoload/game_state.gd")
	# vao slot REPAIR cua T2 de shift_tick co tinh
	gs.minute = 1020
	check_eq(core.shift_budget(gs), 120, "weekday budget 120")
	check_eq(core.shift_tick(gs, 100), true, "100 < 120 ok")
	check_eq(int(gs.shift_used), 100, "shift_used 100")
	check_eq(core.shift_tick(gs, 30), false, "130 >= 120 exhausted")

	# ngoai slot repair -> khong tinh
	gs.shift_used = 0
	gs.minute = 420
	check_eq(core.shift_tick(gs, 50), true, "no-op outside repair slot")
	check_eq(int(gs.shift_used), 0, "not counted outside repair")

	# CN: window1 + BREAK + window2 gop budget
	gs.date = {"year": 2026, "month": 10, "day": 11}  # CN
	gs.shift_used = 0
	check_eq(core.shift_budget(gs), 510, "CN budget 510")
	gs.minute = 540  # REPAIR window1
	check_eq(core.shift_tick(gs, 180), true, "window1 used 180")
	gs.minute = 760  # BREAK 12:40 — khong tinh, khong reset
	check_eq(core.shift_tick(gs, 30), true, "BREAK no-op")
	check_eq(int(gs.shift_used), 180, "shift_used survives BREAK")
	gs.minute = 810  # window2
	check_eq(core.shift_tick(gs, 330), false, "510 exhausted at end window2")

	# T3 khong co ca sua
	gs.date = {"year": 2026, "month": 10, "day": 6}  # T3
	check_eq(core.shift_budget(gs), 0, "T3 budget 0")

	var rs_script = load("res://scripts/repair/repair_session.gd")

	# session het budget giua ca -> LOST_TIME
	gs.date = {"year": 2026, "month": 10, "day": 5}
	gs.minute = 1030
	gs.mode = gscript.GameStateMode.REPAIR
	gs.shift_used = 110
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 1
	var order1 = load("res://scripts/orders/order_factory.gd").make(rng1, {"knowledge": 0, "uy_tin": 0, "project_count": 0})
	var sess1 = rs_script.new(order1, gs, rng1)
	var hit1 = sess1._add_minutes(20)  # 110+20=130 > 120
	check_eq(hit1, true, "budget forced timeout true")
	check_eq(int(sess1.result), int(rs_script.Result.LOST_TIME), "LOST_TIME on budget exhaust")
	check_eq(int(gs.shift_used), 130, "counted 20 in slot")

	# 1320 giua ca -> LOST_TIME + clamp + SUMMARIZE (Review Focus #1)
	gs.shift_used = 0
	gs.minute = 1310
	gs.mode = gscript.GameStateMode.REPAIR
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 2
	var order2 = load("res://scripts/orders/order_factory.gd").make(rng2, {"knowledge": 0, "uy_tin": 0, "project_count": 0})
	var sess2 = rs_script.new(order2, gs, rng2)
	var hit2 = sess2._add_minutes(15)  # 1310 + 15 = 1325
	check_eq(hit2, true, "timeout true")
	check_eq(int(sess2.result), int(rs_script.Result.LOST_TIME), "LOST_TIME before SUMMARIZE")
	check_eq(int(gs.mode), int(gscript.GameStateMode.SUMMARIZE), "mode SUMMARIZE")
	check_eq(int(gs.minute), 1320, "minute clamped at 1320")
