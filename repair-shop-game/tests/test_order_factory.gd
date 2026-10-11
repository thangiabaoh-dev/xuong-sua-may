extends "res://tests/test_case.gd"

func _ctx(knowledge: int, uy_tin: int, project_count: int) -> Dictionary:
	return {"knowledge": knowledge, "uy_tin": uy_tin, "project_count": project_count}

func run() -> void:
	# uy_tin gating: moi don knowledge0/uy_tin0 phai la ban_hoc, hop le
	for i in 30:
		var rng := RandomNumberGenerator.new()
		rng.seed = 500 + i
		var o := OrderFactory.make(rng, _ctx(0, 0, 0))
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

	# eligible_customers voi may that (ctx)
	var gv := load("res://data/machines/pc_thinkcentre_m710q.tres")  # customer_types=[giao_vien]
	check_eq(OrderFactory.eligible_customers(gv, _ctx(0, 0, 0)).size(), 0, "giao_vien needs uy_tin30")
	check_eq(OrderFactory.eligible_customers(gv, _ctx(0, 30, 0)).size(), 1, "giao_vien at uy_tin30")
	var bh := load("res://data/machines/acer_aspire_5.tres")         # customer_types=[ban_hoc]
	check_eq(OrderFactory.eligible_customers(bh, _ctx(0, 0, 0)).size(), 1, "ban_hoc always")

	# may chi co ban_hoc van dung duoc truong_nhom khi pass gate (spec Q2 moi may)
	var hp := load("res://data/machines/hp_15.tres")                 # customer_types=[ban_hoc]
	var pool_hp := OrderFactory.eligible_customers(hp, _ctx(0, 100, 1))
	check(pool_hp.has("truong_nhom"), "global truong_nhom on ban_hoc machine")
	check_eq(pool_hp.has("giam_doc"), false, "giam_doc chua dat moc 3")

	# ctx rong -> zeros (khach min uy_tin 0 van spawn); uy_tin -1 -> null
	var ozero := OrderFactory.make(RandomNumberGenerator.new(), {})
	check(ozero != null, "empty ctx -> zeros -> van co don ban_hoc")
	if ozero != null:
		check_eq(ozero.customer_key, "ban_hoc", "empty ctx khach la ban_hoc")
	check(OrderFactory.make(RandomNumberGenerator.new(), _ctx(0, -1, 0)) == null, "empty pool null")

	# determinism
	var r1 := RandomNumberGenerator.new(); r1.seed = 42
	var r2 := RandomNumberGenerator.new(); r2.seed = 42
	var a := OrderFactory.make(r1, _ctx(2, 30, 0))
	var b := OrderFactory.make(r2, _ctx(2, 30, 0))
	check(a != null and b != null, "determinism samples")
	if a != null and b != null:
		check_eq(a.fault_key, b.fault_key, "same seed same fault")
		check_eq(a.customer_key, b.customer_key, "same seed same customer")
		check_eq(a.deadline_min, b.deadline_min, "same seed same deadline")

	# zeros: khach moi khong xuat hien (spec §7)
	for i in 50:
		var rz := RandomNumberGenerator.new()
		rz.seed = 900 + i
		var oz := OrderFactory.make(rz, _ctx(30, 0, 0))
		if oz != null:
			check(oz.customer_key != "truong_nhom" and oz.customer_key != "giam_doc",
				"zeros khong ra khach moi (lan %d)" % i)

	# moc 1: truong_nhom co, giam_doc khong
	var seen_tn := false
	var seen_gd1 := false
	for i in 50:
		var r1m := RandomNumberGenerator.new()
		r1m.seed = 1900 + i
		var o1 := OrderFactory.make(r1m, _ctx(30, 100, 1))
		if o1 != null:
			if o1.customer_key == "truong_nhom":
				seen_tn = true
			if o1.customer_key == "giam_doc":
				seen_gd1 = true
	check(seen_tn, "moc 1 thay truong_nhom trong 50 lan")
	check_eq(seen_gd1, false, "moc 1 khong thay giam_doc")

	# moc 3: ca 2 khach xuat hien; khach moi khong gate uy_tin (RF1)
	var seen_tn3 := false
	var seen_gd3 := false
	for i in 50:
		var r3 := RandomNumberGenerator.new()
		r3.seed = 3900 + i
		var o3 := OrderFactory.make(r3, _ctx(30, 0, 3))
		if o3 != null:
			if o3.customer_key == "truong_nhom":
				seen_tn3 = true
			if o3.customer_key == "giam_doc":
				seen_gd3 = true
	check(seen_tn3, "moc 3 (uy_tin 0) thay truong_nhom")
	check(seen_gd3, "moc 3 (uy_tin 0) thay giam_doc — khach moi khong gate uy_tin")

	# quote fallback: khach moi dung GENERIC_QUOTE (RF4)
	var found_gd := false
	for i in 120:
		var rg := RandomNumberGenerator.new()
		rg.seed = 5900 + i
		var og := OrderFactory.make(rg, _ctx(30, 0, 3))
		if og != null and og.customer_key == "giam_doc":
			check_eq(og.symptom_quote, OrderFactory.GENERIC_QUOTE, "giam_doc quote = GENERIC")
			found_gd = true
			break
	check(found_gd, "tim thay giam_doc de test quote (120 lan)")
