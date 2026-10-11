# Spawn Context + Khách Mới Trong Đơn Sửa Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `truong_nhom`/`giam_doc` spawn trong đơn sửa trên mọi máy khi đạt mốc project, qua chữ ký `make(rng, ctx)`; quote placeholder cho khách mới.

**Architecture:** `OrderFactory` chuyển sang spawn-context Dictionary; pool = khách máy (gate uy_tin, giữ nguyên) + khách global (bỏ qua `customer_types`, gate `project_count`). `repair_panel` dựng ctx từ `game_state`. Quote fallback qua `GENERIC_QUOTE`.

**Tech Stack:** Godot 4 GDScript, test harness `run_suite.sh`/`run_one.gd`.

**Spec:** `docs/superpowers/specs/2026-10-11-spawn-context-design.md`

## Global Constraints

- Branch: `feat/spawn-context` cắt từ `feat/schedule-engine` @ `349cfc2`.
- Exact string: `GENERIC_QUOTE := "Máy tôi có vấn đề, anh xem giúp tôi với."` (test assert đúng chuỗi).
- Const mới: `CUSTOMER_MIN_PROJECT_COUNT := {"truong_nhom": 1, "giam_doc": 3}`; `CUSTOMER_GLOBAL := ["truong_nhom", "giam_doc"]`. `CUSTOMER_MIN_UY_TIN` giữ nguyên giá trị.
- `make(rng: RandomNumberGenerator, ctx: Dictionary) -> RepairOrder` — chữ ký MỚI duy nhất; mọi caller (`repair_panel.gd`, `test_order_factory.gd`, `test_shift_budget.gd`) sửa trong cùng task (gãy compile nếu tách).
- `eligible_customers(def: MachineDef, ctx: Dictionary) -> Array[String]` — ctx thay `uy_tin: int`.
- Đọc ctx an toàn: `int(ctx.get("knowledge", 0))` / `"uy_tin"` / `"project_count"`.
- KHÔNG sửa `.tres` (máy/fault/khách), `unlock_*`, builder tools.
- Gate: `bash repair-shop-game/tests/run_suite.sh` → `TOTAL_FAILURES=0` + không `SCRIPT ERROR` → `GATE PASS` (ledger); smoke `godot --headless --path repair-shop-game --quit-after 60 res://scenes/main.tscn`.
- Commit một lần cuối task; `git add` tên file cụ thể — KHÔNG stage WIP outfit/animation của user (`game_state.gd`, `run_tests.gd`, `cafe.tscn`, `animation_*.gd`, `player.gd`, … đang dirty — file nào KHÔNG thuộc task này không đụng).

## Review Focus

1. **Khách global không gate uy_tin** — `project_count=3` nhưng `uy_tin=0` vẫn spawn được `giam_doc` (rule cycle 3 chỉ có project_count; mong đợi: có mặt trong 50 lần). → test mới `mốc 3 uy_tin 0` trong `test_order_factory.gd`.
2. **`eligible_customers` đổi chữ ký** — regression: `pc_thinkcentre_m710q` (giao_vien) uy_tin 0 → size 0, uy_tin 30 → size 1; `acer_aspire_5` (ban_hoc) uy_tin 0 → size 1. → amend existing asserts theo ctx.
3. **Determinism giữ nguyên** — seed 42 hai lần vẫn ra fault/customer/deadline giống nhau. → amend existing determinism block theo ctx.
4. **Quote cũ không đổi** — khách cũ vẫn `symptoms[customer_key]` (không rơi GENERIC); khách mới == `GENERIC_QUOTE`. → giữ assert cũ "quote from faultxcustomer" + test fallback mới.
5. **Pool rỗng** — uy_tin -1 (ctx) → null như cũ; `ctx == {}` → zeros → null. → amend uy_tin -1 case + thêm `make(rng, {})` case.

---

### Task 1: OrderFactory spawn context + khách global + caller panel

**Files:**
- Modify: `repair-shop-game/scripts/orders/order_factory.gd`
- Modify: `repair-shop-game/scripts/ui/repair_panel.gd:~56-61`
- Test amend: `repair-shop-game/tests/test_order_factory.gd`
- Test amend: `repair-shop-game/tests/test_shift_budget.gd:45,58`

**Interfaces:**
- Consumes: `CustomerCatalog`/`FaultCatalog`/`MachineGenerator` (đã có); customer keys `truong_nhom`/`giam_doc` + `.tres` (cycle 3).
- Produces: `OrderFactory.make(rng: RandomNumberGenerator, ctx: Dictionary) -> RepairOrder`; `OrderFactory.eligible_customers(def: MachineDef, ctx: Dictionary) -> Array[String]`; `OrderFactory.GENERIC_QUOTE: String`; order mới với khách global có `symptom_quote == GENERIC_QUOTE` khi `customer_key` không trong `fault.symptoms`.

- [ ] **Step 1: Amend `test_order_factory.gd` → RED**

Giữ nguyên mọi assertion hiện có, chỉ đổi cách gọi + thêm case mới. Toàn bộ nội dung `run()` mới:

```gdscript
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

	# ctx rong -> zeros; uy_tin -1 -> null
	check(OrderFactory.make(RandomNumberGenerator.new(), {}) == null, "empty ctx -> null")
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
```

- [ ] **Step 2: Amend `test_shift_budget.gd` → RED (cùng task)**

Dòng 45 và 58: `make(rng1, 0, 0)` → `make(rng1, {"knowledge": 0, "uy_tin": 0, "project_count": 0})` (tương tự rng2). Không đổi assertion nào quanh đó.

- [ ] **Step 3: Chạy RED**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_order_factory.gd`
Expected: FAIL/SCRIPT ERROR (make không nhận Dictionary — arity/type mismatch). `test_shift_budget` cũng RED nếu chạy.

- [ ] **Step 4: Implement `order_factory.gd`**

- Đổi `make(rng: RandomNumberGenerator, ctx: Dictionary)`; đầu hàm: `var knowledge := int(ctx.get("knowledge", 0))`, `var uy_tin := int(ctx.get("uy_tin", 0))`, `var project_count := int(ctx.get("project_count", 0))` — phần còn lại của `make` giữ nguyên (candidates/pool/fault/machine/order).
- `eligible_customers(def: MachineDef, ctx: Dictionary)`: đọc `uy_tin` + `project_count` từ ctx (get default 0); loop `def.customer_types` gate `CUSTOMER_MIN_UY_TIN` như cũ; sau đó `for k in CUSTOMER_GLOBAL: if project_count >= int(CUSTOMER_MIN_PROJECT_COUNT.get(k, 999999)) and not result.has(k): result.append(String(k))`.
- Thêm 2 const + `const GENERIC_QUOTE := "Máy tôi có vấn đề, anh xem giúp tôi với."`.
- `order.symptom_quote = String(fault.symptoms.get(customer_key, GENERIC_QUOTE))` thay truy cập `symptoms[customer_key]` trực tiếp.

- [ ] **Step 5: Sửa caller `repair_panel.gd` (cùng task — chữ ký gãy)**

Thay khối `var knowledge := 0 ... uy := 0 ... make(rng, knowledge, uy)` (dòng ~56-61):
```gdscript
	var ctx := {}
	if game_state != null:
		ctx = {"knowledge": int(game_state.knowledge), "uy_tin": int(game_state.uy_tin), "project_count": int(game_state.project_count)}
	var order := OrderFactory.make(rng, ctx)
```
Giữ mọi dòng guard/`session`/`_render()` khác không đổi.

- [ ] **Step 6: Chạy GREEN + gate**

Run: Step 3 command → PASS (FAILURE=0).
Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_shift_budget.gd` → PASS.
Run: `bash repair-shop-game/tests/run_suite.sh` → `TOTAL_FAILURES=0` + không `SCRIPT ERROR` → GATE PASS (ledger).
Run smoke → 0 SCRIPT ERROR.

- [ ] **Step 7: Commit**

```bash
git add repair-shop-game/scripts/orders/order_factory.gd repair-shop-game/scripts/ui/repair_panel.gd repair-shop-game/tests/test_order_factory.gd repair-shop-game/tests/test_shift_budget.gd
git commit -m "feat: spawn context factory + global customers on every machine"
```
