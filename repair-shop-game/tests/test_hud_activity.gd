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

	# toast rong sau mo_panel khong hook (RF4) — di qua _on_activity qua nut
	box = hud.get_node("Root/ActivityBox")
	check(box.has_node("Btn_mo_panel"), "mo_panel button in REPAIR")
	box.get_node("Btn_mo_panel").pressed.emit()
	check_eq(String(hud.get_node("Root/Toast").text), "", "toast empty after mo_panel")
	check_eq(bool(hud.get_node("Root/Toast").visible), false, "toast hidden after mo_panel")

	# doc_sach_nha luc 1020 REPAIR: 120 phut x 0.020 = 2.4 -> +2 (spec 5.1)
	box = hud.get_node("Root/ActivityBox")
	check(box.has_node("Btn_doc_sach_nha"), "doc_sach_nha button in REPAIR")
	box.get_node("Btn_doc_sach_nha").pressed.emit()
	check_eq(String(hud.get_node("Root/Toast").text), "+2 tri thức", "toast text")
	check_eq(bool(hud.get_node("Root/Toast").visible), true, "toast visible")

	# spec 7: toast tu an sau 1.5s — harness khong chay frame/await duoc
	# (Engine.get_main_loop() == null trong _init) -> test hide method + pin timer wiring
	check(hud.has_method("_hide_toast"), "has _hide_toast method")
	if hud.has_method("_hide_toast"):
		hud._hide_toast()
		check_eq(bool(hud.get_node("Root/Toast").visible), false, "_hide_toast hides toast")
	var hf = FileAccess.open("res://scripts/ui/hud.gd", FileAccess.READ)
	check(hf != null and hf.get_as_text().contains("create_timer(1.5)")
		and hf.get_as_text().contains("_hide_toast()"), "timer wiring pinned (source)")
	check_eq(int(gs.knowledge), 2, "gs.knowledge = 2")
	check_eq(int(gs.minute), 1140, "consume 120 -> 1140")

	# REPAIR mode -> an panel
	gs.mode = load("res://scripts/autoload/game_state.gd").GameStateMode.REPAIR
	hud.refresh()
	check_eq(hud.get_node("Root/ActivityBox").visible, false, "hidden in REPAIR")
	hud.free()
