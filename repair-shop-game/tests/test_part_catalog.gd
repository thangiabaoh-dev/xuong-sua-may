extends "res://tests/test_case.gd"

const NINE := {"nguon_adapter": 45000, "den_nen_inverter": 90000, "quat_tan_re": 35000,
	"ssd_240": 250000, "ban_phim_laptop": 100000, "pin_laptop": 150000,
	"card_wifi": 70000, "cong_sac": 40000, "linh_kien_bo": 120000}

func run() -> void:
	var all := PartCatalog.load_all()
	check_eq(all.size(), 9, "9 part files")
	var ids := {}
	for p in all:
		ids[p.id] = true
		check(NINE.has(p.id), "known id " + p.id)
		if NINE.has(p.id):
			check_eq(p.price, int(NINE[p.id]), "price " + p.id)
		check(p.name != "", "name " + p.id)
	check_eq(ids.size(), 9, "ids unique")
	check(PartCatalog.get_part("ssd_240") != null, "get_part hit")
	check(PartCatalog.get_part("xxx") == null, "get_part miss")
	for f in FaultCatalog.load_all():
		check(PartCatalog.get_part(f.part_id) != null, "fault part resolvable " + f.key)
