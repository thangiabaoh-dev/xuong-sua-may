extends "res://tests/test_case.gd"

func run() -> void:
	var packed = load("res://scenes/ui/workplace_screen.tscn") as PackedScene
	check(packed != null, "workplace_screen.tscn loads")
	if packed == null:
		return
	var gs_script = load("res://scripts/autoload/game_state.gd")

	# backdrop theo tier + clamp 0..2 (spec §4)
	for t in [0, 1, 2, 9]:
		var scr = packed.instantiate()
		var gs = gs_script.new()
		gs.workspace_tier = t
		scr.setup(gs)
		var expect := mini(t, 2)
		for i in range(3):
			var tn = scr.get_node("Root/Backdrop/Tier%d" % i)
			check_eq(tn.visible, i == expect, "tier %d -> preset %d visible=%s" % [t, i, i == expect])
		scr.free()

	# Review Focus 1: upgrade fail khong mutate + toast ly do (spec §3.3)
	var scr2 = packed.instantiate()
	var gs2 = gs_script.new()  # money 50000 < 1.000.000
	scr2.setup(gs2)
	scr2.get_node("Root/UpgradePanel/UpgradeBtn").pressed.emit()
	check_eq(gs2.money, 50000, "fail: money giu nguyen")
	check_eq(gs2.workspace_tier, 0, "fail: tier giu nguyen")
	check_eq(String(scr2.get_node("Root/Toast").text), "Chưa đủ tiền", "toast no_money")

	gs2.money = 2000000  # tien du, uy_tin 0 < 40
	scr2.get_node("Root/UpgradePanel/UpgradeBtn").pressed.emit()
	check_eq(gs2.money, 2000000, "low_uy_tin: khong tru tien")
	check_eq(gs2.workspace_tier, 0, "low_uy_tin: tier giu")
	check_eq(String(scr2.get_node("Root/Toast").text), "Uy tín còn thấp", "toast low_uy_tin")

	# upgrade success (spec §3.2)
	gs2.uy_tin = 50
	scr2.get_node("Root/UpgradePanel/UpgradeBtn").pressed.emit()
	check_eq(gs2.workspace_tier, 1, "success: tier 1")
	check_eq(gs2.money, 1000000, "success: tru dung 1.000.000")
	check(scr2.get_node("Root/Backdrop/Tier1").visible, "backdrop doi ngay")
	check(scr2.get_node("Root/Backdrop/Tier0").visible == false, "Tier0 an di")
	check(String(scr2.get_node("Root/Toast").text).contains("Đã mở"), "toast success")
	check_eq(String(scr2.get_node("Root/UpgradePanel/TierLabel").text), "CHỖ LÀM: Phòng", "TierLabel = Phong")

	# tier 2: nut tat, khong con def
	gs2.workspace_tier = 2
	scr2.refresh()
	check_eq(scr2.get_node("Root/UpgradePanel/UpgradeBtn").disabled, true, "tier2: nut tat")

	# spec §4: thieu .tres -> message + nut tat; setup(null) khong crash
	scr2._upgrade_defs.clear()
	scr2.refresh()
	check_eq(String(scr2.get_node("Root/UpgradePanel/NextLabel").text), "Thiếu dữ liệu progression", "thieu data -> canh bao")
	check_eq(scr2.get_node("Root/UpgradePanel/UpgradeBtn").disabled, true, "thieu data -> nut tat")
	var scrN = packed.instantiate()
	scrN.setup(null)
	check(scrN != null, "setup(null) khong crash")
	scrN.free()
	scr2.free()

	# tracker milestones (spec §2.1)
	var wsp_script = load("res://scripts/ui/workplace_screen.gd")
	var scr4 = packed.instantiate()
	var gs4 = gs_script.new()
	scr4.setup(gs4)
	var row_may = scr4.get_node_or_null("Root/Tracker/Milestones/may_co")
	check(row_may != null, "tracker milestone row may_co")
	if row_may == null:
		scr4.free()
		return
	check_eq(String(row_may.get_node("MName").text), "Máy cổ", "milestone label")
	check_eq(String(row_may.get_node("MMark").text), "", "knowledge 0 -> chua unlock")
	gs4.knowledge = 32
	scr4.refresh()
	check_eq(String(row_may.get_node("MPct").text), "64%", "pct 64% tai knowledge 32")
	gs4.knowledge = 100
	scr4.refresh()
	check_eq(String(scr4.get_node("Root/Tracker/Milestones/may_co/MMark").text), "✓", "knowledge 100 -> ✓")
	check_eq(scr4.get_node("Root/Tracker/Milestones").get_child_count(), 4, "4 milestone rows")

	# Review Focus 3: percent math (spec §2.1 min ratio)
	var vals := {"knowledge": 32, "uy_tin": 45, "workspace_tier": 1}
	check(absf(wsp_script.progress_percent("knowledge >= 50", vals) - 0.64) < 0.001, "32/50 -> 64%")
	check_near(wsp_script.progress_percent("uy_tin >= 90 and workspace_tier >= 1", vals), 0.5, 0.001, "min(45/90, 1/1) = 50%")
	check_eq(wsp_script.progress_percent("no_pattern_here", vals), -1.0, "khong pattern -> -1")

	# customers gate (spec §2.4 + Review Focus 4)
	check_eq(scr4.get_node("Root/Tracker/Customers").get_child_count(), 3, "3 customer rows")
	check(scr4.get_node("Root/Tracker/Customers/giao_vien").modulate.a < 1.0, "uy_tin 0 -> giao vien mo")
	gs4.uy_tin = 60
	scr4.refresh()
	check(scr4.get_node("Root/Tracker/Customers/giao_vien").modulate.a >= 1.0, "uy_tin 60 -> giao vien sang")
	check(scr4.get_node("Root/Tracker/Customers/hoai_niem").modulate.a < 1.0, "phong tin van mo (tier 0)")

	# Review Focus 2: tier up while open -> unlock NGAY qua unlock_changed (spec §3.4)
	gs4.uy_tin = 90
	gs4.money = 9000000
	gs4.workspace_tier = 0
	scr4.refresh()
	check(scr4.get_node("Root/Tracker/Customers/hoai_niem").modulate.a < 1.0, "truoc upgrade phong tin mo")
	scr4.get_node("Root/UpgradePanel/UpgradeBtn").pressed.emit()  # tier 0 -> 1 (uy_tin 90 >= 40)
	check_eq(gs4.workspace_tier, 1, "upgrade len tier 1")
	check(scr4.get_node("Root/Tracker/Customers/hoai_niem").modulate.a >= 1.0, "unlock_changed -> row sang NGAY")
	check_eq(String(scr4.get_node("Root/Tracker/Milestones/khach_phong_tin/MMark").text), "✓", "milestone ✓ ngay")
	check_eq(scr4.get_node("Root/Tracker/Warning").visible, false, "du lieu sach -> warning an")
	scr4.free()

	# HUD entry + dong/mo lai doc state moi (spec §3.1/§3.5 + Review Focus 5)
	var hud_script = load("res://scripts/ui/hud.gd")
	var host := Node.new()
	var hud = hud_script.new()
	host.add_child(hud)
	var gs5 = gs_script.new()
	hud.setup(gs5)
	var btn = hud.get_node_or_null("Root/WorkplaceBtn")
	check(btn != null, "HUD co nut CHỖ LÀM")
	if btn == null:
		host.free()
		return
	btn.pressed.emit()
	var wp = host.get_node_or_null("WorkplaceScreen")
	check(wp != null, "click -> scene instance under parent")
	if wp == null:
		host.free()
		return
	check(wp.visible, "moi instance -> visible")

	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	wp._unhandled_input(ev)
	check(not wp.visible, "Esc -> an")

	# Review Focus 5: mo lai doc GameState moi (tier doi trong luc dang dong)
	gs5.workspace_tier = 2
	btn.pressed.emit()
	check(wp.visible, "nhan nut -> hien lai")
	check_eq(String(wp.get_node("Root/UpgradePanel/TierLabel").text), "CHỖ LÀM: Tiệm", "mo lai -> doc tier moi")
	ev.pressed = true
	wp._unhandled_input(ev)
	check(not wp.visible, "Esc 2 -> an (khong tao instance moi)")
	host.free()
