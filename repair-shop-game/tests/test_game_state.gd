extends "res://tests/test_case.gd"

func run() -> void:
	var state = load("res://scripts/autoload/game_state.gd").new()
	check_eq(state.money, 50000, "money start 50000")
	check_eq(state.knowledge, 0, "knowledge start 0")
	check_eq(state.uy_tin, 0, "uy_tin start 0")
	check_eq(state.ky_luat, 100, "ky_luat start 100")
	state.money += 1000
	check_eq(state.money, 51000, "money mutable")
	var has_inv := false
	for p in state.get_property_list():
		if String(p["name"]) == "inventory":
			has_inv = true
			break
	check(has_inv, "inventory property exists")
	if has_inv:
		check_eq(state.inventory.size(), 0, "inventory start empty")
		state.inventory["ssd_240"] = 1
		check_eq(state.inventory.size(), 1, "inventory mutable")
