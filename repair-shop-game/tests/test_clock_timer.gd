extends "res://tests/test_case.gd"

func run() -> void:
	var ct_script = load("res://scripts/clock_timer.gd")
	check(ct_script != null, "clock_timer.gd loads")
	if ct_script == null:
		return
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var gs = gs_script.new()
	var ct = ct_script.new()
	ct.setup(gs)
	var box := [-1, -1]
	ct.minute_changed.connect(func(old_m, new_m): box[0] = old_m; box[1] = new_m)

	# SCHEDULE: khong tick
	ct.tick(5.0)
	check_eq(gs.minute, 420, "no tick in SCHEDULE")

	# REPAIR: khong con realtime tick (spec Q1)
	gs.mode = gs_script.GameStateMode.REPAIR
	var m_before: int = gs.minute
	ct.tick(5.0)
	check_eq(gs.minute, m_before, "tick does not advance minute")

	# F5 toggle + release ignore
	var ev = InputEventKey.new()
	ev.keycode = KEY_F5
	ev.pressed = true
	ct._unhandled_input(ev)
	check_eq(gs.mode, gs_script.GameStateMode.SCHEDULE, "F5 press -> SCHEDULE")
	ct.tick(3.0)
	check_eq(gs.minute, 420, "no tick after toggle off")
	ct._unhandled_input(ev)
	check_eq(gs.mode, gs_script.GameStateMode.REPAIR, "F5 press -> REPAIR again")
	ev.pressed = false
	ct._unhandled_input(ev)
	check_eq(gs.mode, gs_script.GameStateMode.REPAIR, "F5 release ignored")

	# F6 +30
	ev.keycode = KEY_F6
	ev.pressed = true
	ct._unhandled_input(ev)
	check_eq(gs.minute, 450, "F6 +30 min")
	check_eq(box[1], 450, "F6 emits")

	# F7 -> SUMMARIZE (khong con auto reset)
	ev.keycode = KEY_F7
	ev.pressed = true
	ct._unhandled_input(ev)
	check_eq(int(gs.mode), int(gs_script.GameStateMode.SUMMARIZE), "F7 -> SUMMARIZE")
	check_eq(gs.date["day"], 5, "date unchanged until sleep (van 5/10)")
	gs.begin_new_day()
	check_eq(gs.minute, 420, "reset after sleep")
	check_eq(gs.date["day"], 6, "date +1 after sleep")
	check_eq(int(gs.mode), int(gs_script.GameStateMode.SCHEDULE), "SCHEDULE after sleep")

	# tick qua 22:00: khong con realtime — advance_to moi dua den SUMMARIZE
	gs.mode = gs_script.GameStateMode.REPAIR
	gs.minute = 1319
	ct.tick(2.0)
	check_eq(gs.minute, 1319, "tick never crosses 22:00 by itself")
	ct.tick(60.0)
	check_eq(gs.minute, 1319, "still no realtime advance")
	gs.advance_to(1320)
	check_eq(gs.minute, 1320, "advance_to clamps at 1320")
	check_eq(gs.mode, gs_script.GameStateMode.SUMMARIZE, "mode SUMMARIZE after end_day")
	check_eq(gs.date["day"], 6, "date unchanged until begin_new_day")
	ct.tick(60.0)
	check_eq(gs.minute, 1320, "not ticking in SUMMARIZE")
	gs.begin_new_day()
	check_eq(gs.minute, 420, "07:00 after begin_new_day")
	check_eq(gs.date["day"], 7, "date +1 after begin_new_day")
	check_eq(gs.mode, gs_script.GameStateMode.SCHEDULE, "SCHEDULE after begin_new_day")
	ct.tick(60.0)
	check_eq(gs.minute, 420, "not ticking in SCHEDULE")
	check_eq(gs.date["day"], 7, "date untouched by extra ticks")

	ct.free()
