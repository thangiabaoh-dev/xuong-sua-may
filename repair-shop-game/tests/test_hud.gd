extends "res://tests/test_case.gd"

func run() -> void:
	var packed = load("res://scenes/ui/hud.tscn") as PackedScene
	check(packed != null, "hud.tscn loads")
	if packed == null:
		return
	var hud = packed.instantiate()
	check(hud is CanvasLayer, "root CanvasLayer")
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var gs = gs_script.new()
	var hud_script = load("res://scripts/ui/hud.gd")
	hud.setup(gs, null)
	check(hud.has_node("Root/TimeLabel"), "TimeLabel exists")
	var lbl = hud.get_node("Root/TimeLabel") as Label
	check(String(lbl.text).contains("07:00"), "shows 07:00")
	check(String(lbl.text).contains("T2"), "shows Mon T2")
	check(String(lbl.text).contains("Đi học"), "shows school label")

	check_eq(hud_script.slot_label("SCHOOL"), "Đi học", "label SCHOOL")
	check_eq(hud_script.slot_label("CHOICE"), "Tự chọn", "label CHOICE")
	check_eq(hud_script.slot_label("REPAIR"), "Ca sửa máy", "label REPAIR")
	check_eq(hud_script.slot_label("FREE_HOME"), "Ở nhà", "label FREE_HOME")
	check_eq(hud_script.slot_label("PROJECT"), "Làm project", "label PROJECT")
	check_eq(hud_script.slot_label("BREAK"), "Nghỉ", "label BREAK")
	check_eq(hud_script.slot_label("HOLIDAY"), "Ngày lễ", "label HOLIDAY")
	check_eq(hud_script.slot_label(""), "Ngoài lịch", "label empty -> Ngoai lich")

	# ngoai khung
	gs.minute = 300
	hud.refresh()
	check(String(lbl.text).contains("Ngoài lịch"), "outside range shows Ngoai lich")

	# CHOICE
	gs.minute = 690
	hud.refresh()
	check(String(lbl.text).contains("11:30"), "shows 11:30")
	check(String(lbl.text).contains("Tự chọn"), "shows choice label")

	# signal hook voi clock (task 5)
	var ct_script = load("res://scripts/clock_timer.gd")
	if ct_script != null:
		var ct = ct_script.new()
		ct.setup(gs)
		hud.setup(gs, ct)
		gs.mode = gs_script.GameStateMode.REPAIR
		gs.advance_to(691)
		hud.refresh()
		check(String(lbl.text).contains("11:31"), "refresh shows 11:31")
		ct.free()
	hud.free()
