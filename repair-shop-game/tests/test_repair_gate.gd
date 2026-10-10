extends "res://tests/test_case.gd"

func run() -> void:
	var packed := load("res://scenes/repair_panel.tscn") as PackedScene
	var panel = packed.instantiate()
	var gs = load("res://scripts/autoload/game_state.gd").new()
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
	panel.free()
