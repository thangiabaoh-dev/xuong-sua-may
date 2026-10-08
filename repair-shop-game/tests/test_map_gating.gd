extends "res://tests/test_case.gd"

func run() -> void:
	var sm = load("res://scripts/autoload/scene_manager.gd")
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var main = load("res://scenes/main.tscn").instantiate()
	var player = CharacterBody3D.new()
	player.name = "Player"
	player.add_to_group("player")
	main.add_child(player)
	var gs = gs_script.new()

	# T2 07:00 SCHOOL: gate cho phep
	var ok = sm.change_map(main, player, "gate", gs)
	check_eq(ok, true, "allow gate in school slot")
	check(main.has_node("Gate"), "Gate swapped in")
	check(not main.has_node("Workshop"), "Workshop gone")
	check_eq(gs.current_location, "gate", "location updated")

	# deny: cafe luc 07:00 -> false, scene giu nguyen
	var before: int = main.get_child_count()
	var denied = sm.change_map(main, player, "cafe", gs)
	check_eq(denied, false, "deny cafe in school slot")
	check_eq(main.get_child_count(), before, "scene unchanged on deny")
	check(main.has_node("Gate"), "Gate still present")
	check_eq(gs.current_location, "gate", "location unchanged on deny")

	# CHOICE 11:30: cafe allow, schoolyard deny
	gs.advance_to(690)
	check_eq(sm.change_map(main, player, "cafe", gs), true, "allow cafe at CHOICE")
	check(main.has_node("Cafe"), "Cafe present")
	check_eq(sm.change_map(main, player, "schoolyard", gs), false, "deny schoolyard at CHOICE")
	check(main.has_node("Cafe"), "Cafe unchanged after deny")

	# invalid loc van false
	check_eq(sm.change_map(main, player, "xxx", gs), false, "invalid loc false")
	main.free()

	# source pin
	var f = FileAccess.open("res://scripts/autoload/scene_manager.gd", FileAccess.READ)
	check(f != null and f.get_as_text().contains("-> bool"), "change_map returns bool")
	check(f != null and f.get_as_text().contains("can_enter"), "gates via can_enter")
