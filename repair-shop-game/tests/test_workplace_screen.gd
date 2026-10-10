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
