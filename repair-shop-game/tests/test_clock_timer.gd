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

	# REPAIR: 1 game min / SECONDS_PER_GAME_MINUTE
	gs.mode = gs_script.GameStateMode.REPAIR
	ct.tick(2.5)
	check_eq(gs.minute, 422, "2.5s -> +2 min")
	check_eq(box[0], 421, "signal old = prior minute (last of 2 emits)")
	check_eq(box[1], 422, "signal new")
	check_near(ct._acc, 0.5, 0.001, "acc remainder 0.5")
	ct.tick(1.0)
	check_eq(gs.minute, 423, "remainder + 1s completes a minute")
	check_near(ct._acc, 0.5, 0.001, "acc still 0.5 after full cycle")

	# F5 toggle + release ignore
	var ev = InputEventKey.new()
	ev.keycode = KEY_F5
	ev.pressed = true
	ct._unhandled_input(ev)
	check_eq(gs.mode, gs_script.GameStateMode.SCHEDULE, "F5 press -> SCHEDULE")
	ct.tick(3.0)
	check_eq(gs.minute, 423, "no tick after toggle off")
	ct._unhandled_input(ev)
	check_eq(gs.mode, gs_script.GameStateMode.REPAIR, "F5 press -> REPAIR again")
	ev.pressed = false
	ct._unhandled_input(ev)
	check_eq(gs.mode, gs_script.GameStateMode.REPAIR, "F5 release ignored")

	# F6 +30
	ev.keycode = KEY_F6
	ev.pressed = true
	ct._unhandled_input(ev)
	check_eq(gs.minute, 453, "F6 +30 min")
	check_eq(box[1], 453, "F6 emits")

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

	# tick qua 22:00: end_day, ve SCHEDULE, KHONG tiep tuc (Review Focus #4)
	gs.mode = gs_script.GameStateMode.REPAIR
	gs.minute = 1319
	ct.tick(2.0)
	check_eq(gs.minute, 420, "crossed 22:00 -> 07:00")
	check_eq(gs.date["day"], 7, "date +1 after midnight")
	check_eq(gs.mode, gs_script.GameStateMode.SCHEDULE, "mode SCHEDULE after end_day")
	ct.tick(60.0)
	check_eq(gs.minute, 420, "not ticking after end_day")
	check_eq(gs.date["day"], 7, "date untouched by extra ticks")

	ct.free()
