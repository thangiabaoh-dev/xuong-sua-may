extends "res://tests/test_case.gd"

const FAULT_KEYS: Array[String] = [
	"no_power", "dim_screen", "overheat", "slow_hdd", "keyboard_dead",
	"battery_swollen", "no_wifi", "loose_port", "board_short"
]
const CUSTOMER_KEYS: Array[String] = ["ban_hoc", "giao_vien", "hoai_niem"]

func run() -> void:
	var catalog := MachineGenerator.load_catalog()
	check(catalog.size() >= 10, "catalog has at least 10 machines")
	if catalog.is_empty():
		return
	var modern := 0
	var vintage := 0
	for m in catalog:
		if m.era == MachineDef.Era.HIEN_DAI:
			modern += 1
		if m.era == MachineDef.Era.CO:
			vintage += 1
		check(m.era == MachineDef.Era.HIEN_DAI or m.era == MachineDef.Era.CO, "era valid: " + m.model)
		check(m.brand != "" and m.model != "", "brand/model non-empty: " + m.model)
		check(m.year >= 1990 and m.year <= 2026, "year in 1990-2026: " + m.model)
		check(m.parts.size() > 0, "parts non-empty: " + m.model)
		check(m.faults.size() > 0, "faults non-empty: " + m.model)
		for fk in m.faults:
			check(FAULT_KEYS.has(fk), "known fault '" + fk + "' on " + m.model)
		check(m.difficulty >= 1 and m.difficulty <= 5, "difficulty 1-5: " + m.model)
		check(m.base_price > 0, "price positive: " + m.model)
		check(m.min_knowledge >= 0, "min_knowledge >= 0: " + m.model)
		check(m.customer_types.size() > 0, "customers non-empty: " + m.model)
		for ck in m.customer_types:
			check(CUSTOMER_KEYS.has(ck), "known customer '" + ck + "' on " + m.model)
		if m.era != MachineDef.Era.CO:
			check(not m.faults.has("dim_screen"), "dim_screen only on vintage: " + m.model)
	check(modern >= 10, "at least 10 modern machines")
	check(catalog.size() >= 32, "catalog has at least 32 machines")
	check(vintage >= 22, "at least 22 vintage machines")

	var fx := MachineGenerator.scan_dir("res://tests/fixtures/machines")
	check_eq(fx.size(), 1, "broken .tres skipped by scan_dir")
