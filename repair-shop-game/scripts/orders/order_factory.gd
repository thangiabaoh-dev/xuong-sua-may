class_name OrderFactory
extends RefCounted

const CUSTOMER_MIN_UY_TIN := {"ban_hoc": 0, "hoai_niem": 15, "giao_vien": 30}

static func eligible_customers(def: MachineDef, uy_tin: int) -> Array[String]:
	var result: Array[String] = []
	for c in def.customer_types:
		var key := String(c)
		if CUSTOMER_MIN_UY_TIN.has(key) and uy_tin >= int(CUSTOMER_MIN_UY_TIN[key]):
			result.append(key)
	return result

static func make(rng: RandomNumberGenerator, knowledge: int, uy_tin: int) -> RepairOrder:
	var catalog := MachineGenerator.load_catalog()
	var candidates := MachineGenerator.candidates(knowledge, catalog)
	var pool: Array[MachineDef] = []
	for def in candidates:
		if eligible_customers(def, uy_tin).size() > 0:
			pool.append(def)
	if pool.is_empty():
		return null
	var def: MachineDef = pool[rng.randi_range(0, pool.size() - 1)]
	var customers := eligible_customers(def, uy_tin)
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
	order.symptom_quote = String(fault.symptoms.get(customer_key, ""))
	order.deadline_min = 30 + def.difficulty * 15
	order.money_reward = def.base_price
	return order
