extends "res://tests/test_case.gd"

func run() -> void:
	var hr = load("res://scripts/data/hook_runner.gd")
	check(hr != null, "hook_runner loads")
	if hr == null:
		return
	var gs = load("res://scripts/autoload/game_state.gd").new()

	# count + append id
	var g = hr.apply(gs, "complete_project:p_x", 10)
	check_eq(int(gs.project_count), 1, "count 1")
	check_eq(gs.completed_projects.size(), 1, "1 id")
	check_eq(String(g.get("project", "")), "p_x", "gains project")

	# trung id: count tiep tuc, khong append trung (RF2)
	g = hr.apply(gs, "complete_project:p_x", 10)
	check_eq(int(gs.project_count), 2, "count 2")
	check_eq(gs.completed_projects.size(), 1, "khong trung id")

	# uy_tin cong + clamp 100
	gs.uy_tin = 95
	g = hr.apply(gs, "uy_tin:8", 0)
	check_eq(int(gs.uy_tin), 100, "clamp 100")
	check_eq(int(g.get("uy_tin", 0)), 8, "gains uy_tin")
	gs.uy_tin = 10
	hr.apply(gs, "uy_tin:8", 0)
	check_eq(int(gs.uy_tin), 18, "uy_tin cong binh thuong")

	# pair hong: warn + bo qua, khong count/khong doi state (RF3)
	check_eq(hr.apply(gs, "complete_project:", 0).size(), 0, "id rong -> bo qua")
	check_eq(int(gs.project_count), 2, "id rong khong count")
	check_eq(hr.apply(gs, "complete_project:P Bad", 0).size(), 0, "id sai pattern -> bo qua")
	check_eq(int(gs.project_count), 2, "sai pattern khong count")
	hr.apply(gs, "uy_tin:-5", 0)
	check_eq(int(gs.uy_tin), 18, "uy_tin am bo qua")
	hr.apply(gs, "uy_tin:abc", 0)
	check_eq(int(gs.uy_tin), 18, "uy_tin khong phai int bo qua")

	# knowledge_rate khong regression
	g = hr.apply(gs, "knowledge_rate:0.020", 120)
	check_eq(int(gs.knowledge), 2, "knowledge_rate van chay")

	# combo: 2 pair cung hook
	gs.uy_tin = 50
	g = hr.apply(gs, "complete_project:p_y,uy_tin:6", 0)
	check_eq(int(gs.project_count), 3, "combo count")
	check_eq(int(gs.uy_tin), 56, "combo uy_tin")
	check_eq(String(g.get("project", "")), "p_y", "combo gains project")
	check_eq(int(g.get("uy_tin", 0)), 6, "combo gains uy_tin")
