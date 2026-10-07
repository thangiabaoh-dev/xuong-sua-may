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
		"Root/Screens/ScreenTest/BtnRunTest",
		"Root/Screens/ScreenResult/BtnContinue", "BtnOpen"]
	for p in paths:
		check(panel.get_node_or_null(p) != null, "node " + p)

	check(panel.get_node("Root/Screens/ScreenOffer").visible, "OFFER visible")
	check(not panel.get_node("Root/Screens/ScreenChecks").visible, "CHECKS hidden")

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

	panel.free()
