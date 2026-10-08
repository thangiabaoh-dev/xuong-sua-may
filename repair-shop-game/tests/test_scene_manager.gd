extends "res://tests/test_case.gd"

func run() -> void:
	# data: 7 path load duoc
	var sm = load("res://scripts/autoload/scene_manager.gd")
	check(sm != null, "scene_manager.gd must load")
	if sm == null:
		return
	var locs: Dictionary = sm.LOCATIONS
	check_eq(locs.size(), 7, "7 locations")
	for k in locs:
		check(load(locs[k]) != null, "path loads: " + str(locs[k]))
	# default location
	var gs = load("res://scripts/autoload/game_state.gd").new()
	check_eq(gs.current_location, "workshop", "current_location default")
	# location_for_key
	check_eq(sm.location_for_key(49), "workshop", "KEY_1=49 -> workshop")  # KEY_1 = 49
	check_eq(sm.location_for_key(55), "street", "KEY_7=55 -> street")
	check_eq(sm.location_for_key(65), "", "KEY_A -> empty")
	# change_map: main instance, swap Workshop -> Gate
	var main = load("res://scenes/main.tscn").instantiate()
	var player = CharacterBody3D.new()
	player.name = "Player"
	player.add_to_group("player")
	main.add_child(player)
	check(main.has_node("Workshop"), "start has Workshop")
	sm.change_map(main, player, "gate", gs)
	check(not main.has_node("Workshop"), "old Workshop removed")
	check(main.has_node("Gate"), "Gate added")
	check_eq(gs.current_location, "gate", "location updated")
	check_near(player.position.x, 0.0, 0.001, "spawn X")
	check_near(player.position.y, 0.1, 0.001, "spawn Y")
	check_near(player.position.z, 0.0, 0.001, "spawn Z")
	check_eq(player.velocity, Vector3.ZERO, "velocity reset")
	main.free()
