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
	check(not r.has("gains"), "fail: no gains key")
	check_eq(int(gs.knowledge), 0, "fail: knowledge unchanged")

	# dung cho
	gs.current_location = "classroom"
	check_eq(core.reason_for(gs, acts[0]), "", "ok at classroom")
	r = core.try_activity(gs, "di_hoc")
	check_eq(r.ok, true, "di_hoc ok")
	check_eq(gs.minute, 690, "consume 270 -> 11:30")
	var gains: Dictionary = r.get("gains", {})
	check_eq(int(gains.get("knowledge", -1)), 2, "di_hoc gains +2 (0.008 x 270)")
	check_eq(int(gs.knowledge), 2, "knowledge = 2")
	check_eq(int(gs.today_activities[-1].get("knowledge", 0)), 2, "today entry knowledge")

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
	var gains2: Dictionary = r.get("gains", {})
	check_eq(int(gains2.get("knowledge", -1)), 4, "thu_vien gains +4 (0.030 x 135)")
	check_eq(int(gs.knowledge), 6, "knowledge 2+4")

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
	check_eq(Dictionary(r.get("gains", {})).size(), 0, "mo_panel: empty gains")

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
	check_eq(String(r["gains"].get("project", "")), "p_noibo", "gains project")
	check_eq(int(r["gains"].get("uy_tin", 0)), 10, "gains uy_tin flat (clamp 10 min van +10)")
	check_eq(int(gs.project_count), 1, "project_count 1")
	check(gs.completed_projects.has(&"p_noibo"), "completed_projects append")
	check_eq(String(gs.today_activities[-1].get("project", "")), "p_noibo", "entry project key")
	check_eq(int(gs.today_activities[-1].get("uy_tin", 0)), 10, "entry uy_tin key")

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
	check_eq(String(hacts[0].hook), "knowledge_rate:0.010", "holiday hook set in code (RF4)")
	var hg: Dictionary = r.get("gains", {})
	check_eq(int(hg.get("knowledge", -1)), 7, "holiday gains +7 (0.010 x 720 clamp 600->1320)")
	check_eq(int(gs.knowledge), 13, "knowledge 2+4+7")

	# key le sai format: khong crash + push_warning (source pin, spec 8)
	var sl = load("res://scripts/schedule_logic.gd")
	gs.week.holidays.append("sai-format")
	check_eq(bool(sl.is_holiday(gs.week, {"year": 2026, "month": 10, "day": 5})), false, "bad key not holiday")
	var f = FileAccess.open("res://scripts/schedule_logic.gd", FileAccess.READ)
	check(f != null and f.get_as_text().contains("push_warning"), "malformed holiday key warns")

	# RF1: phut clamp cuoi slot — gain tren phut thuc
	var gs2 = load("res://scripts/autoload/game_state.gd").new()
	gs2.current_location = "workshop"
	gs2.minute = 1139
	var r2 = core.try_activity(gs2, "doc_sach_nha")
	check_eq(r2.ok, true, "clamp: doc_sach_nha ok")
	check_eq(int(gs2.minute), 1140, "clamp: minute 1140")
	check_eq(Dictionary(r2.get("gains", {})).size(), 0, "clamp 1 phut: no int gain")
	check_eq(int(gs2.today_activities[0].get("knowledge", 0)), 0, "clamp: khong tich int")
	check_near(float(gs2.knowledge_remainder), 0.02, 0.001, "clamp: rem = 0.02 x 1 phut")
	gs2.free()
