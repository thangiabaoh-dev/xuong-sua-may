extends "res://tests/test_case.gd"

func run() -> void:
	var packed := load("res://scenes/repair_panel.tscn") as PackedScene
	var panel = packed.instantiate()
	var gscript = load("res://scripts/autoload/game_state.gd")
	var gs = gscript.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# 07:00 SCHOOL: khong tao don
	panel.setup(gs, rng)
	check(panel.session == null, "no session outside repair slot")
	# vao 17:00 REPAIR: tao don
	gs.advance_to(1020)
	panel.open_new_order()
	check(panel.session != null, "session in repair slot")
	# het budget: khong tao don moi
	gs.shift_used = 9999
	panel.open_new_order()
	check(panel.session == null, "no session when budget exhausted")
	# dong ca: cham cuoi slot REPAIR -> LOST_TIME + ve SCHEDULE (spec §5)
	gs.shift_used = 0
	gs.minute = 1130  # 18:50 T2 — trong slot, con du budget
	gs.mode = gscript.GameStateMode.REPAIR
	panel.open_new_order()
	check(panel.session != null, "session at 1130")
	var rs_script = load("res://scripts/repair/repair_session.gd")
	var hit_slot: bool = panel.session._add_minutes(20)  # 1130 + 20 = 1150 > 1140
	check_eq(hit_slot, true, "slot end forces timeout")
	check_eq(int(panel.session.result), int(rs_script.Result.LOST_TIME), "LOST_TIME at slot end")
	check_eq(int(gs.mode), int(gscript.GameStateMode.SCHEDULE), "mode SCHEDULE after forced")
	# mo panel -> state REPAIR; dong panel -> SCHEDULE (spec §4.2)
	gs.minute = 1020
	panel._on_open()
	check(panel.session != null, "session via _on_open")
	check_eq(int(gs.mode), int(gscript.GameStateMode.REPAIR), "state REPAIR on open")
	panel._on_close()
	check_eq(int(gs.mode), int(gscript.GameStateMode.SCHEDULE), "state SCHEDULE on close")
	panel.free()
