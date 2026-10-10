extends "res://tests/test_case.gd"

func run() -> void:
	var packed = load("res://scenes/ui/hud.tscn") as PackedScene
	check(packed != null, "hud loads")
	if packed == null:
		return
	var hud = packed.instantiate()
	var gs = load("res://scripts/autoload/game_state.gd").new()
	hud.setup(gs, null)
	check(hud.has_node("Root/ActivityBox"), "ActivityBox exists")
	check(hud.has_node("Root/LblBudget"), "budget label exists")

	# T2 07:00 workshop: 1 nut, disabled (khong o lop)
	gs.current_location = "workshop"
	hud.refresh()
	var box = hud.get_node("Root/ActivityBox")
	check(box.has_node("Btn_di_hoc"), "di_hoc button in SCHOOL")
	check_eq(box.get_child_count(), 1, "exactly 1 button after refresh")
	hud.refresh()
	check_eq(hud.get_node("Root/ActivityBox").get_child_count(), 1, "no duplicate buttons on re-refresh")
	var b = box.get_node("Btn_di_hoc") as Button
	check_eq(b.disabled, true, "disabled wrong location")
	check(String(b.tooltip_text).contains("classroom"), "tooltip location")

	# sang lop -> enable
	gs.current_location = "classroom"
	hud.refresh()
	b = hud.get_node("Root/ActivityBox/Btn_di_hoc") as Button
	check_eq(b.disabled, false, "enabled at classroom")
	check_eq(String(hud.get_node("Root/LblBudget").text), "", "budget hidden outside repair")

	# 17:00 — advance_to KHONG goi refresh thu cong, HUD tu update qua schedule_changed
	gs.current_location = "workshop"
	gs.advance_to(1020)
	check(hud.get_node("Root/ActivityBox").has_node("Btn_mo_panel"), "mo_panel auto-refreshed in REPAIR")
	check(String(hud.get_node("Root/LblBudget").text).contains("120"), "budget label 120")

	# nhat don: bnut mo_panel -> try ok, minute khong doi
	var m0: int = int(gs.minute)
	var r = load("res://scripts/schedule_core.gd").try_activity(gs, "mo_panel")
	check_eq(r.ok, true, "mo_panel try ok")
	check_eq(int(gs.minute), m0, "minute unchanged")

	# REPAIR mode -> an panel
	gs.mode = load("res://scripts/autoload/game_state.gd").GameStateMode.REPAIR
	hud.refresh()
	check_eq(hud.get_node("Root/ActivityBox").visible, false, "hidden in REPAIR")
	hud.free()
