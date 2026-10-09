# Unlock Engine + Workspace Tier Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Backend mở khoá data-driven (condition = Godot Expression string) + nâng cấp chỗ làm `DESK→ROOM→SHOP` validate-before-mutate, kèm event unlock cho UI/spec 4b.

**Architecture:** `UnlockCore` (RefCounted) parse mỗi `UnlockRule.condition` một lần khi `setup()`, `refresh(gs)` snapshot 5 input từ GameState rồi `Expression.execute(inputs, UnlockContext, show_error=false)`; unlock đã nhận = vĩnh viễn (`permanent` set). `WorkspaceUpgrades.try_upgrade` kiểm tiền/uy tín/condition rồi mới mutate. File mới hoàn toàn trong `scripts/progression/`; đụng `game_state.gd` đúng +2 field.

**Tech Stack:** Godot 4.7 headless, GDScript, Resource `.tres`, test harness `tests/run_one.gd` + `run_suite.sh`.

**Spec:** `docs/superpowers/specs/2026-10-09-progression-unlock-design.md`

## Global Constraints

- Gate từng task: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/<test>.gd` → `FAILURES=0`; gate gộp: `bash repair-shop-game/tests/run_suite.sh` → `TOTAL_FAILURES=0` + `GATE PASS` + **không dòng `SCRIPT ERROR`** (FAILURES xanh mà có SCRIPT ERROR = false green — đã ledger).
- Script mới có `class_name` phải chạy `godot --headless --path repair-shop-game --import` trước khi test (lesson ledger).
- **Không sửa file của session khác.** File duy nhất được modify: `scripts/autoload/game_state.gd` (+2 field, additive) và `tests/run_tests.gd` (đăng ký test).
- Đúng pattern TDD: test RED → implement → GREEN → commit. Test helpers: `check(cond, msg)`, `check_eq(actual, expected, msg)` từ `tests/test_case.gd`. Harness không có autoloads → `load("res://scripts/autoload/game_state.gd").new()`.
- Input variables của Expression (thứ tự cố định): `["money", "knowledge", "uy_tin", "ky_luat", "workspace_tier"]`. Reason key của `try_upgrade`: `"max_tier" | "no_money" | "low_uy_tin" | "condition"`; thành công = `""`.
- Prefix commit: `feat:` / `test:` / `docs:`.

## Review Focus

1. **Unlock vĩnh viễn sau khi money giảm** — rule `money >= 100` mở khi money=200, tiêu xuống 0 → người chơi vẫn phải giữ quyền unlock (mất = bug cảm nhận "bỏ lỡ là mất thật" bị đảo nghĩa). → Task 2, test `permanent survives money drop`.
2. **`try_upgrade` fail không được mutate gì** — fail nhánh nào thì `money` và `workspace_tier` phải giữ nguyên tuyệt đối (trừ tiền trước khi check = mất tiền thật). → Task 4, test từng nhánh assert `money`/`tier` không đổi.
3. **Identifier lạ trong condition trả `null` im lặng** — rule gõ sai biến (`knowlege`) sẽ không bao giờ mở khoá cho người chơi, không ai phát hiện nếu chỉ nhìn "PASS". → Task 1 (detect null → `parse_errors`) + Task 3 (mọi rule trong `.tres` phải qua `parse_errors().is_empty()` sau refresh).
4. **`unlock_changed` phát đúng 1 lần mỗi transition** — phát lại mỗi `refresh` = UI/spec 4b hiển thị milestone trùng; không phát lúc lock→lock. → Task 2, test emit-once qua 3 lần refresh.
5. **`refresh` đọc GameState tươi mỗi lần** — cache input cũ khi `setup` = tri thức tăng sau đó không bao giờ unlock (engine chết lặng lẽ). → Task 1, test cùng 1 core instance: knowledge 0 → lock; ghi knowledge=100 → refresh → unlock.

---

### Task 1: UnlockRule + UnlockContext + UnlockCore (parse/refresh/query) + GameState fields

**Files:**
- Create: `repair-shop-game/scripts/progression/unlock_rule.gd`
- Create: `repair-shop-game/scripts/progression/unlock_context.gd`
- Create: `repair-shop-game/scripts/progression/unlock_core.gd`
- Modify: `repair-shop-game/scripts/autoload/game_state.gd` (thêm 2 field, cuối file)
- Test: `repair-shop-game/tests/test_unlock_core.gd`

**Interfaces:**
- Consumes: `tests/test_case.gd` (`check/check_eq`), Godot `Expression` (probe: parse(text, input_names) → err code; execute(inputs, base, show_error=false)).
- Produces (Task 2–4 dùng lại):
  - `UnlockRule` Resource: `id: StringName, target_kind: String, target_id: StringName, condition: String, enabled: bool = true`
  - `UnlockContext` extends RefCounted: `var completed_projects: Array = []` (untyped nội bộ), `func has_project(id: StringName) -> bool`
  - `UnlockCore` extends RefCounted: `signal unlock_changed(id: StringName)`, `func setup(rules: Array) -> void`, `func refresh(game_state: Node) -> void`, `func is_unlocked(id: StringName) -> bool`, `func unlocked_ids() -> Array[StringName]`, `func parse_errors() -> Array[String]`
  - `GameState`: `var workspace_tier: int = 0`, `var completed_projects: Array[StringName] = []`

- [ ] **Step 1: Viết test RED `tests/test_unlock_core.gd`**

```gdscript
extends "res://tests/test_case.gd"

func _rule(id: String, cond: String) -> UnlockRule:
	var r := UnlockRule.new()
	r.id = id
	r.target_kind = "machine"
	r.target_id = id
	r.condition = cond
	return r

func run() -> void:
	var core_script = load("res://scripts/progression/unlock_core.gd")
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var gs = gs_script.new()

	# boundary knowledge (Review Focus #5)
	var c1 = core_script.new()
	c1.setup([_rule("may_co", "knowledge >= 50")])
	c1.refresh(gs)
	check_eq(c1.is_unlocked("may_co"), false, "knowledge 0 -> locked")
	gs.knowledge = 50
	c1.refresh(gs)
	check_eq(c1.is_unlocked(&"may_co"), true, "knowledge 50 -> unlocked (fresh read)")

	# boundary uy_tin rule
	var c2 = core_script.new()
	c2.setup([_rule("khach_giao_vien", "uy_tin >= 60")])
	gs.uy_tin = 59
	c2.refresh(gs)
	check_eq(c2.is_unlocked("khach_giao_vien"), false, "uy_tin 59 -> locked")
	gs.uy_tin = 60
	c2.refresh(gs)
	check_eq(c2.is_unlocked("khach_giao_vien"), true, "uy_tin 60 -> unlocked")

	# rule 2 bien: workspace tier + uy tin
	var c3 = core_script.new()
	c3.setup([_rule("khach_phong_tin", "uy_tin >= 90 and workspace_tier >= 1")])
	gs.uy_tin = 90
	gs.workspace_tier = 0
	c3.refresh(gs)
	check_eq(c3.is_unlocked("khach_phong_tin"), false, "tier 0 -> locked")
	gs.workspace_tier = 1
	c3.refresh(gs)
	check_eq(c3.is_unlocked("khach_phong_tin"), true, "tier 1 -> unlocked")

	# has_project (method call tren UnlockContext)
	var c4 = core_script.new()
	c4.setup([_rule("feature_x", 'has_project("p1")')])
	c4.refresh(gs)
	check_eq(c4.is_unlocked("feature_x"), false, "no project -> locked")
	gs.completed_projects = [&"p1"]
	c4.refresh(gs)
	check_eq(c4.is_unlocked("feature_x"), true, "project done -> unlocked")

	# disabled rule: condition rac khong vao parse_errors
	var c5 = core_script.new()
	var bad = _rule("off_rule", "?? bad ??")
	bad.enabled = false
	c5.setup([bad])
	check(c5.parse_errors().is_empty(), "disabled rule skipped, no parse error")

	# identifier la -> parse ok nhung execute null -> parse_errors (Review Focus #3)
	var c6 = core_script.new()
	c6.setup([_rule("typo_rule", "knowlege >= 50")])
	c6.refresh(gs)
	check(not c6.parse_errors().is_empty(), "unknown identifier reported")
	check_eq(c6.is_unlocked("typo_rule"), false, "unknown identifier -> locked")

	# parse error syntax -> parse_errors
	var c7 = core_script.new()
	c7.setup([_rule("syntax_rule", "knowledge >= 50 ??")])
	check(not c7.parse_errors().is_empty(), "syntax error reported")

	# GameState thieu field -> khong crash, fallback 0 (spec §5)
	var c8 = core_script.new()
	c8.setup([_rule("safe_rule", "knowledge >= 50")])
	c8.refresh(Node.new())
	check_eq(c8.is_unlocked("safe_rule"), false, "bare Node fallback -> locked")
	check(c8.parse_errors().is_empty(), "fallback khong tao loi gia mao")

	check_eq(c1.unlocked_ids().size(), 1, "unlocked_ids size")

	# short-circuit: operand trai false -> operand phai khong chay, khong loi
	var c9 = core_script.new()
	c9.setup([_rule("sc_rule", 'knowledge >= 50 and has_project("p1")')])
	gs.knowledge = 0
	gs.completed_projects = []
	c9.refresh(gs)
	check_eq(c9.is_unlocked("sc_rule"), false, "short-circuit false -> locked")
	check(c9.parse_errors().is_empty(), "short-circuit khong tao loi")
```

- [ ] **Step 2: Chạy — verify RED**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_unlock_core.gd`
Expected: `FAIL load:` (chưa có script) hoặc FAILES do thiếu field.

- [ ] **Step 3: Implement 3 script progression + 2 field GameState**

- `unlock_rule.gd`: đúng interface trên (`@export` đầy đủ để serialize `.tres`).
- `unlock_context.gd`: `completed_projects: Array = []`; `has_project(id) -> bool: return completed_projects.has(id)` (Array.has so sánh `==`, String/StringName tương thích).
- `unlock_core.gd`:
  - Internal: `_rules: Array`, `_parsed: Dictionary` (id → Expression), `_errors: Array[String]`, `_unlocked: Dictionary` (set).
  - `setup()`: clear state; với rule `enabled`: `Expression.parse(condition, INPUT_NAMES)` → err ≠ OK thì `_errors.append("%s: %s" % [rule.id, expr.get_error_text()])`, không đưa vào `_parsed`; err == OK thì `_parsed[rule.id] = expr` (parse 1 lần — cache).
  - `refresh(gs)`: dựng `inputs: Array` từ `_int_field(gs, "money")` … 5 field (helper đọc `gs.get(prop)`, `null → 0` — **không** đụng prop trực tiếp); copy `gs.get("completed_projects")` sang ctx (nếu `is Array`); với mỗi `(id, expr)` trong `_parsed`: `var r = expr.execute(inputs, ctx, false)`; `r == null` → `_errors.append("%s: evaluate null (unknown identifier?)" % id)` + coi false; `r == true` → `_unlocked[id] = true` (Task 2 sẽ thêm signal/permanent — Task 1 chỉ set).
  - `parse_errors()`, `is_unlocked(id) -> _unlocked.has(id)`, `unlocked_ids() -> Array[StringName]`.
  - `const INPUT_NAMES := ["money", "knowledge", "uy_tin", "ky_luat", "workspace_tier"]`.
- `game_state.gd`: thêm đúng 2 dòng cuối file:
  `var workspace_tier: int = 0`
  `var completed_projects: Array[StringName] = []`

- [ ] **Step 4: Chạy — verify GREEN (cần --import vì có class_name mới)**

Run: `godot --headless --path repair-shop-game --import >/dev/null 2>&1 && godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_unlock_core.gd`
Expected: `FAILURES=0`

- [ ] **Step 5: Đăng ký test + gate gộp**

Thêm `"res://tests/test_unlock_core.gd",` vào `TEST_SCRIPTS` (run_tests.gd), rồi:
Run: `bash repair-shop-game/tests/run_suite.sh`
Expected: `TOTAL_FAILURES=0` + `GATE PASS` + không `SCRIPT ERROR`

- [ ] **Step 6: Commit**

```bash
git add repair-shop-game/scripts/progression/ repair-shop-game/scripts/autoload/game_state.gd repair-shop-game/tests/test_unlock_core.gd repair-shop-game/tests/run_tests.gd
git commit -m "feat: unlock core engine (Expression-based) + game_state fields"
```

---

### Task 2: `unlock_changed` event + unlock vĩnh viễn (permanent)

**Files:**
- Modify: `repair-shop-game/scripts/progression/unlock_core.gd`
- Test: `repair-shop-game/tests/test_unlock_core.gd` (append block)

**Interfaces:**
- Consumes: Task 1 (`UnlockCore.setup/refresh/is_unlocked`, signal đã khai báo ở Task 1).
- Produces: `signal unlock_changed(id: StringName)` phát đúng 1 lần khi transition locked→unlocked; semantics permanent (spec §4) — Task 3/4 và 4b dựa vào đây.

- [ ] **Step 1: Append test RED (block cuối `run()`)**

```gdscript
	# unlock_changed: dung 1 lan per transition (Review Focus #4)
	var ce = core_script.new()
	ce.setup([_rule("khach_giao_vien", "uy_tin >= 60")])
	var box: Array = []
	ce.unlock_changed.connect(func(id): box.append(id))
	gs.uy_tin = 0
	ce.refresh(gs)
	check_eq(box.size(), 0, "khong emit khi van locked")
	gs.uy_tin = 60
	ce.refresh(gs)
	check_eq(box.size(), 1, "emit dung 1 lan khi unlock")
	check_eq(box[0], &"khach_giao_vien", "emit id dung")
	ce.refresh(gs)
	check_eq(box.size(), 1, "refresh lai khong emit lai")

	# permanent: money tieu het van giu unlock (Review Focus #1)
	var cp = core_script.new()
	cp.setup([_rule("tool_x", "money >= 100")])
	var box2: Array = []
	cp.unlock_changed.connect(func(id): box2.append(id))
	gs.money = 200
	cp.refresh(gs)
	check_eq(cp.is_unlocked("tool_x"), true, "money 200 -> unlocked")
	check_eq(box2.size(), 1, "emit lan dau cho tool_x")
	gs.money = 0
	cp.refresh(gs)
	check_eq(cp.is_unlocked("tool_x"), true, "permanent: money 0 van unlocked")
	check_eq(box2.size(), 1, "khong emit lai khi van unlocked")
```


- [ ] **Step 2: Chạy — verify RED**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_unlock_core.gd`
Expected: `FAIL: unlock_changed ...` / `permanent ...` (signal chưa emit, money=0 → locked)

- [ ] **Step 3: Implement trong `unlock_core.gd`**

- Thêm `var _permanent: Dictionary = {}`.
- `refresh()` khi `r == true`: nếu `_unlocked` chưa có id → `_unlocked[id] = true`; nếu id chưa trong `_permanent` → `_permanent[id] = true` + `unlock_changed.emit(id)`.
- Khi `r == false`: chỉ bỏ khỏi `_unlocked` nếu id **không** trong `_permanent`.
- `setup()` reset cả `_permanent` (mỗi core mới = trạng thái sạch).

- [ ] **Step 4: Chạy — verify GREEN**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_unlock_core.gd`
Expected: `FAILURES=0`

- [ ] **Step 5: Gate gộp**

Run: `bash repair-shop-game/tests/run_suite.sh`
Expected: `TOTAL_FAILURES=0` + `GATE PASS`, không `SCRIPT ERROR`

- [ ] **Step 6: Commit**

```bash
git add repair-shop-game/scripts/progression/unlock_core.gd repair-shop-game/tests/test_unlock_core.gd
git commit -m "feat: unlock_changed event + permanent unlock semantics"
```

---

### Task 3: Tool sinh `.tres` + `data/unlock_rules.tres` + test dữ liệu

**Files:**
- Create: `repair-shop-game/scripts/progression/unlock_rule_set.gd`
- Create: `repair-shop-game/tools/build_progression.gd`
- Create: `repair-shop-game/data/unlock_rules.tres` (sinh bởi tool)
- Test: `repair-shop-game/tests/test_unlock_data.gd`

**Interfaces:**
- Consumes: `UnlockRule`, `UnlockCore` (Task 1–2); pattern `tools/build_week_schedule.gd` (SceneTree script + ResourceSaver).
- Produces: `UnlockRuleSet` Resource `{ @export var rules: Array[UnlockRule] = [] }`; `res://data/unlock_rules.tres` — Task 4 và 4b nạp từ đây.

- [ ] **Step 1: Viết test RED `tests/test_unlock_data.gd`**

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var set = load("res://data/unlock_rules.tres")
	check(set != null, "unlock_rules.tres loads")
	if set == null:
		return
	check(set.rules.size() == 4, "4 rules")
	var ids: Array = []
	for r in set.rules:
		ids.append(String(r.id))
	for want in ["may_co", "may_phuc_tap", "khach_giao_vien", "khach_phong_tin"]:
		check(ids.has(want), "has rule %s" % want)

	var core_script = load("res://scripts/progression/unlock_core.gd")
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var core = core_script.new()
	core.setup(set.rules)
	check(core.parse_errors().is_empty(), "tat ca rule parse OK")

	var gs = gs_script.new()   # mac dinh: 0/0/0/100/tier0 -> tat ca locked
	core.refresh(gs)
	check(core.parse_errors().is_empty(), "khong evaluate null (Review Focus #3)")
	check_eq(core.unlocked_ids().size(), 0, "mac dinh khong co gi mo khoa")
	check_eq(gs.money, 50000, "tien dau game 50000 (khong bi rule nao an)")
```

- [ ] **Step 2: Chạy — verify RED**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_unlock_data.gd`
Expected: `FAIL load:` (chưa có `.tres`/test)

- [ ] **Step 3: Implement container + tool, sinh `.tres`**

- `unlock_rule_set.gd`: `class_name UnlockRuleSet extends Resource`, `@export var rules: Array[UnlockRule] = []`.
- `tools/build_progression.gd`: `extends SceneTree`; `_init` dựng 4 `UnlockRule` đúng bảng spec §2.5 (mỗi rule: `id/target_kind/target_id/condition/enabled=true`; `target_kind`: may_co+may_phuc_tap = `"machine"`, 2 rule khách = `"customer"`; condition y như spec) → `UnlockRuleSet` → `ResourceSaver.save(set, "res://data/unlock_rules.tres")` → `print` kết quả → `quit(0)`.
- Chạy: `godot --headless --path repair-shop-game -s res://tools/build_progression.gd`

- [ ] **Step 4: Chạy — verify GREEN**

Run: `godot --headless --path repair-shop-game --import >/dev/null 2>&1 && godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_unlock_data.gd`
Expected: `FAILURES=0`

- [ ] **Step 5: Đăng ký + gate gộp**

Thêm `"res://tests/test_unlock_data.gd",` vào `run_tests.gd`; `bash repair-shop-game/tests/run_suite.sh` → `TOTAL_FAILURES=0` + `GATE PASS`, không `SCRIPT ERROR`

- [ ] **Step 6: Commit**

```bash
git add repair-shop-game/scripts/progression/unlock_rule_set.gd repair-shop-game/tools/build_progression.gd repair-shop-game/data/unlock_rules.tres repair-shop-game/tests/test_unlock_data.gd repair-shop-game/tests/run_tests.gd
git commit -m "feat: unlock rules data (.tres) + build tool + validation test"
```

---

### Task 4: WorkspaceUpgrade + `try_upgrade` validate-before-mutate + `.tres`

**Files:**
- Create: `repair-shop-game/scripts/progression/workspace_upgrade.gd`
- Create: `repair-shop-game/scripts/progression/workspace_upgrades.gd`
- Create: `repair-shop-game/scripts/progression/workspace_upgrade_set.gd`
- Create: `repair-shop-game/data/workspace_upgrades.tres` (sinh bởi tool)
- Modify: `repair-shop-game/tools/build_progression.gd` (append phần sinh upgrades)
- Test: `repair-shop-game/tests/test_workspace_upgrade.gd`

**Interfaces:**
- Consumes: `UnlockContext`, input names của core (Task 1), GameState fields (Task 1).
- Produces:
  - `WorkspaceUpgrade` Resource: `to_tier: int, cost: int, uy_tin_req: int, condition: String = ""`
  - `WorkspaceUpgrades` extends RefCounted: `static func try_upgrade(game_state: Node, defs: Array) -> String`
  - `res://data/workspace_upgrades.tres` (2 defs) — 4b dùng khi render nút mua.

- [ ] **Step 1: Viết test RED `tests/test_workspace_upgrade.gd`**

```gdscript
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
```

- [ ] **Step 2: Chạy — verify RED**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_workspace_upgrade.gd`
Expected: `FAIL load:` (chưa có WorkspaceUpgrade)

- [ ] **Step 3: Implement 2 script + tool part + sinh `.tres`**

- `workspace_upgrade.gd`: Resource 4 field đúng interface (`condition: String = ""`).
- `workspace_upgrades.gd`: `static func try_upgrade(gs: Node, defs: Array) -> String`:
  1. `var tier := int(gs.get("workspace_tier"))`; tìm `d` trong defs có `int(d.to_tier) == tier + 1`; không có → `"max_tier"`.
  2. `int(gs.get("money")) < int(d.cost)` → `"no_money"`; `int(gs.get("uy_tin")) < int(d.uy_tin_req)` → `"low_uy_tin"`.
  3. `d.condition != ""` → `Expression.parse(d.condition, INPUT_NAMES)` (lấy `INPUT_NAMES` từ `UnlockCore`); parse fail → `"condition"`; execute với inputs snapshot + `UnlockContext` (copy `gs.get("completed_projects")` nếu `is Array`), `show_error=false`; kết quả ≠ `true` → `"condition"`.
  4. Pass → `gs.set("money", int(gs.get("money")) - int(d.cost))`, `gs.set("workspace_tier", int(d.to_tier))`, return `""`.
  - **Không mutate gì trước bước 4.** `gs.get` null-safe (`_int` helper với null→0).
- `build_progression.gd`: append — dựng `WorkspaceUpgrade` 2 defs (1_000_000/40; 5_000_000/120; condition `""`) → container `WorkspaceUpgradeSet` (file `workspace_upgrade_set.gd`: `class_name WorkspaceUpgradeSet extends Resource`, `@export var defs: Array[WorkspaceUpgrade] = []` — GDScript chỉ 1 class_name/file nên tách riêng) → `ResourceSaver.save(..., "res://data/workspace_upgrades.tres")`.
- Chạy tool: `godot --headless --path repair-shop-game -s res://tools/build_progression.gd`

- [ ] **Step 4: Chạy — verify GREEN**

Run: `godot --headless --path repair-shop-game --import >/dev/null 2>&1 && godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_workspace_upgrade.gd`
Expected: `FAILURES=0`

- [ ] **Step 5: Đăng ký + gate gộp**

Thêm `"res://tests/test_workspace_upgrade.gd",` vào `run_tests.gd`; `bash repair-shop-game/tests/run_suite.sh` → `TOTAL_FAILURES=0` + `GATE PASS`, không `SCRIPT ERROR`

- [ ] **Step 6: Commit**

```bash
git add repair-shop-game/scripts/progression/ repair-shop-game/tools/build_progression.gd repair-shop-game/data/workspace_upgrades.tres repair-shop-game/tests/test_workspace_upgrade.gd repair-shop-game/tests/run_tests.gd
git commit -m "feat: workspace upgrade backend (validate-before-mutate) + data"
```
