extends "res://tests/test_case.gd"

func run() -> void:
	var gs = load("res://scripts/autoload/game_state.gd").new()
	var core = load("res://scripts/schedule_core.gd")
	check(core != null, "schedule_core loads")
	if core == null:
		return
	# T2 07:00, di tai workshop -> SCHOOL slot, di_hoc bi chan vi khong o lop
	gs.current_location = "workshop"
	var acts = core.available(gs)
	check_eq(acts.size(), 1, "SCHOOL has 1 activity")
	check_eq(String(acts[0].id), "di_hoc", "di_hoc")
	check_eq(core.reason_for(gs, acts[0]), "Cần ở: classroom", "wrong location reason")
	var r = core.try_activity(gs, "di_hoc")
	check_eq(r.ok, false, "fail wrong location")
	check_eq(gs.minute, 420, "minute unchanged on fail")

	# dung cho
	gs.current_location = "classroom"
	check_eq(core.reason_for(gs, acts[0]), "", "ok at classroom")
	r = core.try_activity(gs, "di_hoc")
	check_eq(r.ok, true, "di_hoc ok")
	check_eq(gs.minute, 690, "consume 270 -> 11:30")

	# id la
	r = core.try_activity(gs, "khong_ton_tai")
	check_eq(r.ok, false, "unknown id fails")
	check_eq(gs.minute, 690, "minute unchanged unknown id")

	# khong dung khung (11:30 CHOICE: khong con di_hoc)
	gs.current_location = "classroom"
	r = core.try_activity(gs, "di_hoc")
	check_eq(r.ok, false, "di_hoc not in CHOICE slot")

	# CHOICE dung cho
	gs.current_location = "library"
	r = core.try_activity(gs, "doc_thu_vien")
	check_eq(r.ok, true, "doc_thu_vien ok")
	check_eq(gs.minute, 825, "consume 135 -> 13:45")

	# mode khong phai SCHEDULE
	gs.mode = load("res://scripts/autoload/game_state.gd").GameStateMode.REPAIR
	gs.current_location = "classroom"
	r = core.try_activity(gs, "di_hoc")
	check_eq(r.ok, false, "blocked when not SCHEDULE")
	check_eq(gs.minute, 825, "minute unchanged in REPAIR")

	# mo_panel khong consume phut
	gs.mode = load("res://scripts/autoload/game_state.gd").GameStateMode.SCHEDULE
	gs.minute = 1020
	gs.current_location = "workshop"
	r = core.try_activity(gs, "mo_panel")
	check_eq(r.ok, true, "mo_panel ok")
	check_eq(gs.minute, 1020, "mo_panel consumes 0")

	# clamp cuoi slot: 1139 + di 120 (nghi_tai_nha) khong vuot 1140
	gs.minute = 1139
	r = core.try_activity(gs, "nghi_tai_nha")
	check_eq(r.ok, true, "clamp ok")
	check_eq(gs.minute, 1140, "clamped at slot end")

	# cham 1320 -> end_day
	gs.minute = 1310
	gs.current_location = "workshop"
	r = core.try_activity(gs, "lam_project")
	check_eq(r.ok, true, "project ok")
	check_eq(int(gs.mode), int(load("res://scripts/autoload/game_state.gd").GameStateMode.SUMMARIZE), "end_day at 1320")

	# ngay le — slot runtime khong co activities, core tu sinh
	gs.begin_new_day()
	gs.date = {"year": 2026, "month": 4, "day": 30}
	gs.minute = 600
	gs.current_location = "street"
	var hacts = core.available(gs)
	check_eq(hacts.size(), 1, "holiday 1 activity")
	check_eq(String(hacts[0].id), "su_kien_doi_thuong", "holiday activity id")
	check_eq(core.reason_for(gs, hacts[0]), "", "holiday activity anywhere")
	r = core.try_activity(gs, "su_kien_doi_thuong")
	check_eq(r.ok, true, "holiday ok")
	check_eq(gs.minute, 1320, "900 clamp to 1320")

	# key le sai format: khong crash + push_warning (source pin, spec 8)
	var sl = load("res://scripts/schedule_logic.gd")
	gs.week.holidays.append("sai-format")
	check_eq(bool(sl.is_holiday(gs.week, {"year": 2026, "month": 10, "day": 5})), false, "bad key not holiday")
	var f = FileAccess.open("res://scripts/schedule_logic.gd", FileAccess.READ)
	check(f != null and f.get_as_text().contains("push_warning"), "malformed holiday key warns")
