extends "res://tests/test_case.gd"

func run() -> void:
	var state = load("res://scripts/autoload/game_state.gd").new()
	check_eq(state.money, 50000, "money start 50000")
	check_eq(state.knowledge, 0, "knowledge start 0")
	check_eq(state.uy_tin, 0, "uy_tin start 0")
	check_eq(state.ky_luat, 100, "ky_luat start 100")
	state.money += 1000
	check_eq(state.money, 51000, "money mutable")
