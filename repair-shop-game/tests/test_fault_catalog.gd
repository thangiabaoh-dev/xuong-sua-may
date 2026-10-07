extends "res://tests/test_case.gd"

const NINE := ["battery_swollen", "board_short", "dim_screen", "keyboard_dead",
	"loose_port", "no_power", "no_wifi", "overheat", "slow_hdd"]
const CHECKS := ["do_nguon", "nghe_quat", "kiem_tra_ram", "nhin_bo"]
const CUSTOMERS := ["ban_hoc", "giao_vien", "hoai_niem"]
const MINIGAMES := ["van_oc", "han_mach", "cam_cap", "lau_bui"]

func run() -> void:
	var all := FaultCatalog.load_all()
	check_eq(all.size(), 9, "9 fault files")
	var keys := {}
	for f in all:
		keys[f.key] = true
	check_eq(keys.size(), 9, "keys unique")
	for k in NINE:
		check(keys.has(k), "covers " + k)

	for f in all:
		check(f.display_name != "" and f.part_id != "" and f.part_name != "", "names " + f.key)
		check(f.part_price > 0, "part_price " + f.key)
		check(MINIGAMES.has(f.minigame), "minigame valid " + f.key)
		for c in CUSTOMERS:
			check(String(f.symptoms.get(c, "")) != "", "symptom %s/%s" % [f.key, c])
		check_eq(f.check_outcomes.size(), 4, "4 checks " + f.key)
		for ck in CHECKS:
			var cell = f.check_outcomes.get(ck, null)
			check(cell != null, "cell exists %s/%s" % [f.key, ck])
			if cell == null:
				continue
			check(String(cell.get("clue", "")) != "", "clue non-empty %s/%s" % [f.key, ck])
			var ex = cell.get("excludes", [])
			check(not ex.has(f.key), "no self-exclude %s/%s" % [f.key, ck])
			for e in ex:
				check(NINE.has(String(e)), "excludes in NINE %s/%s" % [f.key, ck])

	var union := {}
	for m in MachineGenerator.load_catalog():
		for fk in m.faults:
			union[String(fk)] = true
	check_eq(union.size(), 9, "machine catalog union == 9 faults")

	check(FaultCatalog.get_fault("no_power") != null, "get_fault hit")
	check(FaultCatalog.get_fault("xxx") == null, "get_fault miss")
