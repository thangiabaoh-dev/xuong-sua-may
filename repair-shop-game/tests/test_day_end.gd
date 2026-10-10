extends "res://tests/test_case.gd"

func run() -> void:
	var gs = load("res://scripts/autoload/game_state.gd").new()
	var packed := load("res://scenes/ui/summarize.tscn") as PackedScene
	check(packed != null, "summarize.tscn loads")
	if packed == null:
		return
	var s = packed.instantiate()
	s.setup(gs)
	check(s.has_node("Root/LblSummary"), "summary label")
	check(s.has_node("Root/BtnSleep"), "sleep button")

	# ngay moi: 3 hoat dong + 20 phut hoc
	gs.today_activities = [
		{"id": "di_hoc", "label": "Đi học", "minutes": 20, "knowledge": 2},
		{"id": "nghi_ngoi", "label": "Nghỉ ngơi", "minutes": 120},
		{"id": "doc_thu_vien", "label": "Đọc thư viện", "minutes": 135, "knowledge": 4},
	]
	gs.advance_to(1320)
	check_eq(int(gs.mode), int(load("res://scripts/autoload/game_state.gd").GameStateMode.SUMMARIZE), "mode SUMMARIZE")
	s.refresh()
	var lbl = s.get_node("Root/LblSummary") as Label
	check(String(lbl.text).contains("Đi học"), "lists activities")
	check(String(lbl.text).contains("Nghỉ ngơi"), "lists all")
	check(String(lbl.text).contains("Tri thức nhận: +6"), "knowledge total line +6")
	check(String(lbl.text).contains("Tiền:"), "money line intact")
	var day_before = int(gs.date["day"])
	var ky_before = int(gs.ky_luat)
	(s.get_node("Root/BtnSleep") as Button).pressed.emit()
	check_eq(int(gs.date["day"]), day_before + 1, "date +1")
	check_eq(int(gs.minute), 420, "minute 07:00")
	check_eq(int(gs.mode), int(load("res://scripts/autoload/game_state.gd").GameStateMode.SCHEDULE), "SCHEDULE after sleep")
	check_eq(int(gs.shift_used), 0, "shift reset")
	check_eq(int(gs.ky_luat), ky_before - 10, "penalty -10 for 430 missing")
	s.refresh()
	check_eq(bool(String(lbl.text).contains("Tri thức nhận")), false, "knowledge line hidden when 0 (RF5)")
	s.free()
