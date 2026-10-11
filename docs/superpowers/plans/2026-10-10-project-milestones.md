# Project Milestones (Uy tín / Giới thiệu) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hoàn thành hook project (`complete_project:<id>`, `uy_tin:<n>`), thưởng uy tín theo activity, mở 2 khách mới qua milestone `project_count`, kèm toast + dòng SUMMARIZE.

**Architecture:** Mở rộng `HookRunner` whitelist (cycle 2) thêm 2 key; state thêm `project_count` làm input của `UnlockCore` (Expression đọc thẳng field); data 3 hook + 2 rule regen qua builder; feedback UI tái dùng toast/SUMMARIZE pattern cycle 2.

**Tech Stack:** Godot 4 (GDScript), test harness `run_suite.sh`/`run_one.gd`/`test_case.gd`, builder SceneTree scripts regen `.tres`.

**Spec:** `docs/superpowers/specs/2026-10-10-project-milestones-design.md`

## Global Constraints

- Branch: `feat/project-milestones` cắt từ `feat/schedule-engine` @ `76cdafd`.
- Exact strings (test assert đúng chuỗi): toast `Hoàn thành project! +%d uy_tin`; SUMMARIZE `Project hoàn thành: +%d uy_tin`; `Tri thức nhận` (cycle 2) giữ nguyên.
- `uy_tin` award là **flat** (không nhân consumed/phút); `complete_project` count +1 mỗi lần apply bất kể consumed.
- `project_count` / `completed_projects` KHÔNG bị `begin_new_day()` reset.
- `UnlockCore.INPUT_NAMES`: chỉ **append** `"project_count"` cuối mảng (không đổi thứ tự 5 phần tử cũ).
- Regen data chỉ qua builder (không edit tay `.tres`): `godot --headless --path repair-shop-game -s res://tools/build_week_schedule.gd` và `godot --headless --path repair-shop-game -s res://tools/build_progression.gd`.
- Gate mỗi commit: `bash repair-shop-game/tests/run_suite.sh` → mọi FAIL/SCRIPT ERROR phải **chỉ** từ `test_outfit.gd` (WIP của user, baseline — không thuộc scope) + smoke `godot --headless --path repair-shop-game --quit-after 60 res://scenes/main.tscn` không có SCRIPT ERROR mới → `GATE PASS` (ghi ledger).
- Commit từng task, `git add` **tên file cụ thể**, KHÔNG stage file dirty của user: `scenes/cafe.tscn`, `scripts/animation_controller.gd`, `scripts/animation_setup.gd`, `chibi-model/generate_chibi.py`, entry `test_outfit.gd` trong `run_tests.gd`.
- File `.gd` mới: chạy test 1 lần để Godot sinh `.uid` rồi commit kèm.
- Test mới register **cuối** `TEST_SCRIPTS` trong `run_tests.gd` (sau `test_chibi_school.gd`).

## Review Focus

1. **Award flat khi consumed bị clamp** — `try_activity` ở phút 1310 clamp consumed về 10 phút; kỳ vọng `uy_tin` vẫn +10, `project_count` vẫn +1 (không scale). → Task 3: `test_activities.gd` block `lam_project` assert `gains.uy_tin == 10`, `project_count == 1`.
2. **Trùng id** — apply `complete_project:p_x` hai lần; kỳ vọng `project_count == 2` nhưng `completed_projects.size() == 1`. → Task 1: `test_project_hook.gd` assert đủ 2 vế.
3. **Pair hỏng trong hook nhiều key** — `uy_tin:-5` / `uy_tin:abc` / `complete_project:p Bad` phải warn + bỏ qua pair đó, pair còn lại vẫn chạy. → Task 1: `test_project_hook.gd` bad-pair section + combo assertion.
4. **INPUT_NAMES mảng mới dài hơn** — 6 rule parse/execute OK trên context mặc định (`def_inputs` 6 giá trị), default state không unlock gì. → Task 2: `test_unlock_data.gd` (size 6 + def_inputs 6 + `unlocked_ids().size() == 0` giữ nguyên).
5. **Feedback giả** — activity không có project gains không được sinh toast/dòng summary. → Task 3: `test_day_end.gd` assert sau sleep summary KHÔNG chứa `Project hoàn thành`; Task 4: pin `mo_panel` toast rỗng (đã có sẵn, giữ nguyên khi sửa `_on_activity`).

---

### Task 1: State `project_count` + HookRunner 2 key mới

**Files:**
- Modify: `repair-shop-game/scripts/autoload/game_state.gd` (sau `knowledge_remainder`)
- Modify: `repair-shop-game/scripts/data/hook_runner.gd`
- Create: `repair-shop-game/tests/test_project_hook.gd` (+`.uid` tự sinh)
- Modify: `repair-shop-game/tests/run_tests.gd` (register cuối `TEST_SCRIPTS`)

**Interfaces:**
- Consumes: `HookRunner.apply(gs: Node, hook: String, consumed: int) -> Dictionary` (không đổi chữ ký); `gs.completed_projects: Array[StringName]` (spec 4a, đã có).
- Produces: `gs.project_count: int`; `apply()` trả gains có thể chứa key `"project"` (String id) và `"uy_tin"` (int, >0). `UnlockCore.INPUT_NAMES` vẫn 5 phần tử ở task này (append `"project_count"` ở Task 2 cùng lúc amend `def_inputs` — tránh làm `test_unlock_data` fail sớm).

- [ ] **Step 1: Viết test FAIL `test_project_hook.gd`** + register vào `run_tests.gd`

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var hr = load("res://scripts/data/hook_runner.gd")
	check(hr != null, "hook_runner loads")
	if hr == null:
		return
	var gs = load("res://scripts/autoload/game_state.gd").new()

	# count + append id
	var g = hr.apply(gs, "complete_project:p_x", 10)
	check_eq(int(gs.project_count), 1, "count 1")
	check_eq(gs.completed_projects.size(), 1, "1 id")
	check_eq(String(g.get("project", "")), "p_x", "gains project")

	# trung id: count tiep tuc, khong append trung (RF2)
	g = hr.apply(gs, "complete_project:p_x", 10)
	check_eq(int(gs.project_count), 2, "count 2")
	check_eq(gs.completed_projects.size(), 1, "khong trung id")

	# uy_tin cong + clamp 100
	gs.uy_tin = 95
	g = hr.apply(gs, "uy_tin:8", 0)
	check_eq(int(gs.uy_tin), 100, "clamp 100")
	check_eq(int(g.get("uy_tin", 0)), 8, "gains uy_tin")
	gs.uy_tin = 10
	hr.apply(gs, "uy_tin:8", 0)
	check_eq(int(gs.uy_tin), 18, "uy_tin cong binh thuong")

	# pair hong: warn + bo qua, khong count/khong doi state (RF3)
	check_eq(hr.apply(gs, "complete_project:", 0).size(), 0, "id rong -> bo qua")
	check_eq(int(gs.project_count), 2, "id rong khong count")
	check_eq(hr.apply(gs, "complete_project:P Bad", 0).size(), 0, "id sai pattern -> bo qua")
	check_eq(int(gs.project_count), 2, "sai pattern khong count")
	hr.apply(gs, "uy_tin:-5", 0)
	check_eq(int(gs.uy_tin), 18, "uy_tin am bo qua")
	hr.apply(gs, "uy_tin:abc", 0)
	check_eq(int(gs.uy_tin), 18, "uy_tin khong phai int bo qua")

	# knowledge_rate khong regression
	g = hr.apply(gs, "knowledge_rate:0.020", 120)
	check_eq(int(gs.knowledge), 2, "knowledge_rate van chay")

	# combo: 2 pair cung hook
	gs.uy_tin = 50
	g = hr.apply(gs, "complete_project:p_y,uy_tin:6", 0)
	check_eq(int(gs.project_count), 3, "combo count")
	check_eq(int(gs.uy_tin), 56, "combo uy_tin")
	check_eq(String(g.get("project", "")), "p_y", "combo gains project")
	check_eq(int(g.get("uy_tin", 0)), 6, "combo gains uy_tin")
```

Register: thêm `"res://tests/test_project_hook.gd",` sau dòng `"res://tests/test_chibi_school.gd",`.

- [ ] **Step 2: Chạy RED**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_project_hook.gd`
Expected: FAIL (thiếu `project_count` / gains không có key) — FAILURE > 0.

- [ ] **Step 3: Implement**

`game_state.gd`: thêm `var project_count: int = 0` ngay sau `var knowledge_remainder: float = 0.0`. Không sửa `begin_new_day`.

`hook_runner.gd`: `const WHITELIST := ["knowledge_rate", "complete_project", "uy_tin"]`. Giữ nguyên phần validate format pair + whitelist. Chuyển validate value + apply vào nhánh per-key (match key):
- `knowledge_rate`: code hiện tại giữ nguyên 100% (is_valid_float, rate < 0 warn, remainder, gains `knowledge`).
- `complete_project`: value rỗng hoặc không khớp RegEx `^[a-z0-9_]+$` (tạo bằng `RegEx.create_from_string`) → `push_warning` + `continue`; `gs.project_count = int(gs.project_count) + 1`; `if not gs.completed_projects.has(StringName(id)): gs.completed_projects.append(StringName(id))`; `out["project"] = id`.
- `uy_tin`: `value.is_valid_int()` false hoặc `int(value) < 0` → warn + `continue`; `gs.uy_tin = clampi(int(gs.uy_tin) + int(value), 0, 100)`; `if n > 0: out["uy_tin"] = n`.

- [ ] **Step 4: Chạy PASS**

Run: Step 2 command → PASS (FAILURE=0).
Run: `bash repair-shop-game/tests/run_suite.sh` → mọi FAIL chỉ từ `test_outfit.gd` (baseline) → GATE PASS (ledger).
Run smoke (Global Constraints) → không SCRIPT ERROR mới.

- [ ] **Step 5: Commit**

```bash
git add repair-shop-game/scripts/autoload/game_state.gd repair-shop-game/scripts/data/hook_runner.gd repair-shop-game/tests/test_project_hook.gd repair-shop-game/tests/test_project_hook.gd.uid repair-shop-game/tests/run_tests.gd
git commit -m "feat: project/uy_tin hook keys + project_count state"
```

---

### Task 2: Data — 3 hook schedule, 2 milestone rule, 2 khách mới

**Files:**
- Modify: `repair-shop-game/scripts/progression/unlock_core.gd` (dòng 6 — append input name)
- Modify: `repair-shop-game/tools/build_week_schedule.gd` (3 tham số hook + validation whitelist)
- Regen: `repair-shop-game/data/week_schedule.tres`
- Modify: `repair-shop-game/tools/build_progression.gd` (append 2 `_rule`)
- Regen: `repair-shop-game/data/unlock_rules.tres`
- Create: `repair-shop-game/data/customers/truong_nhom.tres`, `repair-shop-game/data/customers/giam_doc.tres`
- Test amend: `test_activities_data.gd`, `test_unlock_data.gd`, `test_unlock_core.gd`, `test_customer_catalog.gd`, `test_workplace_screen.gd`

**Interfaces:**
- Consumes: Task 1 — `gs.project_count`.
- Produces: `UnlockCore.INPUT_NAMES` 6 phần tử (append cuối; workplace `values` dict + `progress_percent` tự đọc field, không sửa `workplace_screen.gd`); hook string data 3 activity; rule ids `khach_truong_nhom` (`project_count >= 1`), `khach_giam_doc` (`project_count >= 3`); customer keys `truong_nhom`/`giam_doc` với `unlock_rule` tương ứng. Task 4 dùng data này (nút `Btn_lam_project` có hook).

- [ ] **Step 1: Amend tests → RED**

`test_activities_data.gd` (dòng 31 đổi + thêm 2 dòng):
```gdscript
	check_eq(String(week.days[0].slots[4].activities[0].hook), "complete_project:p_noibo,uy_tin:10", "lam_project hook cycle3")
	check_eq(String(week.days[1].slots[3].activities[0].hook), "complete_project:p_som,uy_tin:6", "lam_project_som hook")
	check_eq(String(week.days[0].slots[1].activities[1].hook), "complete_project:p_cafe,uy_tin:8", "project_ca_phe hook")
```

`test_unlock_data.gd`:
- `check(set.rules.size() == 4, "4 rules")` → `== 6`, nhãn `"6 rules"`.
- mảng `for want in [...]` thêm `"khach_truong_nhom"`, `"khach_giam_doc"`.
- `var def_inputs: Array = [50000, 0, 0, 100, 0]` → append `0` (6 phần tử khớp 6 `INPUT_NAMES`).
- `expected_labels` thêm: `"khach_truong_nhom": "Trưởng nhóm"`, `"khach_giam_doc": "Giám đốc"`.
- Catalog hook: thêm 2 dòng check `unlock_rule` map đúng + mở rộng `for f in [...]` thêm `"truong_nhom"`, `"giam_doc"`.

`test_unlock_core.gd` — append cuối `run()` (state `gs` dùng chung, `project_count` đang 0):
```gdscript
	# milestone theo so lan hoan thanh project (cycle 3)
	var c10 = core_script.new()
	c10.setup([_rule("khach_truong_nhom", "project_count >= 1")])
	gs.project_count = 0
	c10.refresh(gs)
	check_eq(c10.is_unlocked("khach_truong_nhom"), false, "project_count 0 -> locked")
	gs.project_count = 1
	c10.refresh(gs)
	check_eq(c10.is_unlocked("khach_truong_nhom"), true, "project_count 1 -> unlocked")
```

`test_customer_catalog.gd`:
- `check_eq(all.size(), 3, "3 customer files")` → `5`, nhãn `"5 customer files"`; `check_eq(keys.size(), 3, ...)` → `5`.
- Mở rộng `for k in THREE` hoặc thêm 2 dòng: `check(keys.has("truong_nhom"), ...)` + `check(keys.has("giam_doc"), ...)`.
- Effects chốt: `truong_nhom` than `tip_percent == 15`, kho `lost_order == true`; `giam_doc` than `tip_percent == 20`, trung_tinh `tip_percent == 5`, kho `lost_order == true`.

`test_workplace_screen.gd`:
- dòng 81: `get_child_count(), 4, "4 milestone rows"` → `6`, `"6 milestone rows"`.
- dòng 90: `get_child_count(), 3, "3 customer rows"` → `5`, `"5 customer rows"`.

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_unlock_data.gd` (và các test amend khác) → RED (rule/catalog chưa có).

- [ ] **Step 2: Implement INPUT_NAMES + builder hooks + validation**

`unlock_core.gd` dòng 6: append cuối mảng — `const INPUT_NAMES := ["money", "knowledge", "uy_tin", "ky_luat", "workspace_tier", "project_count"]`. Không sửa logic refresh/parse (field int → `_int_field` đọc thẳng; bare Node fallback 0 đã có sẵn).

`build_week_schedule.gd` — 3 call `_act(...)` thêm hook:
- `_act("lam_project", "Làm project", "workshop", 180, "complete_project:p_noibo,uy_tin:10")`
- `_act("lam_project_som", "Làm project sớm", "workshop", 120, "complete_project:p_som,uy_tin:6")`
- `_act("project_ca_phe", "Project ở cà phê", "cafe", 135, "complete_project:p_cafe,uy_tin:8")`

Thay dòng validate `if key != "knowledge_rate" or ...` bằng per-key (match): `knowledge_rate` → float hợp lệ ≥ 0; `complete_project` → khớp RegEx `^[a-z0-9_]+$`; `uy_tin` → `is_valid_int()` và ≥ 0; sai → `push_error("build_week_schedule: hook khong hop le: ...")` + `quit(1)` + `return` (giữ nguyên nhánh format pair).

- [ ] **Step 3: Regen week_schedule**

Run: `godot --headless --path repair-shop-game -s res://tools/build_week_schedule.gd`
Expected: in `WROTE res://data/week_schedule.tres err=0`.

- [ ] **Step 4: Implement rules + 2 customer .tres**

`build_progression.gd` — append 2 dòng vào `set.rules`:
```gdscript
		_rule("khach_truong_nhom", "customer", "project_count >= 1", "Trưởng nhóm"),
		_rule("khach_giam_doc", "customer", "project_count >= 3", "Giám đốc"),
```

Tạo `truong_nhom.tres` (template `giao_vien.tres`, `load_steps=2 format=3`):
```
key = "truong_nhom"
display_name = "Trưởng nhóm"
reactions = {"than": "Sếp khen dự án này — để tôi giới thiệu đồng nghiệp nhé.", "trung_tinh": "Cảm ơn, dự án ổn.", "kho": "Việc thế này mà chậm là tôi chuyển đơn khác."}
effects = { "than": { "tip_percent": 15 }, "trung_tinh": {}, "kho": { "lost_order": true } }
risk_warning = "Trưởng nhóm giới thiệu việc — tone khô là mất mối quan hệ ngay."
unlock_rule = &"khach_truong_nhom"
```

Tạo `giam_doc.tres`:
```
key = "giam_doc"
display_name = "Giám đốc"
reactions = {"than": "Hoàn hảo. Hợp đồng dài hạn là của anh.", "trung_tinh": "Được rồi, tiếp tục.", "kho": "Chậm một nhịp là tôi hủy toàn bộ."}
effects = { "than": { "tip_percent": 20 }, "trung_tinh": { "tip_percent": 5 }, "kho": { "lost_order": true } }
risk_warning = "Giám đốc khó tính — sai một đơn là mất hợp đồng dài hạn."
unlock_rule = &"khach_giam_doc"
```

- [ ] **Step 5: Regen unlock_rules**

Run: `godot --headless --path repair-shop-game -s res://tools/build_progression.gd`
Expected: in `unlock_rules.tres save err=0` (và `workspace_upgrades` vẫn err=0).

- [ ] **Step 6: Chạy PASS**

Run từng test đã amend + `bash repair-shop-game/tests/run_suite.sh` → FAIL chỉ baseline `test_outfit` → GATE PASS (ledger). Smoke → không SCRIPT ERROR mới.

- [ ] **Step 7: Commit**

```bash
git add repair-shop-game/scripts/progression/unlock_core.gd repair-shop-game/tools/build_week_schedule.gd repair-shop-game/data/week_schedule.tres repair-shop-game/tools/build_progression.gd repair-shop-game/data/unlock_rules.tres repair-shop-game/data/customers/truong_nhom.tres repair-shop-game/data/customers/giam_doc.tres repair-shop-game/tests/test_activities_data.gd repair-shop-game/tests/test_unlock_data.gd repair-shop-game/tests/test_unlock_core.gd repair-shop-game/tests/test_customer_catalog.gd repair-shop-game/tests/test_workplace_screen.gd
git commit -m "feat: project hooks data + milestone rules + project_count unlock input + 2 customers"
```

---

### Task 3: Entry keys trong `today_activities` + dòng SUMMARIZE

**Files:**
- Modify: `repair-shop-game/scripts/schedule_core.gd` (khối entry trong `try_activity`)
- Modify: `repair-shop-game/scripts/ui/summarize.gd` (`refresh()`)
- Test amend: `test_activities.gd`, `test_day_end.gd`

**Interfaces:**
- Consumes: Task 1 gains keys `"project"` (String), `"uy_tin"` (int).
- Produces: entry dict trong `today_activities` có thêm `"project"` / `"uy_tin"` khi gains có; summary line `Project hoàn thành: +%d uy_tin`. Task 4 chỉ phụ thuộc gains (không phụ thuộc task này) nhưng test_hud bấm activity sẽ tạo entry — không conflict.

- [ ] **Step 1: Amend tests → RED**

`test_activities.gd` — sau dòng 78 (`check_eq(int(gs.mode), ... "end_day at 1320")`):
```gdscript
	check_eq(String(r["gains"].get("project", "")), "p_noibo", "gains project")
	check_eq(int(r["gains"].get("uy_tin", 0)), 10, "gains uy_tin flat (clamp 10 min van +10)")
	check_eq(int(gs.project_count), 1, "project_count 1")
	check(gs.completed_projects.has(&"p_noibo"), "completed_projects append")
	check_eq(String(gs.today_activities[-1].get("project", "")), "p_noibo", "entry project key")
	check_eq(int(gs.today_activities[-1].get("uy_tin", 0)), 10, "entry uy_tin key")
```

`test_day_end.gd`:
- Thêm phần tử vào `gs.today_activities` literal: `{"id": "lam_project", "label": "Làm project", "minutes": 10, "project": "p_noibo", "uy_tin": 10}`.
- Sau assert `Tri thức nhận: +6` thêm: `check(String(lbl.text).contains("Project hoàn thành: +10 uy_tin"), "project uy tin line +10")`.
- Sau assert RF5 (dòng sau `BtnSleep` pressed + `s.refresh()`): thêm `check_eq(String(lbl.text).contains("Project hoàn thành"), false, "project line hidden when no entries (RF5)")`.

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_activities.gd` → RED.

- [ ] **Step 2: Implement**

`schedule_core.gd` — trong khối tạo `entry` sau `if k > 0:` hiện tại:
```gdscript
		if gains.has("project"):
			entry["project"] = String(gains["project"])
		var ui := int(gains.get("uy_tin", 0))
		if ui > 0:
			entry["uy_tin"] = ui
```

`summarize.gd` — sau khối tính `know` / sau dòng `Tri thức nhận` (thứ tự: `Tiền` → `Tri thức nhận` → `Project hoàn thành` → `Phạt`): tính `proj_uy` = tổng `int(a.get("uy_tin", 0))` với mọi entry `a.has("project")`; `if proj_uy > 0: lines.append("Project hoàn thành: +%d uy_tin" % proj_uy)`.

- [ ] **Step 3: Chạy PASS**

Run: Step 1 command → PASS; `run_one` `test_day_end.gd` → PASS; suite → GATE PASS (ledger); smoke OK.

- [ ] **Step 4: Commit**

```bash
git add repair-shop-game/scripts/schedule_core.gd repair-shop-game/scripts/ui/summarize.gd repair-shop-game/tests/test_activities.gd repair-shop-game/tests/test_day_end.gd
git commit -m "feat: project gains in activity entries + summarize uy tin line"
```

---

### Task 4: Toast `Hoàn thành project!`

**Files:**
- Modify: `repair-shop-game/scripts/ui/hud.gd` (`_on_activity`, dòng ~101-105)
- Test amend: `test_hud_activity.gd`

**Interfaces:**
- Consumes: Task 1 gains `"project"`/`"uy_tin"`; helper `_toast(msg: String)` + `_hide_toast()` (cycle 2).
- Produces: toast hiển thị khi bấm activity có project gains.

- [ ] **Step 1: Amend test → RED**

`test_hud_activity.gd` — chèn **ngay sau** dòng `check_eq(int(gs.minute), 1140, "consume 120 -> 1140")` (trước khối `# REPAIR mode -> an panel`):
```gdscript
	# project toast: PROJECT slot tai 1140, workshop (RF: toast dung chuoi cycle 3)
	hud.refresh()
	box = hud.get_node("Root/ActivityBox")
	check(box.has_node("Btn_lam_project"), "lam_project button in PROJECT")
	box.get_node("Btn_lam_project").pressed.emit()
	check_eq(String(hud.get_node("Root/Toast").text), "Hoàn thành project! +10 uy_tin", "project toast text")
	check_eq(bool(hud.get_node("Root/Toast").visible), true, "project toast visible")
	check_eq(int(gs.project_count), 1, "project_count 1 after press")
```
(Lưu ý implementer: sau emit, `advance_to(1320)` → mode SUMMARIZE; block sau vẫn `gs.mode = REPAIR` ghi đè — không sửa block cũ. Nếu `pressed` bị chặn vì mode, kiểm tra `reason_for` và chỉ di chuyển chèn nếu cần — giữ nguyên mọi assertion cũ.)

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_hud_activity.gd` → RED (toast text sai/rỗng).

- [ ] **Step 2: Implement**

`hud.gd` `_on_activity` — nhánh `gains` (hiện `var k ...; if k > 0: _toast("+%d tri thức" % k)`):
```gdscript
		if gains.has("project"):
			_toast("Hoàn thành project! +%d uy_tin" % int(gains.get("uy_tin", 0)))
		elif k > 0:
			_toast("+%d tri thức" % k)
```

- [ ] **Step 3: Chạy PASS**

Run: Step 1 command → PASS (assert `mo_panel` toast rỗng cũ vẫn pass → RF5). Suite → GATE PASS (ledger). Smoke OK.

- [ ] **Step 4: Commit**

```bash
git add repair-shop-game/scripts/ui/hud.gd repair-shop-game/tests/test_hud_activity.gd
git commit -m "feat: project completion toast"
```

---

### Task 5: Whole-branch review + merge

**Files:** không sửa chủ động (chỉ fix pass review)

- [ ] **Step 1: Whole-branch review** — dispatch 1 reviewer subagent fresh context, template `requesting-code-review/code-reviewer.md`, input: diff `76cdafd..HEAD` + spec + plan. Yêu cầu phân loại Critical/Important/Minor + Recommendations.
- [ ] **Step 2: Fix pass** — sửa Critical/Important theo skill; Minor → ledger `progress.md` (`Ruling:`); Recommendations → ledger.
- [ ] **Step 3: Verification cuối** — suite GATE PASS + smoke (bằng chứng chạy thật, không suy diễn).
- [ ] **Step 4: Merge + dọn** — `git fetch . feat/project-milestones:feat/schedule-engine` (ff, tránh checkout refusal do dirty `run_tests.gd`), checkout `feat/schedule-engine`, xác nhận suite trên nhánh chính, `git branch -d feat/project-milestones`, commit docs spec+plan.
