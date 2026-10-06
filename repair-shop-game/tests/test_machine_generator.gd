extends "res://tests/test_case.gd"

func run() -> void:
	var catalog := MachineGenerator.load_catalog()
	check(catalog.size() >= 32, "catalog loaded")

	check(MachineGenerator.candidates(0, catalog).size() > 0, "week 1 pool not empty")

	for i in 50:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + i
		var gm := MachineGenerator.generate(rng, 0)
		check(gm != null, "generate non-null at knowledge 0")
		if gm != null:
			check_eq(gm.def.era, MachineDef.Era.HIEN_DAI, "no vintage at knowledge 0")
			check(gm.def.faults.has(String(gm.fault)), "fault belongs to machine")
			check_eq(gm.price, gm.def.base_price, "price equals base_price")

	var has_vintage := false
	for m in MachineGenerator.candidates(2, catalog):
		if m.era == MachineDef.Era.CO:
			has_vintage = true
	check(has_vintage, "knowledge 2 unlocks vintage machines")

	var r1 := RandomNumberGenerator.new()
	r1.seed = 42
	var r2 := RandomNumberGenerator.new()
	r2.seed = 42
	var a := MachineGenerator.generate(r1, 2)
	var b := MachineGenerator.generate(r2, 2)
	check(a != null and b != null, "determinism samples generated")
	if a != null and b != null:
		check_eq(a.def.model, b.def.model, "same seed same model")
		check_eq(a.fault, b.fault, "same seed same fault")

	var none := MachineGenerator.generate(RandomNumberGenerator.new(), -1)
	check(none == null, "empty pool returns null")
