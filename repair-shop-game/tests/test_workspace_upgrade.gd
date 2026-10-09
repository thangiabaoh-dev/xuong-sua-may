extends "res://tests/test_case.gd"

func _def(to_tier: int, cost: int, uy: int, cond: String = "") -> WorkspaceUpgrade:
	var d := WorkspaceUpgrade.new()
	d.to_tier = to_tier
	d.cost = cost
	d.uy_tin_req = uy
	d.condition = cond
	return d

func run() -> void:
	var logic = load("res://scripts/progression/workspace_upgrades.gd")
	var gs_script = load("res://scripts/autoload/game_state.gd")

	var defs = [_def(1, 1000000, 40), _def(2, 5000000, 120)]

	# thieu tien -> no_money, khong mutate (Review Focus #2)
	var gs = gs_script.new()
	gs.money = 50000
	gs.uy_tin = 100
	check_eq(logic.try_upgrade(gs, defs), "no_money", "thieu tien -> no_money")
	check_eq(gs.money, 50000, "money khong doi")
	check_eq(gs.workspace_tier, 0, "tier khong doi")

	# thieu uy tin -> low_uy_tin, khong mutate
	gs.money = 2000000
	gs.uy_tin = 10
	check_eq(logic.try_upgrade(gs, defs), "low_uy_tin", "thieu uy tin -> low_uy_tin")
	check_eq(gs.money, 2000000, "money khong doi (uy tin fail)")
	check_eq(gs.workspace_tier, 0, "tier khong doi (uy tin fail)")

	# thanh cong -> tru dung tien, tier +1, return ""
	gs.uy_tin = 40
	check_eq(logic.try_upgrade(gs, defs), "", "du dieu kien -> ok")
	check_eq(gs.money, 1000000, "tru dung 1.000.000")
	check_eq(gs.workspace_tier, 1, "tier 0 -> 1")

	# tiep tuc len shop
	gs.money = 6000000
	gs.uy_tin = 120
	check_eq(logic.try_upgrade(gs, defs), "", "len shop -> ok")
	check_eq(gs.money, 1000000, "tru them 5.000.000")
	check_eq(gs.workspace_tier, 2, "tier 1 -> 2")

	# da max tier
	check_eq(logic.try_upgrade(gs, defs), "max_tier", "tier 2 -> max_tier")

	# nhay tier (defs thieu buoc giua)
	var gs3 = gs_script.new()
	gs3.money = 9999999
	gs3.uy_tin = 999
	check_eq(logic.try_upgrade(gs3, [_def(2, 1, 1)]), "max_tier", "nhay 0 -> 2 bi chan")
	check_eq(gs3.workspace_tier, 0, "tier khong doi")

	# condition bai toan
	var gs4 = gs_script.new()
	gs4.money = 2000000
	gs4.uy_tin = 50
	var cond_defs = [_def(1, 1000000, 40, "knowledge >= 50")]
	check_eq(logic.try_upgrade(gs4, cond_defs), "condition", "condition sai -> chan, khong mutate")
	check_eq(gs4.money, 2000000, "money khong doi (condition fail)")
	gs4.knowledge = 50
	check_eq(logic.try_upgrade(gs4, cond_defs), "", "condition dung -> ok")
	check_eq(gs4.workspace_tier, 1, "tier len sau condition pass")

	# defs rong
	check_eq(logic.try_upgrade(gs_script.new(), []), "max_tier", "defs rong -> max_tier")

	# file .tres
	var set = load("res://data/workspace_upgrades.tres")
	check(set != null, "workspace_upgrades.tres loads")
	if set != null:
		check_eq(set.defs.size(), 2, "2 upgrade defs")
		check_eq(set.defs[0].to_tier, 1, "def0 -> ROOM")
		check_eq(set.defs[1].cost, 5000000, "def1 cost 5.000.000")
