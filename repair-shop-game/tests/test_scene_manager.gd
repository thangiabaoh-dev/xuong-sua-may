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
	# regression: repeat switch khong tich ghost (review Critical #1b)
	var main2 = load("res://scenes/main.tscn").instantiate()
	var p2 := CharacterBody3D.new()
	main2.add_child(p2)
	var gs2 = load("res://scripts/autoload/game_state.gd").new()
	var before: int = main2.get_child_count()
	sm.change_map(main2, p2, "gate", gs2)
	check_eq(main2.get_child_count(), before, "switch keeps child count")
	sm.change_map(main2, p2, "gate", gs2)
	check_eq(main2.get_child_count(), before, "repeat switch no ghost")
	var maps := 0
	for c in main2.get_children():
		var matched := false
		for k in sm.LOCATIONS:
			if String(c.name) == str(k).capitalize():
				matched = true
		if matched:
			maps += 1
	check_eq(maps, 1, "exactly one map node")
	# regression: loc khong hop le khong pha scene (review Important #3)
	var before_bad: int = main2.get_child_count()
	sm.change_map(main2, p2, "xxx", gs2)
	check_eq(main2.get_child_count(), before_bad, "invalid loc no-op")
	check_eq(gs2.current_location, "gate", "invalid loc keeps location")
	main2.free()
	# handler source pin (khuon mau _camera_script_reads_player_group)
	var f = FileAccess.open("res://scripts/autoload/scene_manager.gd", FileAccess.READ)
	check(f != null and f.get_as_text().contains("_unhandled_input"), "handler defined")
	check(f != null and f.get_as_text().contains("get_first_node_in_group(\"player\")"), "resolves player group")
	check(f != null and f.get_as_text().contains("not key.pressed"), "pressed guard pinned")
	check(f != null and f.get_as_text().contains("/root/GameState"), "runtime GameState lookup pinned")
