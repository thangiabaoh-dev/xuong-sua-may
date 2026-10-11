class_name OrderFactory
extends RefCounted

const CUSTOMER_MIN_UY_TIN := {"ban_hoc": 0, "hoai_niem": 15, "giao_vien": 30}
const CUSTOMER_MIN_PROJECT_COUNT := {"truong_nhom": 1, "giam_doc": 3}
const CUSTOMER_GLOBAL := ["truong_nhom", "giam_doc"]
const GENERIC_QUOTE := "Máy tôi có vấn đề, anh xem giúp tôi với."

static func eligible_customers(def: MachineDef, ctx: Dictionary) -> Array[String]:
	var uy_tin := int(ctx.get("uy_tin", 0))
	var project_count := int(ctx.get("project_count", 0))
	var result: Array[String] = []
	for c in def.customer_types:
		var key := String(c)
		if CUSTOMER_MIN_UY_TIN.has(key) and uy_tin >= int(CUSTOMER_MIN_UY_TIN[key]):
			result.append(key)
	for k in CUSTOMER_GLOBAL:
		if project_count >= int(CUSTOMER_MIN_PROJECT_COUNT.get(k, 999999)) and not result.has(String(k)):
			result.append(String(k))
	return result

static func make(rng: RandomNumberGenerator, ctx: Dictionary) -> RepairOrder:
	var knowledge := int(ctx.get("knowledge", 0))
	var catalog := MachineGenerator.load_catalog()
	var candidates := MachineGenerator.candidates(knowledge, catalog)
	var pool: Array[MachineDef] = []
	for def in candidates:
		if eligible_customers(def, ctx).size() > 0:
			pool.append(def)
	if pool.is_empty():
		return null
	var def := pool[rng.randi_range(0, pool.size() - 1)]
	var customers := eligible_customers(def, ctx)
	var customer_key: String = customers[rng.randi_range(0, customers.size() - 1)]
	var fault_key := String(def.faults[rng.randi_range(0, def.faults.size() - 1)])
	var fault := FaultCatalog.get_fault(fault_key)
	if fault == null:
		push_error("OrderFactory: missing fault '%s'" % fault_key)
		return null
	var gm := GeneratedMachine.new()
	gm.def = def
	gm.fault = StringName(fault_key)
	gm.price = def.base_price
	var order := RepairOrder.new()
	order.machine = gm
	order.fault_key = fault_key
	order.customer_key = customer_key
	order.symptom_quote = String(fault.symptoms.get(customer_key, GENERIC_QUOTE))
	order.deadline_min = 30 + def.difficulty * 15
	order.money_reward = def.base_price
	return order
