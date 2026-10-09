# Workplace Screen (Spec 4b) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Màn hình Chỗ làm — backdrop theo tier, panel nâng cấp (tiền + uy tín), goal tracker (milestone % + danh sách khách), mở từ nút HUD.

**Architecture:** 1 scene `workplace_screen.tscn` (CanvasLayer, code-built UI theo pattern `schedule_screen.gd`) load động khi bấm nút HUD — không sửa `main.tscn`/`game_state.gd`. `UnlockCore` scene-local: setup từ `data/unlock_rules.tres`, refresh khi mở/sau upgrade, nghe `unlock_changed` để cập nhật tracker. Nâng cấp gọi thẳng `WorkspaceUpgrades.try_upgrade` (đã có từ 4a, validate-before-mutate).

**Tech Stack:** Godot 4.7.2 headless, GDScript, Resource `.tres`, test harness `tests/test_case.gd` (`check`/`check_eq`/`check_near`).

**Spec:** `docs/superpowers/specs/2026-10-09-workplace-screen-design.md`

## Global Constraints

- Gate: `bash repair-shop-game/tests/run_suite.sh` → `TOTAL_FAILURES=0` + `GATE PASS`. **FALSE GREEN:** `FAILURES=0` nhưng có dòng `SCRIPT ERROR` = test run bị abort giữa chừng → tính là FAIL, phải sửa.
- Single test: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/<test>.gd`
- Regen data: `godot --headless --path repair-shop-game -s res://tools/build_progression.gd` (in `save err=0`).
- Chuỗi UI tiếng Việt đúng spec §3: `"Chưa đủ tiền"`, `"Uy tín còn thấp"`, `"Điều kiện chưa đạt"`, `"Đã là tiệm rồi"`, `"Đã mở chỗ làm mới!"`; tên tier `"Bàn học"`, `"Phòng"`, `"Tiệm"`.
- **KHÔNG sửa:** `game_state.gd`, `main.tscn`, `unlock_core.gd`, `workspace_upgrades.gd` (session khác đang hoạt động trên các file này / đã ổn định).
- `tests/run_tests.gd`: append file test mới **sau entry cuối cùng hiện tại** (session khác cũng thêm test — anchor giữa file từng gây false-green ở 4a).
- Môi trường: đường dẫn working dir có ký tự unicode → mọi tạo/sửa file làm qua `python3` heredoc trong `bash` (file tool fail với path này).
- Script UI không có `class_name` (theo `schedule_screen.gd`), UI build bằng `_build_ui()` trong code.
- Gán giá trị vào `Array[T]` typed phải qua biến typed temp (bài học 4a — literal untyped = SCRIPT ERROR).
- Mỗi task: RED (test fail đúng lý do) → implement → GREEN (test pass, không `SCRIPT ERROR`) → commit. Task-done chạy gate.

## Review Focus

Những input/điều kiện spec ngầm định nhưng không task nào tự nhiên phủ — mỗi dòng có test trong task sở hữu:

1. **Upgrade fail qua UI không được mutate gì** (spec §3.3 — trừ tiền trước khi check = mất tiền thật): Task 3 test `fail: money giu nguyen` / `fail: tier giu nguyen` + toast đúng reason (cả nhánh `low_uy_tin` không trừ tiền).
2. **`unlock_changed` cập nhật ô NGAY khi scene đang mở** (spec §3.4 — nâng tier làm `khach_phong_tin` mở khoá, không cần mở lại màn): Task 4 test `unlock_changed -> row sang NGAY` (uy_tin 90, tier 0→1 → row `hoai_niem` sáng + milestone ✓).
3. **% milestone của rule nhiều điều kiện = min các tỉ số** (spec §2.1 — sai công thức = % dương ngụy, người chơi thấy 100% nhưng chưa mở): Task 4 test `min(45/90, 1/1) = 50%` + `32/50 -> 64%` + `khong pattern -> -1`.
4. **`customer.unlock_rule` trỏ id không tồn tại** (spec §4 — khách khoá im lặng mãi mãi, không warning): Task 2 test `unlock_rule khop rule id` (null-safe loop) + 3 assert map cụ thể.
5. **Mở lại sau khi state đổi phải đọc GameState mới** (spec §3.5 — cache cũ = backdrop/label lạc hậu sau nâng cấp ở lần mở trước): Task 5 test `mo lai -> doc tier moi` (tier set = 2 sau khi đóng, mở lại → `TierLabel` = "Tiệm").

---

### Task 1: UnlockRule.label + regen unlock_rules.tres

**Files:**
- Modify: `repair-shop-game/scripts/progression/unlock_rule.gd` (thêm field)
- Modify: `repair-shop-game/tools/build_progression.gd` (gán nhãn 4 rule)
- Modify: `repair-shop-game/data/unlock_rules.tres` (regen bằng tool)
- Modify: `repair-shop-game/tests/test_unlock_data.gd` (append block cuối `run()`)

**Interfaces:**
- Consumes: `UnlockRule` (`id/target_kind/target_id/condition/enabled` đã có), tool `build_progression.gd` (`_rule(id, kind, cond)` → sẽ thêm tham số).
- Produces: `UnlockRule.label: String` — Task 4 dùng để hiện tên rule trong tracker (`r.label`).

- [ ] **Step 1: Viết test FAIL (append cuối `run()` trong `test_unlock_data.gd`)**

```gdscript
	# label cua moi rule (spec §2.1: milestone hien ten rule)
	var expected_labels := {
		"may_co": "Máy cổ",
		"may_phuc_tap": "Máy phức tạp",
		"khach_giao_vien": "Khách giáo viên",
		"khach_phong_tin": "Khách phòng tin",
	}
	for r in set.rules:
		check_eq(r.get("label"), expected_labels.get(String(r.id)), "label %s" % r.id)
```

- [ ] **Step 2: Chạy verify FAIL**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_unlock_data.gd`
Expected: `FAILURES>=1` (r.get("label") = null ≠ "Máy cổ"…), **không** `SCRIPT ERROR` (dùng `get()` động nên field thiếu không abort).

- [ ] **Step 3: Implement**

- `unlock_rule.gd`: thêm `@export var label: String = ""` (sau `enabled`).
- `build_progression.gd`: `_rule(id: String, kind: String, cond: String, label: String)` — set thêm `r.label = label`; 4 call site: `"may_co"→"Máy cổ"`, `"may_phuc_tap"→"Máy phức tạp"`, `"khach_giao_vien"→"Khách giáo viên"`, `"khach_phong_tin"→"Khách phòng tin"` (giữ nguyên id/kind/cond hiện tại).
- Chạy regen: `godot --headless --path repair-shop-game -s res://tools/build_progression.gd` → expect `unlock_rules.tres save err=0` và `workspace_upgrades.tres save err=0` (file thứ 2 viết lại byte-identical).

- [ ] **Step 4: Chạy verify PASS**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_unlock_data.gd`
Expected: `FAILURES=0`, không `SCRIPT ERROR`. (Các test 4a trong file này phải tiếp tục pass — label là field additive.)

- [ ] **Step 5: Commit**

```bash
git add repair-shop-game/scripts/progression/unlock_rule.gd repair-shop-game/tools/build_progression.gd repair-shop-game/data/unlock_rules.tres repair-shop-game/tests/test_unlock_data.gd
git commit -m "feat: UnlockRule.label + regen unlock rules data"
```

---

### Task 2: CustomerDef.unlock_rule + data 3 khách + cross-validation

**Files:**
- Modify: `repair-shop-game/scripts/customer_def.gd` (thêm field)
- Modify: `repair-shop-game/data/customers/ban_hoc.tres`, `giao_vien.tres`, `hoai_niem.tres` (+1 dòng cuối section `[resource]`)
- Modify: `repair-shop-game/tests/test_unlock_data.gd` (append block cuối `run()`)

**Interfaces:**
- Consumes: `UnlockRule.id` (Task 1), `UnlockRuleSet.rules` (test `set` đang có sẵn trong file).
- Produces: `CustomerDef.unlock_rule: StringName = &""` — Task 4 dùng `String(c.unlock_rule)` để gate hàng trong tracker; `&""` = khách luôn thấy.

- [ ] **Step 1: Viết test FAIL (append cuối `run()` trong `test_unlock_data.gd`)**

```gdscript
	# catalog hook: moi unlock_rule id phai khop id trong rules (spec §4)
	var ids: Array = []
	for r in set.rules:
		ids.append(String(r.id))
	check_eq(load("res://data/customers/ban_hoc.tres").get("unlock_rule"), &"", "ban_hoc khong gate")
	check_eq(load("res://data/customers/giao_vien.tres").get("unlock_rule"), &"khach_giao_vien", "giao_vien map rule")
	check_eq(load("res://data/customers/hoai_niem.tres").get("unlock_rule"), &"khach_phong_tin", "hoai_niem map rule")
	for f in ["ban_hoc", "giao_vien", "hoai_niem"]:
		var ur = load("res://data/customers/%s.tres" % f).get("unlock_rule")
		if ur != null and String(ur) != "":
			check(ids.has(String(ur)), "%s unlock_rule khop rule id" % f)
```

- [ ] **Step 2: Chạy verify FAIL**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_unlock_data.gd`
Expected: `FAILURES>=3` (null ≠ expected ở 3 assert map), không `SCRIPT ERROR`; loop null-safe nên không abort.

- [ ] **Step 3: Implement**

- `customer_def.gd`: thêm `@export var unlock_rule: StringName = &""`.
- 3 file `.tres`: append 1 dòng sau property cuối của section `[resource]`:
  - `ban_hoc.tres`: `unlock_rule = &""`
  - `giao_vien.tres`: `unlock_rule = &"khach_giao_vien"`
  - `hoai_niem.tres`: `unlock_rule = &"khach_phong_tin"`

- [ ] **Step 4: Chạy verify PASS**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_unlock_data.gd`
Expected: `FAILURES=0`, không `SCRIPT ERROR`.

- [ ] **Step 5: Commit**

```bash
git add repair-shop-game/scripts/customer_def.gd repair-shop-game/data/customers/ban_hoc.tres repair-shop-game/data/customers/giao_vien.tres repair-shop-game/data/customers/hoai_niem.tres repair-shop-game/tests/test_unlock_data.gd
git commit -m "feat: CustomerDef.unlock_rule gate field + customer data"
```

---

### Task 3: workplace_screen scene — backdrop 3 tier + upgrade panel + toast

**Files:**
- Create: `repair-shop-game/scenes/ui/workplace_screen.tscn`
- Create: `repair-shop-game/scripts/ui/workplace_screen.gd`
- Create: `repair-shop-game/tests/test_workplace_screen.gd`
- Modify: `repair-shop-game/tests/run_tests.gd` (append `res://tests/test_workplace_screen.gd` sau entry cuối)

**Interfaces:**
- Consumes: `WorkspaceUpgrades.try_upgrade(game_state: Node, defs: Array) -> String` (reason keys `max_tier/no_money/low_uy_tin/condition`, `""` = thành công); `load("res://data/workspace_upgrades.tres").defs` → `Array[WorkspaceUpgrade]` (`to_tier/cost/uy_tin_req/condition`).
- Produces (Task 4/5 dựa vào):
  - Scene root `WorkplaceScreen` (CanvasLayer) + script `workplace_screen.gd`: `setup(gs: Node) -> void`, `refresh() -> void`, node paths `Root/Backdrop/Tier0|Tier1|Tier2`, `Root/UpgradePanel/{TierLabel,NextLabel,UpgradeBtn}`, `Root/Toast`.
  - Task 4 thêm: `_core`, `Root/Tracker/...`, `static func progress_percent(condition: String, values: Dictionary) -> float`.
  - Task 5 thêm: `close() -> void`, `_unhandled_input`.

- [ ] **Step 1: Viết test FAIL (tạo `tests/test_workplace_screen.gd` + đăng ký trong `run_tests.gd`)**

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var packed = load("res://scenes/ui/workplace_screen.tscn") as PackedScene
	check(packed != null, "workplace_screen.tscn loads")
	if packed == null:
		return
	var gs_script = load("res://scripts/autoload/game_state.gd")

	# backdrop theo tier + clamp 0..2 (spec §4)
	for t in [0, 1, 2, 9]:
		var scr = packed.instantiate()
		var gs = gs_script.new()
		gs.workspace_tier = t
		scr.setup(gs)
		var expect := mini(t, 2)
		for i in range(3):
			var tn = scr.get_node("Root/Backdrop/Tier%d" % i)
			check_eq(tn.visible, i == expect, "tier %d -> preset %d visible=%s" % [t, i, i == expect])
		scr.free()

	# Review Focus 1: upgrade fail khong mutate + toast ly do (spec §3.3)
	var scr2 = packed.instantiate()
	var gs2 = gs_script.new()  # money 50000 < 1.000.000
	scr2.setup(gs2)
	scr2.get_node("Root/UpgradePanel/UpgradeBtn").pressed.emit()
	check_eq(gs2.money, 50000, "fail: money giu nguyen")
	check_eq(gs2.workspace_tier, 0, "fail: tier giu nguyen")
	check_eq(String(scr2.get_node("Root/Toast").text), "Chưa đủ tiền", "toast no_money")

	gs2.money = 2000000  # tien du, uy_tin 0 < 40
	scr2.get_node("Root/UpgradePanel/UpgradeBtn").pressed.emit()
	check_eq(gs2.money, 2000000, "low_uy_tin: khong tru tien")
	check_eq(gs2.workspace_tier, 0, "low_uy_tin: tier giu")
	check_eq(String(scr2.get_node("Root/Toast").text), "Uy tín còn thấp", "toast low_uy_tin")

	# upgrade success (spec §3.2)
	gs2.uy_tin = 50
	scr2.get_node("Root/UpgradePanel/UpgradeBtn").pressed.emit()
	check_eq(gs2.workspace_tier, 1, "success: tier 1")
	check_eq(gs2.money, 1000000, "success: tru dung 1.000.000")
	check(scr2.get_node("Root/Backdrop/Tier1").visible, "backdrop doi ngay")
	check(scr2.get_node("Root/Backdrop/Tier0").visible == false, "Tier0 an di")
	check(String(scr2.get_node("Root/Toast").text).contains("Đã mở"), "toast success")
	check_eq(String(scr2.get_node("Root/UpgradePanel/TierLabel").text), "CHỖ LÀM: Phòng", "TierLabel = Phong")

	# tier 2: nut tat, khong con def
	gs2.workspace_tier = 2
	scr2.refresh()
	check_eq(scr2.get_node("Root/UpgradePanel/UpgradeBtn").disabled, true, "tier2: nut tat")

	# spec §4: thieu .tres -> message + nut tat; setup(null) khong crash
	scr2._upgrade_defs.clear()
	scr2.refresh()
	check_eq(String(scr2.get_node("Root/UpgradePanel/NextLabel").text), "Thiếu dữ liệu progression", "thieu data -> canh bao")
	check_eq(scr2.get_node("Root/UpgradePanel/UpgradeBtn").disabled, true, "thieu data -> nut tat")
	var scrN = packed.instantiate()
	scrN.setup(null)
	check(scrN != null, "setup(null) khong crash")
	scrN.free()
	scr2.free()
```

`run_tests.gd`: append `res://tests/test_workplace_screen.gd` **sau entry cuối cùng** của danh sách case.

- [ ] **Step 2: Chạy verify FAIL**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_workplace_screen.gd`
Expected: FAIL `workplace_screen.tscn loads` (file chưa tồn tại), test return sớm — không `SCRIPT ERROR`.

- [ ] **Step 3: Implement scene + script**

`scenes/ui/workplace_screen.tscn` (mirror `schedule_screen.tscn`):

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/workplace_screen.gd" id="1"]

[node name="WorkplaceScreen" type="CanvasLayer"]
script = ExtResource("1")
```

`scripts/ui/workplace_screen.gd` — quyết định thiết kế (test đã pin đường node, phần thân tự viết theo pattern `schedule_screen.gd`):

```gdscript
extends CanvasLayer

const UPGRADES_PATH := "res://data/workspace_upgrades.tres"
const TIER_NAMES := ["Bàn học", "Phòng", "Tiệm"]
const REASON_TEXT := {
	"no_money": "Chưa đủ tiền",
	"low_uy_tin": "Uy tín còn thấp",
	"condition": "Điều kiện chưa đạt",
	"max_tier": "Đã là tiệm rồi",
}

var game_state
var _built := false
var _upgrade_defs: Array = []
var _core  # UnlockCore — Task 4 mới khởi tạo

func _ready() -> void: ...        # auto-setup từ /root/GameState nếu game_state == null (pattern schedule_screen)
func setup(gs: Node) -> void: ... # load UPGRADES_PATH -> _upgrade_defs; _build_ui() 1 lần; refresh()
func refresh() -> void: ...       # Task 3: backdrop + TierLabel + NextLabel/UpgradeBtn (Task 4 thêm tracker + _core.refresh)
func _build_ui() -> void: ...
func _on_upgrade_pressed() -> void: ...
func _toast(msg: String) -> void: ...
static func _vn(n: int) -> String: ...   # "1000000" -> "1.000.000"
```

Cây node `_build_ui()` (root Control FULL_RECT, `mouse_filter = MOUSE_FILTER_STOP`):

```
Root (Control)
├─ Backdrop (Control)
│   ├─ Tier0 (Control, visible theo tier)  → ColorRect "Desk" + ColorRect "Lamp"
│   ├─ Tier1 (Control)                    → + ColorRect "Shelf" + ColorRect "Socket"
│   └─ Tier2 (Control)                    → + ColorRect "Sign" + ColorRect "Counter"
├─ UpgradePanel (Control, góc dưới-trái ~ (40, 430))
│   ├─ TierLabel (Label)   # "CHỖ LÀM: Bàn học" / "Phòng" / "Tiệm"
│   ├─ NextLabel (Label)   # "→ Phòng · 1.000.000đ · uy tín 40" | "Đã lên cấp cao nhất"
│   └─ UpgradeBtn (Button) # "NÂNG CẤP"
└─ Toast (Label, visible = false, vị trí trên-giữa)
```

Hành vi `refresh()`:
- `var tier := clampi(int(game_state.workspace_tier), 0, 2)` → `Tier<i>.visible = (i == tier)` (clamp test tier 9).
- `TierLabel.text = "CHỖ LÀM: " + TIER_NAMES[tier]`.
- Tìm `def` trong `_upgrade_defs` có `to_tier == tier + 1`: có → `NextLabel.text = "→ %s · %sđ · uy tín %d" % [TIER_NAMES[def.to_tier], _vn(def.cost), def.uy_tin_req]`, `UpgradeBtn.disabled = false`; không → `NextLabel.text = "Đã lên cấp cao nhất"`, `UpgradeBtn.disabled = true`.
- `_upgrade_defs` rỗng (`.tres` load lỗi, spec §4): `NextLabel.text = "Thiếu dữ liệu progression"`, `UpgradeBtn.disabled = true`.

`_on_upgrade_pressed()`:
- `var reason := WorkspaceUpgrades.try_upgrade(game_state, _upgrade_defs)`
- `reason == ""` → `_toast("Đã mở chỗ làm mới!")` → `refresh()` (backdrop + labels đổi ngay).
- khác → `_toast(REASON_TEXT.get(reason, reason))`. **Không tự mutate state** — mọi mutate nằm trong `try_upgrade` (validate-before-mutate của 4a).

`_toast(msg)`: set `text` + `visible = true`; chỉ hẹn ẩn sau 1.5s khi `is_inside_tree()` (test gọi ngoài tree → timer không chạy, text giữ nguyên để assert).

- [ ] **Step 4: Chạy verify PASS**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_workplace_screen.gd`
Expected: `FAILURES=0`, không `SCRIPT ERROR`.

- [ ] **Step 5: Commit**

```bash
git add repair-shop-game/scenes/ui/workplace_screen.tscn repair-shop-game/scripts/ui/workplace_screen.gd repair-shop-game/tests/test_workplace_screen.gd repair-shop-game/tests/run_tests.gd
git commit -m "feat: workplace screen backdrop + upgrade panel + toast"
```

---

### Task 4: Goal tracker — milestone % + customer rows + unlock_changed

**Files:**
- Modify: `repair-shop-game/scripts/ui/workplace_screen.gd` (thêm core + tracker + `progress_percent`)
- Modify: `repair-shop-game/tests/test_workplace_screen.gd` (append block sau test cũ, cùng `run()`)

**Interfaces:**
- Consumes: `UnlockCore` — `setup(rules: Array)`, `refresh(game_state: Node)`, `is_unlocked(id: StringName) -> bool`, `parse_errors() -> Array[String]`, `signal unlock_changed(id: StringName)`, `const INPUT_NAMES` (`["money","knowledge","uy_tin","ky_luat","workspace_tier"]`); `UnlockRule.label` (Task 1); `CustomerDef.unlock_rule` + `CustomerCatalog.load_all()` (Task 2; đã sort `files.sort()` → thứ tự ban_hoc, giao_vien, hoai_niem).
- Produces:
  - `static func progress_percent(condition: String, values: Dictionary) -> float` — `values` key = tên input `INPUT_NAMES`; trả tỉ số `0.0..1.0` (min các phép `X >= N` khớp), `-1.0` nếu không có pattern nào khớp input hợp lệ.
  - Node: `Root/Tracker/{Milestones,Customers}` — mỗi row là Container **đặt tên theo id** (`may_co`, `khach_giao_vien`… / `ban_hoc`, `giao_vien`, `hoai_niem`); row milestone có con `MName/MPct/MMark`; row customer có con `CName/CNote`.
  - `_core` (UnlockCore instance, đã setup+refresh trong `setup()`), handler `_on_unlock_changed(id: StringName)`.
  - Task 5 không phụ thuộc chi tiết này.

- [ ] **Step 1: Viết test FAIL (append cùng `run()` trong `test_workplace_screen.gd`)**

```gdscript
	# tracker milestones (spec §2.1)
	var wsp_script = load("res://scripts/ui/workplace_screen.gd")
	var scr4 = packed.instantiate()
	var gs4 = gs_script.new()
	scr4.setup(gs4)
	var row_may = scr4.get_node("Root/Tracker/Milestones/may_co")
	check_eq(String(row_may.get_node("MName").text), "Máy cổ", "milestone label")
	check_eq(String(row_may.get_node("MMark").text), "", "knowledge 0 -> chua unlock")
	gs4.knowledge = 32
	scr4.refresh()
	check_eq(String(row_may.get_node("MPct").text), "64%", "pct 64% tai knowledge 32")
	gs4.knowledge = 100
	scr4.refresh()
	check_eq(String(scr4.get_node("Root/Tracker/Milestones/may_co/MMark").text), "✓", "knowledge 100 -> ✓")
	check_eq(scr4.get_node("Root/Tracker/Milestones").get_child_count(), 4, "4 milestone rows")

	# Review Focus 3: percent math (spec §2.1 min ratio)
	var vals := {"knowledge": 32, "uy_tin": 45, "workspace_tier": 1}
	check(absf(wsp_script.progress_percent("knowledge >= 50", vals) - 0.64) < 0.001, "32/50 -> 64%")
	check_near(wsp_script.progress_percent("uy_tin >= 90 and workspace_tier >= 1", vals), 0.5, 0.001, "min(45/90, 1/1) = 50%")
	check_eq(wsp_script.progress_percent("no_pattern_here", vals), -1.0, "khong pattern -> -1")

	# customers gate (spec §2.4 + Review Focus 4)
	check_eq(scr4.get_node("Root/Tracker/Customers").get_child_count(), 3, "3 customer rows")
	check(scr4.get_node("Root/Tracker/Customers/giao_vien").modulate.a < 1.0, "uy_tin 0 -> giao vien mo")
	gs4.uy_tin = 60
	scr4.refresh()
	check(scr4.get_node("Root/Tracker/Customers/giao_vien").modulate.a >= 1.0, "uy_tin 60 -> giao vien sang")
	check(scr4.get_node("Root/Tracker/Customers/hoai_niem").modulate.a < 1.0, "phong tin van mo (tier 0)")

	# Review Focus 2: tier up while open -> unlock NGAY qua unlock_changed (spec §3.4)
	gs4.uy_tin = 90
	gs4.money = 9000000
	gs4.workspace_tier = 0
	scr4.refresh()
	check(scr4.get_node("Root/Tracker/Customers/hoai_niem").modulate.a < 1.0, "truoc upgrade phong tin mo")
	scr4.get_node("Root/UpgradePanel/UpgradeBtn").pressed.emit()  # tier 0 -> 1 (uy_tin 90 >= 40)
	check_eq(gs4.workspace_tier, 1, "upgrade len tier 1")
	check(scr4.get_node("Root/Tracker/Customers/hoai_niem").modulate.a >= 1.0, "unlock_changed -> row sang NGAY")
	check_eq(String(scr4.get_node("Root/Tracker/Milestones/khach_phong_tin/MMark").text), "✓", "milestone ✓ ngay")
	check_eq(scr4.get_node("Root/Tracker/Warning").visible, false, "du lieu sach -> warning an")
	scr4.free()
```

- [ ] **Step 2: Chạy verify FAIL**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_workplace_screen.gd`
Expected: FAIL `Root/Tracker/Milestones/may_co` (node chưa có) → test abort tại lần get_node đầu (Node get_node lỗi Runtime → `SCRIPT ERROR` accept được ở bước này vì node thiếu là RED rõ ràng; nếu muốn RED sạch, step 1 viết guard `get_node_or_null` cho lần đầu — executor chọn cách sạch hơn nếu được).

- [ ] **Step 3: Implement**

Trong `workplace_screen.gd`:

1. **Core:** trong `setup()` sau `_build_ui()`: `_core = load("res://scripts/progression/unlock_core.gd").new()`; `_core.setup(load("res://data/unlock_rules.tres").rules)`; `_core.unlock_changed.connect(_on_unlock_changed)`; `_core.refresh(game_state)`. (Guard: `.tres` null → bỏ qua core, tracker hiện "Thiếu dữ liệu progression".)
2. **`_build_ui()` thêm nhánh `Root/Tracker`** (Control phải-trên ~ (700, 80)):
   - `Milestones` (VBoxContainer) — mỗi enabled rule 1 `HBoxContainer` **`name = String(rule.id)`** chứa `MName` (text `rule.label`), `MPct`, `MMark`.
   - `Customers` (VBoxContainer) — mỗi khách 1 `HBoxContainer` **`name = c.key`** chứa `CName` (text `c.display_name`), `CNote`.
3. **`refresh()` mở rộng (đầu hàm):**
   - Nếu `_core != null` → `_core.refresh(game_state)` (signal có thể gọi `_refresh_tracker()` trong lúc này — không recursion vì handler chỉ build lại tracker).
   - `_refresh_tracker()`: với mỗi enabled rule: `mark = "✓" nếu _core.is_unlocked(id) else ""`; `pp = progress_percent(rule.condition, values)` (values = dict `INPUT_NAMES → int(game_state.get(prop))`, null→0); `pct = "100%" nếu unlocked; pp < 0 → ""; ngược lại "%d%%" % int(round(pp*100))`.
   - Customer row: `unlock_rule == &""` → `modulate.a = 1.0`, `CNote.text = ""`; ngược lại `_core.is_unlocked(ur)` → `a = 1.0`, note `""`; chưa mở → `a = 0.4`, `CNote.text = "Chưa mở"`. Nếu `ur` khác rỗng nhưng không có trong ids của rules → `push_warning` (một lần khi vừa phát hiện) + coi như chưa mở (test data chặn trước nên nhánh này chỉ là fail-safe).
   - `Root/Tracker/Warning` (Label, đỏ, mặc định `visible = false`): `refresh()` cuối cùng — `var errs: Array = _core.parse_errors()`; `visible = not errs.is_empty()`; nếu khác rỗng → `text = String(errs[0])` + `push_warning` khi vừa chuyển từ rỗng → khác rỗng (không spam mỗi refresh).
4. **`_on_upgrade_pressed()` nhánh thành công:** thêm `_core?.refresh(game_state)` + `_refresh_tracker()` (nếu `_core != null`) — đây là đường UnlockCore biết tier mới.
5. **`static func progress_percent`:** regex `(\w+) >= (\d+)` (`RegEx.create_from_string`), mọi match có key ∈ `values` → `minf` của `clampf(value/threshold, 0, 1)`; không match hợp lệ nào → `-1.0`.
6. `_on_unlock_changed(_id)` → `_refresh_tracker()`.

- [ ] **Step 4: Chạy verify PASS**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_workplace_screen.gd`
Expected: `FAILURES=0`, không `SCRIPT ERROR` (bao gồm cả block Task 3 chạy lại).

- [ ] **Step 5: Commit**

```bash
git add repair-shop-game/scripts/ui/workplace_screen.gd repair-shop-game/tests/test_workplace_screen.gd
git commit -m "feat: goal tracker milestones + customer gate + live unlock_changed"
```

---

### Task 5: HUD entry (nút CHỖ LÀM) + đóng/mở lại (✕/Esc)

**Files:**
- Modify: `repair-shop-game/scripts/ui/hud.gd` (`_build_ui` +1 nút; + `var _workplace`; + `_toggle_workplace()`)
- Modify: `repair-shop-game/scripts/ui/workplace_screen.gd` (+ `close()`, `_unhandled_input` Esc, nút ✕ `CloseBtn`)
- Modify: `repair-shop-game/tests/test_workplace_screen.gd` (append block cuối cùng trong `run()`)

**Interfaces:**
- Consumes: Task 3 `setup(gs)/refresh()` + node `Root/UpgradePanel/TierLabel`; Task 4 xong (tracker đã hoạt động).
- Produces: HUD `Root/WorkplaceBtn` (Button, text `"CHỖ LÀM"`, position `(16, 56)`, size `(170, 40)`); `hud._toggle_workplace()` — có instance hợp lệ → `visible = not visible` + `refresh()` khi hiện; chưa có → instantiate → `setup(game_state)` → `get_parent().add_child(...)`. Screen: `close()` → `visible = false`.

- [ ] **Step 1: Viết test FAIL (append cuối `run()` trong `test_workplace_screen.gd`)**

```gdscript
	# HUD entry + dong/mo lai doc state moi (spec §3.1/§3.5 + Review Focus 5)
	var hud_script = load("res://scripts/ui/hud.gd")
	var host := Node.new()
	var hud = hud_script.new()
	host.add_child(hud)
	var gs5 = gs_script.new()
	hud.setup(gs5)
	var btn = hud.get_node_or_null("Root/WorkplaceBtn")
	check(btn != null, "HUD co nut CHỖ LÀM")
	if btn == null:
		host.free()
		return
	btn.pressed.emit()
	var wp = host.get_node_or_null("WorkplaceScreen")
	check(wp != null, "click -> scene instance under parent")
	if wp == null:
		host.free()
		return
	check(wp.visible, "moi instance -> visible")

	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	wp._unhandled_input(ev)
	check(not wp.visible, "Esc -> an")

	# Review Focus 5: mo lai doc GameState moi (tier doi trong luc dang dong)
	gs5.workspace_tier = 2
	btn.pressed.emit()
	check(wp.visible, "nhan nut -> hien lai")
	check_eq(String(wp.get_node("Root/UpgradePanel/TierLabel").text), "CHỖ LÀM: Tiệm", "mo lai -> doc tier moi")
	ev.pressed = true
	wp._unhandled_input(ev)
	check(not wp.visible, "Esc 2 -> an (khong tao instance moi)")
	host.free()
```

- [ ] **Step 2: Chạy verify FAIL**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_workplace_screen.gd`
Expected: FAIL `HUD co nut CHỖ LÀM` (nút chưa có) + return sớm.

- [ ] **Step 3: Implement**

`hud.gd`:
- `var _workplace` (CanvasLayer instance, null ban đầu).
- Trong `_build_ui()` sau `TimeLabel`: `Button` name `WorkplaceBtn`, text `"CHỖ LÀM"`, `position = Vector2(16, 56)`, `size = Vector2(170, 40)`, `pressed.connect(_toggle_workplace)`.
- `func _toggle_workplace()` như Interfaces block. Nạp scene: `load("res://scenes/ui/workplace_screen.tscn")`; guard `packed == null or game_state == null` → return.

`workplace_screen.gd`:
- `_build_ui()` thêm `CloseBtn` (Button "✕", góc trên-phải của `Root`) → `pressed.connect(close)`.
- `func close() -> void: visible = false` (ẩn — giữ instance, spec §3.5).
- `func _unhandled_input(event)` pattern `schedule_screen.gd` (bỏ qua `echo`/`release`) với `KEY_ESCAPE` → `close()`.

- [ ] **Step 4: Chạy verify PASS**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_workplace_screen.gd`
Expected: `FAILURES=0`, không `SCRIPT ERROR`.

- [ ] **Step 5: Gate + Commit**

```bash
bash repair-shop-game/tests/run_suite.sh   # expect TOTAL_FAILURES=0 + GATE PASS + không SCRIPT ERROR
git add repair-shop-game/scripts/ui/hud.gd repair-shop-game/scripts/ui/workplace_screen.gd repair-shop-game/tests/test_workplace_screen.gd
git commit -m "feat: HUD workplace button + Esc/close + fresh reopen"
```
