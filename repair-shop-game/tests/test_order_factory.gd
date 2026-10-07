extends "res://tests/test_case.gd"

func run() -> void:
	# uy_tin gating: moi don knowledge0/uy_tin0 phai la ban_hoc, hop le
	for i in 30:
		var rng := RandomNumberGenerator.new()
		rng.seed = 500 + i
		var o := OrderFactory.make(rng, 0, 0)
		check(o != null, "order non-null at uy_tin 0")
		if o == null:
			continue
		check_eq(o.customer_key, "ban_hoc", "uy_tin0 only ban_hoc")
		check(o.machine.def.faults.has(String(o.fault_key)), "fault belongs")
		check_eq(o.deadline_min, 30 + o.machine.def.difficulty * 15, "deadline formula")
		check_eq(o.money_reward, o.machine.def.base_price, "reward == base_price")
		check(o.symptom_quote != "", "symptom quote non-empty")
		check_eq(o.symptom_quote,
			FaultCatalog.get_fault(o.fault_key).symptoms[o.customer_key], "quote from faultxcustomer")

	# eligible_customers voi may that
	var gv := load("res://data/machines/pc_thinkcentre_m710q.tres")  # customer_types=[giao_vien]
	check_eq(OrderFactory.eligible_customers(gv, 0).size(), 0, "giao_vien needs uy_tin30")
	check_eq(OrderFactory.eligible_customers(gv, 30).size(), 1, "giao_vien at uy_tin30")
	var bh := load("res://data/machines/acer_aspire_5.tres")         # customer_types=[ban_hoc]
	check_eq(OrderFactory.eligible_customers(bh, 0).size(), 1, "ban_hoc always")

	# uy_tin=-1 -> null
	check(OrderFactory.make(RandomNumberGenerator.new(), 0, -1) == null, "empty pool null")

	# determinism
	var r1 := RandomNumberGenerator.new(); r1.seed = 42
	var r2 := RandomNumberGenerator.new(); r2.seed = 42
	var a := OrderFactory.make(r1, 2, 30)
	var b := OrderFactory.make(r2, 2, 30)
	check(a != null and b != null, "determinism samples")
	if a != null and b != null:
		check_eq(a.fault_key, b.fault_key, "same seed same fault")
		check_eq(a.customer_key, b.customer_key, "same seed same customer")
		check_eq(a.deadline_min, b.deadline_min, "same seed same deadline")
