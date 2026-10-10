extends "res://tests/test_case.gd"

func run() -> void:
	var gs = load("res://scripts/autoload/game_state.gd").new()
	# du hoc (450) -> khong phat
	gs.today_activities = [{"id": "di_hoc", "label": "Đi học", "minutes": 450}]
	check_eq(gs.school_minutes_done(), 450, "done 450")
	var ky0: int = int(gs.ky_luat)
	gs.begin_new_day()
	check_eq(int(gs.ky_luat), ky0, "full school no penalty")
	# thieu dung 450 -> -10
	gs.today_activities = []
	var ky1: int = int(gs.ky_luat)
	gs.begin_new_day()
	check_eq(int(gs.ky_luat), ky1 - 10, "missing 450 -> -10")
	# thieu 449 (du 1 phut di hoc) van -10 (ceil(449/450)=1)
	gs.today_activities = [{"id": "di_hoc", "label": "Đi học", "minutes": 1}]
	check_eq(gs.school_minutes_done(), 1, "done 1")
	var ky2: int = int(gs.ky_luat)
	gs.begin_new_day()
	check_eq(int(gs.ky_luat), ky2 - 10, "missing 449 -> -10")
	# vuot qua expected -> khong am
	gs.today_activities = [{"id": "di_hoc", "label": "Đi học", "minutes": 451}]
	check_eq(gs.school_minutes_done(), 451, "done 451")
	var ky3: int = int(gs.ky_luat)
	gs.begin_new_day()
	check_eq(int(gs.ky_luat), ky3, "over-complete no penalty")
