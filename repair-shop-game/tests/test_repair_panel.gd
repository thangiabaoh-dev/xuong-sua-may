extends "res://tests/test_case.gd"

func run() -> void:
	var packed := load("res://scenes/repair_panel.tscn") as PackedScene
	check(packed != null, "repair_panel.tscn loads")
	if packed == null:
		return
	var panel = packed.instantiate()
	check(panel is CanvasLayer, "root is CanvasLayer")

	var state = load("res://scripts/autoload/game_state.gd").new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	panel.setup(state, rng)
	check(panel.session != null, "session created")

	var paths := ["Root/Header/LblMoney", "Root/Header/LblClock", "Root/Header/LblUyTin",
		"Root/Screens/ScreenOffer/BtnAccept", "Root/Screens/ScreenOffer/BtnReject",
		"Root/Screens/ScreenSymptom/BtnSymptomNext",
		"Root/Screens/ScreenChecks/BtnCheck0", "Root/Screens/ScreenChecks/BtnConclusion",
		"Root/Screens/ScreenConclusion/ConclusionBox",
		"Root/Screens/ScreenParts/BtnBuy", "Root/Screens/ScreenParts/BtnGiveUp",
		"Root/Screens/ScreenDisassemble/BtnDisassemble",
		"Root/Screens/ScreenDisassemble/LblProgress",
		"Root/Screens/ScreenDisassemble/BtnPort0",
		"Root/Screens/ScreenDisassemble/BtnPort1",
		"Root/Screens/ScreenDisassemble/BtnPort2",
		"Root/Screens/ScreenDisassemble/BtnPort3",
		"Root/Screens/ScreenDisassemble/BtnOrient0",
		"Root/Screens/ScreenDisassemble/BtnOrient1",
		"Root/Screens/ScreenTest/BtnRunTest",
		"Root/Screens/ScreenTone/BtnToneThan", "Root/Screens/ScreenTone/BtnToneNeutral",
		"Root/Screens/ScreenTone/BtnToneKho", "Root/Screens/ScreenTone/LblRisk",
		"Root/Screens/ScreenResult/BtnContinue", "Root/Screens/ScreenResult/LblReaction", "BtnOpen"]
	for p in paths:
		check(panel.get_node_or_null(p) != null, "node " + p)

	check(panel.get_node("Root/Screens/ScreenOffer").visible, "OFFER visible")
	check(not panel.get_node("Root/Screens/ScreenChecks").visible, "CHECKS hidden")

	# F1: OFFER warning phai bo qua khi da co stock trong kho
	var offer_part: String = FaultCatalog.get_fault(String(panel.session.order.fault_key)).part_id
	var offer_price: int = int(PartCatalog.get_part(offer_part).price)
	panel.game_state.money = offer_price - 1
	panel._render()
	check(panel.get_node("Root/Screens/ScreenOffer/LblWarn").visible, "warn when poor + no stock")
	panel.game_state.inventory[offer_part] = 1
	panel._render()
	check(not panel.get_node("Root/Screens/ScreenOffer/LblWarn").visible, "warn hidden with stock")
	panel.game_state.inventory.erase(offer_part)
	panel.game_state.money = 50000
	panel._render()

	panel.get_node("Root/Screens/ScreenOffer/BtnAccept").emit_signal("pressed")
	check(panel.get_node("Root/Screens/ScreenSymptom").visible, "accept -> SYMPTOM screen")

	panel.get_node("Root/Screens/ScreenSymptom/BtnSymptomNext").emit_signal("pressed")
	check(panel.get_node("Root/Screens/ScreenChecks").visible, "next -> CHECKS screen")
	check(panel.get_node("Root/Screens/ScreenChecks/BtnConclusion").disabled,
		"conclude disabled before2 checks")

	panel.get_node("Root/Screens/ScreenChecks/BtnCheck0").emit_signal("pressed")
	panel.get_node("Root/Screens/ScreenChecks/BtnCheck1").emit_signal("pressed")
	check(not panel.get_node("Root/Screens/ScreenChecks/BtnConclusion").disabled,
		"conclude enabled after2")

	panel.get_node("Root/Screens/ScreenChecks/BtnConclusion").emit_signal("pressed")
	check(panel.get_node("Root/Screens/ScreenConclusion").visible, "-> CONCLUSION screen")
	check(panel.get_node("Root/Screens/ScreenConclusion/ConclusionBox").get_child_count() > 0,
		"dynamic suspect buttons")

	# PARTS stock: BtnTake hien, BtnBuy an
	if not panel.has_node("Root/Screens/ScreenParts/BtnTake"):
		check(false, "BtnTake exists")
		panel.free()
		return
	check(panel.session.conclude(String(panel.session.order.fault_key)), "conclude true fault")
	panel._render()
	check(panel.get_node("Root/Screens/ScreenParts").visible, "PARTS visible")
	var pid: String = FaultCatalog.get_fault(String(panel.session.order.fault_key)).part_id
	panel.game_state.inventory[pid] = 1
	panel._render()
	check(panel.get_node("Root/Screens/ScreenParts/BtnTake").visible, "BtnTake visible with stock")
	check(not panel.get_node("Root/Screens/ScreenParts/BtnBuy").visible, "BtnBuy hidden with stock")
	panel.get_node("Root/Screens/ScreenParts/BtnTake").emit_signal("pressed")
	check_eq(int(panel.game_state.inventory[pid]), 0, "stock used up")
	check_eq(int(panel.session.elapsed), 10, "take costs 0 minutes")
	check_eq(int(panel.game_state.money), 50000, "take costs 0 money")

	# Minigame cam_cap (slow_hdd, d=1, 3 cong): sai -> +2' retry; dung -> TEST
	var ctrl0 = panel.session.begin_minigame()
	check(ctrl0 != null and ctrl0.kind == int(MinigameController.Kind.CAM_CAP), "dau don -> cam_cap")
	check_eq(int(ctrl0.port_count), 3, "d1 -> 3 cong")
	check(panel.get_node("Root/Screens/ScreenDisassemble/BtnPort0").visible, "port buttons visible")
	check(not panel.get_node("Root/Screens/ScreenDisassemble/BtnDisassemble").visible, "cam_cap an nut chinh")
	var wrong_port: int = (ctrl0.correct_port + 1) % ctrl0.port_count
	panel.get_node("Root/Screens/ScreenDisassemble/BtnPort%d" % wrong_port).emit_signal("pressed")
	panel.get_node("Root/Screens/ScreenDisassemble/BtnOrient%d" % ctrl0.correct_orientation).emit_signal("pressed")
	check_eq(int(panel.session.elapsed), 10 + 2, "fail +2 minutes")
	check(panel.get_node("Root/Screens/ScreenDisassemble").visible, "fail stays DISASSEMBLE")
	check(not ctrl0.failed, "reset after fail")
	# dap an da re-roll sau reset — chon dung
	panel.get_node("Root/Screens/ScreenDisassemble/BtnPort%d" % ctrl0.correct_port).emit_signal("pressed")
	panel.get_node("Root/Screens/ScreenDisassemble/BtnOrient%d" % ctrl0.correct_orientation).emit_signal("pressed")
	check(panel.get_node("Root/Screens/ScreenTest").visible, "correct -> TEST screen")
	check_eq(int(panel.session.elapsed), 12 + 5 * 1, "pass cost 5xd")
	# ScreenTone: TEST -> TONE -> RESULT
	panel.get_node("Root/Screens/ScreenTest/BtnRunTest").emit_signal("pressed")
	check(panel.get_node("Root/Screens/ScreenTone").visible, "run_test -> TONE screen")
	check(panel.get_node("Root/Screens/ScreenTone/LblRisk").text != "", "risk warning shown")
	panel.get_node("Root/Screens/ScreenTone/BtnToneNeutral").emit_signal("pressed")
	check(panel.get_node("Root/Screens/ScreenResult").visible, "tone -> RESULT screen")
	check(panel.get_node("Root/Screens/ScreenResult/LblReaction").text != "", "reaction shown")

	# Shop: Continue -> ScreenShop; thieu tien no-op; mua duoc; 1 mon/lan; khong dong clock
	if not panel.has_node("Root/Screens/ScreenShop/ShopBox"):
		check(false, "ScreenShop exists")
		panel.free()
		return
	panel.get_node("Root/Screens/ScreenResult/BtnContinue").emit_signal("pressed")
	check(panel.get_node("Root/Screens/ScreenShop").visible, "shop visible after continue")
	var elapsed_before: int = int(panel.session.elapsed)
	var state_before: int = int(panel.session.state)
	var shop_btn := panel.get_node("Root/Screens/ScreenShop/ShopBox").get_child(0) as Button
	check(shop_btn.has_meta("part_id") and shop_btn.has_meta("price"), "shop btn meta")
	if not (shop_btn.has_meta("part_id") and shop_btn.has_meta("price")):
		panel.free()
		return
	var shop_pid: String = String(shop_btn.get_meta("part_id"))
	var shop_price: int = int(shop_btn.get_meta("price"))
	var inv_before: int = int(panel.game_state.inventory.get(shop_pid, 0))
	panel.game_state.money = 1000
	shop_btn.emit_signal("pressed")
	check_eq(int(panel.game_state.money), 1000, "poor buy no-op")
	check_eq(int(panel.game_state.inventory.get(shop_pid, 0)), inv_before, "poor buy no inventory change")
	panel.game_state.money = 200000
	shop_btn.emit_signal("pressed")
	check_eq(int(panel.game_state.money), 200000 - shop_price, "shop deducts price")
	check_eq(int(panel.game_state.inventory.get(shop_pid, 0)), inv_before + 1, "inventory +1")
	shop_btn.emit_signal("pressed")
	check_eq(int(panel.game_state.money), 200000 - shop_price, "1 item per visit: money")
	check_eq(int(panel.game_state.inventory.get(shop_pid, 0)), inv_before + 1, "1 item per visit: inv")
	check_eq(int(panel.session.elapsed), elapsed_before, "shop does not touch clock")
	check_eq(int(panel.session.state), state_before, "shop does not touch session")
	panel.get_node("Root/Screens/ScreenShop/BtnSkip").emit_signal("pressed")
	check(panel.get_node("Root/Screens/ScreenOffer").visible, "skip -> new order OFFER")

	# Van_oc wiring (don ke no_wifi): BtnDisassemble that -> fail -> that du -> TEST
	panel.game_state.money = 200000
	var sV: RepairSession = panel.session
	sV.accept(); sV.advance_symptom()
	sV.do_check("do_nguon"); sV.do_check("nghe_quat")
	sV.begin_conclusion()
	check(sV.conclude("no_wifi"), "conclude no_wifi")
	sV.buy_part()
	panel._render()
	check(panel.get_node("Root/Screens/ScreenDisassemble").visible, "DISASSEMBLE sau buy")
	var ctrlV = panel.session.begin_minigame()
	check_eq(ctrlV.kind, int(MinigameController.Kind.VAN_OC), "no_wifi -> van_oc")
	check(panel.get_node("Root/Screens/ScreenDisassemble/BtnDisassemble").visible, "van_oc hien nut chinh")
	check(not panel.get_node("Root/Screens/ScreenDisassemble/BtnPort0").visible, "van_oc an port")
	var elapsed0: int = int(panel.session.elapsed)
	ctrlV.needle_pos = ctrlV.zone_lo - 0.01
	panel.get_node("Root/Screens/ScreenDisassemble/BtnDisassemble").emit_signal("pressed")
	check_eq(int(panel.session.elapsed), elapsed0 + 2, "van_oc fail +2")
	check(panel.get_node("Root/Screens/ScreenDisassemble").visible, "van_oc van o DISASSEMBLE")
	for i in ctrlV.beats_needed:
		ctrlV.needle_pos = (ctrlV.zone_lo + ctrlV.zone_hi) * 0.5
		panel.get_node("Root/Screens/ScreenDisassemble/BtnDisassemble").emit_signal("pressed")
	check(panel.get_node("Root/Screens/ScreenTest").visible, "van_oc pass -> TEST")

	panel.free()
