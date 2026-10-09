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

	# tick khong con tang minute theo wall-clock (Q1)
	gs.mode = gs_script.GameStateMode.REPAIR
	var m_before: int = gs.minute
	ct.tick(5.0)
	check_eq(gs.minute, m_before, "tick does not advance minute")
	gs.minute = 423  # dat day du lieu cho cac block F5/F6/F7 giu nguyen assertion cu

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

	# tick khong bao gio vuot 22:00 tu no (Q1)
	gs.mode = gs_script.GameStateMode.REPAIR
	gs.minute = 1319
	ct.tick(2.0)
	check_eq(gs.minute, 1319, "tick never crosses 22:00 by itself")
	ct.tick(60.0)
	check_eq(gs.minute, 1319, "still no realtime advance")

	ct.free()
