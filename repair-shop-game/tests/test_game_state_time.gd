extends "res://tests/test_case.gd"

func run() -> void:
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var gs = gs_script.new()
	check_eq(gs.minute, 420, "start 07:00")
	check_eq(gs.date["year"], 2026, "start year")
	check_eq(gs.date["month"], 10, "start month")
	check_eq(gs.date["day"], 5, "start Mon Oct 5")
	check_eq(gs.mode, gs_script.GameStateMode.SCHEDULE, "start SCHEDULE")
	check(gs.week != null, "week preloaded")
	check_eq(gs.week.days.size(), 7, "week has 7 days")
	check_eq(gs_script.GameStateMode.size(), 4, "4 modes")

	gs.advance_to(690)
	check_eq(gs.minute, 690, "minute advanced")
	var s = gs.slot()
	check(s != null and String(s.kind) == "CHOICE", "11:30 CHOICE")
	check(gs.can_enter("cafe"), "can cafe at CHOICE")
	check(not gs.can_enter("schoolyard"), "deny schoolyard at CHOICE")

	# end_day tu kich hoat luc 22:00
	gs.advance_to(1320)
	check_eq(gs.minute, 420, "reset to 07:00")
	check_eq(gs.date["day"], 6, "date +1")
	check_eq(gs.mode, gs_script.GameStateMode.SCHEDULE, "back to SCHEDULE")

	# bien thang
	gs.date = {"year": 2026, "month": 10, "day": 31}
	gs.advance_to(1320)
	check_eq(gs.date["month"], 11, "Oct -> Nov")
	check_eq(gs.date["day"], 1, "day 1")

	# bien nam
	gs.date = {"year": 2026, "month": 12, "day": 31}
	gs.advance_to(1320)
	check_eq(gs.date["year"], 2027, "Dec 2026 -> Jan 2027")
	check_eq(gs.date["day"], 1, "Jan 1")

	# ngoai khung fail-closed
	gs.minute = 300
	check(gs.slot() == null, "05:00 null slot")
	check(not gs.can_enter("workshop"), "05:00 deny all")
