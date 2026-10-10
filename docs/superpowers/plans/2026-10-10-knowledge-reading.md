# Knowledge / Reading Rewards (Cycle 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Điền `ActivityDef.hook` của cycle 1 — 4 hoạt động (`doc_sach_nha`, `doc_thu_vien`, `di_hoc`, `su_kien_doi_thuong`) sinh `knowledge` theo phút thực consume, kèm phản hồi toast HUD + dòng tổng SUMMARIZE.

**Architecture:** Hook format `"key:value[,key:value]*"` với key `knowledge_rate` (knowledge/phút). Executor mới `HookRunner.apply(gs, hook, consumed)` cộng dồn phần lẻ qua field mới `game_state.knowledge_remainder`. `ScheduleCore.try_activity` gọi runner, trả thêm key `gains`, ghi `"knowledge"` vào `today_activities`. Rate là data trong `week_schedule.tres` (builder ghi + validate); riêng hook ngày lễ sống trong code `ScheduleCore.available()` (runtime tự dựng ActivityDef, không lấy từ tres).

**Tech Stack:** Godot 4 (GDScript), test harness headless `tests/run_suite.sh` + `run_one.gd`.

**Spec:** `docs/superpowers/specs/2026-10-10-knowledge-reading-design.md`

**Branch:** cắt `feat/knowledge-reading` từ `feat/schedule-engine` @ `11320a6`.

## Global Constraints

- Exact strings (test assert đúng chuỗi này): toast `+N tri thức` (vd `+2 tri thức`), SUMMARIZE `Tri thức nhận: +N` (vd `Tri thức nhận: +6`).
- Exact hook values: `di_hoc` = `knowledge_rate:0.008`, `doc_thu_vien` = `knowledge_rate:0.030`, `doc_sach_nha` = `knowledge_rate:0.020`, `su_kien_doi_thuong` = `knowledge_rate:0.010`. Các activity khác giữ `hook == ""`.
- KHÔNG sửa `unlock_core.gd`, `workspace_upgrades.gd`, `main.tscn`.
- `game_state.gd` chỉ **thêm** `var knowledge_remainder: float = 0.0` — không đổi field khác; `begin_new_day()` KHÔNG được reset nó.
- KHÔNG `git add repair-shop-game/scenes/cafe.tscn` (file đang sửa dở của user, working tree dirty) — cũng không add `.DS_Store`/`.idea`/thư mục ngoài repo.
- `.uid` của file `.gd` mới được commit kèm (repo convention).
- Gate sau **mỗi** task: `bash repair-shop-game/tests/run_suite.sh` → `TOTAL_FAILURES=0` + không `SCRIPT ERROR` → `GATE PASS`; smoke trước commit: `godot --headless --path repair-shop-game --quit-after 60 res://scenes/main.tscn` → 0 `SCRIPT ERROR`.
- Single test: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/<ten>.gd` → dòng `FAILURES=0`.

## Review Focus

1. **Phút clamp cuối slot** — activity bị slot cắt ngắn chỉ hưởng theo phút thực consume (không phải slot trọn): test_activities Task 2 (gs2 fresh: minute 1139 + `doc_sach_nha` → consumed 1 → knowledge int +0, `knowledge_remainder ≈ 0.02`).
2. **Remainder qua đêm** — `begin_new_day()` không reset `knowledge_remainder` (phần lẻ hôm trước vẫn giá trị): test_hook_runner Task 1 (set 0.7 → `begin_new_day()` → vẫn 0.7).
3. **Activity fail không sinh side-effect** — `ok:false` → không key `gains`, `knowledge`/`today_activities` không đổi: test_activities Task 2 (di_hoc sai vị trí lần gọi đầu).
4. **Hook ngày lễ là runtime-only** — `ScheduleCore.available()` tự dựng `ActivityDef` nên hook phải ghi trong code, không chờ tres: test_activities Task 2 (`hacts[0].hook == "knowledge_rate:0.010"` + gains `+7`).
5. **Dòng SUMMARIZE ẩn khi tổng = 0** — không hiện `Tri thức nhận` khi không có hoạt động sinh tri thức, line `Tiền:` không bị đè: test_day_end Task 4 (sau sleep, refresh → `not contains("Tri thức nhận")`).

---

### Task 1: HookRunner + knowledge_remainder

**Files:**
- Create: `repair-shop-game/scripts/data/hook_runner.gd` (+`.uid` sinh tự động), `repair-shop-game/tests/test_hook_runner.gd` (+`.uid`)
- Modify: `repair-shop-game/scripts/autoload/game_state.gd:4` (thêm field sau `var knowledge`), `repair-shop-game/tests/run_tests.gd` (append entry cuối)

**Interfaces:**
- Consumes: `game_state.knowledge` (int), `game_state.knowledge_remainder` (float — task này tạo), `game_state.begin_new_day()` (không đổi).
- Produces: `HookRunner.apply(gs: Node, hook: String, consumed: int) -> Dictionary` — trả `{}` nếu hook rỗng/hết gain; `{"knowledge": N}` với `N >= 1` khi có gain nguyên. Task 2+ gọi API này; mọi test sau đọc `gs.knowledge_remainder`.

- [ ] **Step 1: Viết test FAIL mới `tests/test_hook_runner.gd`**

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var hr = load("res://scripts/data/hook_runner.gd")
	check(hr != null, "hook_runner loads")
	if hr == null:
		return
	var gs = load("res://scripts/autoload/game_state.gd").new()

	# hook rỗng -> {} + state giu nguyen (spec 6)
	var g = hr.apply(gs, "", 135)
	check_eq(g.size(), 0, "empty hook -> empty gains")
	check_eq(int(gs.knowledge), 0, "empty hook: knowledge unchanged")

	# rate x phut: 0.03 x 135 = 4.05 -> +4, remainder 0.05
	g = hr.apply(gs, "knowledge_rate:0.03", 135)
	check_eq(int(g.get("knowledge", -1)), 4, "0.03x135 -> +4")
	check_eq(int(gs.knowledge), 4, "knowledge = 4")
	check_near(float(gs.knowledge_remainder), 0.05, 0.001, "remainder 0.05")

	# remainder cong don (RF2): 0.06 x 10 = 0.6 -> lan 1 +0, lan 2 +1 (rem 0.65 -> 0.25)
	g = hr.apply(gs, "knowledge_rate:0.06", 10)
	check_eq(g.size(), 0, "sub-unit gain -> no knowledge key")
	check_eq(int(gs.knowledge), 4, "first 0.6: no int gain")
	check_near(float(gs.knowledge_remainder), 0.65, 0.001, "rem 0.05+0.6")
	g = hr.apply(gs, "knowledge_rate:0.06", 10)
	check_eq(int(g.get("knowledge", -1)), 1, "second 0.6 -> +1")
	check_eq(int(gs.knowledge), 5, "knowledge 5")
	check_near(float(gs.knowledge_remainder), 0.25, 0.001, "rem 0.25")

	# key la -> warn + bo qua, pair tot ke ben van chay (spec 6)
	var k0 := int(gs.knowledge)
	g = hr.apply(gs, "foo:1,knowledge_rate:0.01", 100)
	check_eq(int(g.get("knowledge", -1)), 1, "good pair runs despite bad key")
	check_eq(int(gs.knowledge), k0 + 1, "knowledge from good pair")

	# rate am -> warn + khong doi (spec 6)
	k0 = int(gs.knowledge)
	var r0 := float(gs.knowledge_remainder)
	g = hr.apply(gs, "knowledge_rate:-0.5", 100)
	check_eq(g.size(), 0, "negative rate -> no gains")
	check_eq(int(gs.knowledge), k0, "negative rate: knowledge unchanged")
	check_near(float(gs.knowledge_remainder), r0, 0.001, "negative rate: remainder unchanged")

	# value rac -> warn + khong doi (spec 6)
	g = hr.apply(gs, "knowledge_rate:abc", 100)
	check_eq(g.size(), 0, "bad value -> no gains")
	check_eq(int(gs.knowledge), k0, "bad value: knowledge unchanged")

	# RF2: begin_new_day KHONG reset remainder (spec 3.2)
	gs.knowledge_remainder = 0.7
	gs.begin_new_day()
	check_near(float(gs.knowledge_remainder), 0.7, 0.001, "remainder survives begin_new_day")

	# source pin: push_warning ton tai (spec 8)
	var f = FileAccess.open("res://scripts/data/hook_runner.gd", FileAccess.READ)
	check(f != null and f.get_as_text().contains("push_warning"), "bad hook warns (source pin)")
	gs.free()
```

Append sau entry cuối trong `run_tests.gd`: `"res://tests/test_hook_runner.gd",`

- [ ] **Step 2: Chạy test, verify FAIL**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_hook_runner.gd`
Expected: FAIL — `cannot load` / parse error (file chưa tồn tại).

- [ ] **Step 3: Implement**

`scripts/autoload/game_state.gd`: thêm đúng 1 dòng sau `var knowledge: int = 0`:
```gdscript
var knowledge_remainder: float = 0.0
```
(Không đụng `begin_new_day`.)

`scripts/data/hook_runner.gd`: `class_name HookRunner extends RefCounted` + `static func apply(gs: Node, hook: String, consumed: int) -> Dictionary`:
- `hook == ""` → `return {}`.
- Tách `hook.split(",")`; mỗi pair tách ở lần xuất hiện `:` đầu tiên (`find(":")`) → key/value (strip_edges). Pair thiếu `:` → `push_warning` + bỏ qua.
- Key `knowledge_rate`: value phải `is_valid_float()` và `to_float() >= 0` (sai → `push_warning` + bỏ qua pair); `gain_f = value.to_float() × consumed` → `gs.knowledge_remainder += gain_f` → `N = int(gs.knowledge_remainder)` → `gs.knowledge_remainder -= N` → `gs.knowledge += N`; nếu `N > 0` ghi `out["knowledge"] = N`.
- Key không nằm whitelist (`knowledge_rate`) → `push_warning` + bỏ qua pair.
- Trả `out: Dictionary`.

- [ ] **Step 4: Chạy test, verify PASS**

Run: cùng lệnh Step 2. Expected: `FAILURES=0`.

- [ ] **Step 5: Gate + smoke + commit**

```bash
bash repair-shop-game/tests/run_suite.sh          # GATE PASS
godot --headless --path repair-shop-game --quit-after 60 res://scenes/main.tscn   # 0 SCRIPT ERROR
git add repair-shop-game/scripts/data/hook_runner.gd repair-shop-game/scripts/data/hook_runner.gd.uid \
  repair-shop-game/tests/test_hook_runner.gd repair-shop-game/tests/test_hook_runner.gd.uid \
  repair-shop-game/scripts/autoload/game_state.gd repair-shop-game/tests/run_tests.gd
git commit -m "feat: HookRunner knowledge_rate + knowledge_remainder (cycle 2)"
```

---

### Task 2: ScheduleCore gains + hook data trong builder

**Files:**
- Modify: `repair-shop-game/scripts/schedule_core.gd` (`available()` holiday hook; `try_activity()` gains — dòng ~45-66), `repair-shop-game/tools/build_week_schedule.gd` (`_act` nhận hook + 4 call site + validate trước save), `repair-shop-game/data/week_schedule.tres` (regen), `repair-shop-game/tests/test_activities.gd`, `repair-shop-game/tests/test_activities_data.gd`

**Interfaces:**
- Consumes: `HookRunner.apply(gs, hook, consumed)` (Task 1), `ActivityDef.hook` (đã có).
- Produces: `try_activity` trả `{"ok": true, "reason": "", "gains": Dictionary}` (gains có thể `{}`; key vắng khi `ok:false`); entry `today_activities` thêm key `"knowledge": int` khi gain > 0. Task 3 đọc `r["gains"]["knowledge"]`; Task 4 đọc `a["knowledge"]`.

- [ ] **Step 1: Amend 2 test → FAIL**

`tests/test_activities_data.gd` — **thay dòng cuối** `check_eq(...hook, "", "hook empty cycle1")` bằng:

```gdscript
	check_eq(String(school0.activities[0].hook), "knowledge_rate:0.008", "di_hoc hook cycle2")
	check_eq(String(mon.slots[1].activities[0].hook), "knowledge_rate:0.030", "doc_thu_vien hook")
	check_eq(String(t3.slots[3].activities[1].hook), "knowledge_rate:0.020", "doc_sach_nha hook")
	check_eq(String(mon.slots[4].activities[0].hook), "", "lam_project hook empty (cycle3)")
```

`tests/test_activities.gd` — chèn các block sau (biến `gains`/`gains2` khai báo inline, dùng `var gains: Dictionary = r.get("gains", {})`):

1. Sau `check_eq(gs.minute, 420, "minute unchanged on fail")` (fail sai vị trí — RF3):
```gdscript
	check(not r.has("gains"), "fail: no gains key")
	check_eq(int(gs.knowledge), 0, "fail: knowledge unchanged")
```
2. Sau `check_eq(gs.minute, 690, "consume 270 -> 11:30")` (di_hoc ok):
```gdscript
	var gains: Dictionary = r.get("gains", {})
	check_eq(int(gains.get("knowledge", -1)), 2, "di_hoc gains +2 (0.008 x 270)")
	check_eq(int(gs.knowledge), 2, "knowledge = 2")
	check_eq(int(gs.today_activities[-1].get("knowledge", 0)), 2, "today entry knowledge")
```
3. Sau `check_eq(gs.minute, 825, "consume 135 -> 13:45")` (doc_thu_vien ok):
```gdscript
	var gains2: Dictionary = r.get("gains", {})
	check_eq(int(gains2.get("knowledge", -1)), 4, "thu_vien gains +4 (0.030 x 135)")
	check_eq(int(gs.knowledge), 6, "knowledge 2+4")
```
4. Sau `check_eq(gs.minute, 1020, "mo_panel consumes 0")`:
```gdscript
	check_eq(Dictionary(r.get("gains", {})).size(), 0, "mo_panel: empty gains")
```
5. Sau `check_eq(gs.minute, 1320, "900 clamp to 1320")` (holiday — RF4):
```gdscript
	check_eq(String(hacts[0].hook), "knowledge_rate:0.010", "holiday hook set in code (RF4)")
	var hg: Dictionary = r.get("gains", {})
	check_eq(int(hg.get("knowledge", -1)), 7, "holiday gains +7 (0.010 x 720 clamp 600->1320)")
	check_eq(int(gs.knowledge), 13, "knowledge 2+4+7")
```
6. **Cuối `run()`** (sau block bad-format holiday — RF1, gs2 fresh):
```gdscript
	# RF1: phut clamp cuoi slot — gain tren phut thuc
	var gs2 = load("res://scripts/autoload/game_state.gd").new()
	gs2.current_location = "workshop"
	gs2.minute = 1139
	var r2 = core.try_activity(gs2, "doc_sach_nha")
	check_eq(r2.ok, true, "clamp: doc_sach_nha ok")
	check_eq(int(gs2.minute), 1140, "clamp: minute 1140")
	check_eq(Dictionary(r2.get("gains", {})).size(), 0, "clamp 1 phut: no int gain")
	check_eq(int(gs2.today_activities[0].get("knowledge", 0)), 0, "clamp: khong tich int")
	check_near(float(gs2.knowledge_remainder), 0.02, 0.001, "clamp: rem = 0.02 x 1 phut")
	gs2.free()
```

- [ ] **Step 2: Chạy 2 test, verify FAIL**

Run lần lượt: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_activities_data.gd` và `... -- res://tests/test_activities.gd`
Expected: cả 2 `FAILURES>0` (hook rỗng, không key `gains`).

- [ ] **Step 3: Implement `schedule_core.gd`**

- `available()`: sau khi set `h.minutes = 900`, thêm `h.hook = "knowledge_rate:0.010"` (ActivityDef inline — RF4).
- `try_activity()`: sau khi tính `consumed`, **trước** block push `today_activities`:
  - `var gains := HookRunner.apply(gs, act.hook, consumed)` — `class_name HookRunner` resolve toàn cục như `ActivityDef` sẵn có trong file này, không cần preload.
  - Entry dict thêm `var k := int(gains.get("knowledge", 0))`; nếu `k > 0` thì entry["knowledge"] = k (chỉ khi id != "mo_panel", giữ nguyên nhánh hiện tại).
  - Return cuối thành `return {"ok": true, "reason": "", "gains": gains}`.
  - Các nhánh `ok:false` giữ nguyên (không có `gains`).

- [ ] **Step 4: Implement builder + regen `.tres`**

`tools/build_week_schedule.gd`:
- `_act(id, String label, loc, minutes, hook := "")` — thêm tham số + `a.hook = hook`.
- Ghi hook đúng 4 chỗ: `di_hoc` → `knowledge_rate:0.008`; `doc_thu_vien` → `knowledge_rate:0.030`; `doc_sach_nha` (cả nhánh REPAIR và FREE_HOME) → `knowledge_rate:0.020`; `su_kien_doi_thuong` (nhánh HOLIDAY) → `knowledge_rate:0.010`. Các act khác không truyền hook.
- Trước `ResourceSaver.save`: validate mọi activity có hook ≠ "" — mỗi pair phải có key = `knowledge_rate` và value `is_valid_float()`且 `>= 0`; sai → `push_error` + `quit(1)` (không save).

Regen: `godot --headless --path repair-shop-game -s res://tools/build_week_schedule.gd` → in `WROTE res://data/week_schedule.tres err=0`.

- [ ] **Step 5: Chạy 2 test, verify PASS**

Run lại 2 lệnh Step 2. Expected: cả 2 `FAILURES=0`.

- [ ] **Step 6: Gate + smoke + commit**

```bash
bash repair-shop-game/tests/run_suite.sh          # GATE PASS
godot --headless --path repair-shop-game --quit-after 60 res://scenes/main.tscn   # 0 SCRIPT ERROR
git add repair-shop-game/scripts/schedule_core.gd repair-shop-game/tools/build_week_schedule.gd \
  repair-shop-game/data/week_schedule.tres repair-shop-game/tests/test_activities.gd \
  repair-shop-game/tests/test_activities_data.gd
git commit -m "feat: hook knowledge_rate cho 4 hoat dong (schedule_core + builder)"
```

---

### Task 3: HUD toast `+N tri thức`

**Files:**
- Modify: `repair-shop-game/scripts/ui/hud.gd` (var `_lbl_toast`, node trong `_build_ui`, `_toast()`, nhánh gains trong `_on_activity`:94), `repair-shop-game/tests/test_hud_activity.gd`

**Interfaces:**
- Consumes: `try_activity` trả `gains` (Task 2), pattern `_toast()` của `workplace_screen.gd:183` (set text + `visible = true` + `get_tree().create_timer(1.5)` chỉ khi `is_inside_tree()`).
- Produces: node `Root/Toast` (Label, default `visible=false`, default text `""`). Không task sau nào consume — test đọc trực tiếp.

- [ ] **Step 1: Amend test `test_hud_activity.gd` → FAIL**

Chèn **giữa** block mo_panel (`check_eq(int(gs.minute), m0, "minute unchanged")`) và block `# REPAIR mode -> an panel`:

```gdscript
	# toast rong sau mo_panel khong hook (RF4)
	check_eq(String(hud.get_node("Root/Toast").text), "", "toast empty after mo_panel")
	check_eq(bool(hud.get_node("Root/Toast").visible), false, "toast hidden after mo_panel")

	# doc_sach_nha luc 1020 REPAIR: 120 phut x 0.020 = 2.4 -> +2 (spec 5.1)
	box = hud.get_node("Root/ActivityBox")
	check(box.has_node("Btn_doc_sach_nha"), "doc_sach_nha button in REPAIR")
	box.get_node("Btn_doc_sach_nha").pressed.emit()
	check_eq(String(hud.get_node("Root/Toast").text), "+2 tri thức", "toast text")
	check_eq(bool(hud.get_node("Root/Toast").visible), true, "toast visible")
	check_eq(int(gs.knowledge), 2, "gs.knowledge = 2")
	check_eq(int(gs.minute), 1140, "consume 120 -> 1140")
```

- [ ] **Step 2: Chạy test, verify FAIL**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_hud_activity.gd`
Expected: `FAILURES>0` — `Root/Toast` không tồn tại (has_node false → get_node null → error/FAIL).

- [ ] **Step 3: Implement `hud.gd`**

- Var mới cạnh `_lbl_budget`: `var _lbl_toast: Label`.
- `_build_ui()` (sau khi add `_activity_box`): tạo `Label` name `"Toast"`, `visible = false`, `horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER`, `set_anchors_preset(Control.PRESET_CENTER_TOP)` + offsets y ≈ 60..100, x ≈ ±260 (copy `workplace_screen.gd:306-315`), add vào `root`.
- `_toast(msg: String) -> void`: copy pattern `workplace_screen.gd:183-188` (set text, visible, timer 1.5s nếu `is_inside_tree()`).
- `_on_activity()`: sau nhánh `mo_panel`, thêm:
```gdscript
	if bool(r.get("ok", false)):
		var gains: Dictionary = r.get("gains", {})
		var k: int = int(gains.get("knowledge", 0))
		if k > 0:
			_toast("+%d tri thức" % k)
```

- [ ] **Step 4: Chạy test, verify PASS**

Run lại lệnh Step 2. Expected: `FAILURES=0`.

- [ ] **Step 5: Gate + smoke + commit**

```bash
bash repair-shop-game/tests/run_suite.sh          # GATE PASS
godot --headless --path repair-shop-game --quit-after 60 res://scenes/main.tscn   # 0 SCRIPT ERROR
git add repair-shop-game/scripts/ui/hud.gd repair-shop-game/tests/test_hud_activity.gd
git commit -m "feat: HUD toast +N tri thức khi hoat dong sinh knowledge"
```

---

### Task 4: SUMMARIZE dòng `Tri thức nhận: +N`

**Files:**
- Modify: `repair-shop-game/scripts/ui/summarize.gd` (`refresh()`), `repair-shop-game/tests/test_day_end.gd`

**Interfaces:**
- Consumes: entry `today_activities` có key `"knowledge"` (Task 2).
- Produces: dòng `Tri thức nhận: +N` trong `Root/LblSummary` khi tổng > 0; ẩn khi = 0.

- [ ] **Step 1: Amend test `test_day_end.gd` → FAIL**

1. Trong literal `gs.today_activities` (dòng ~15): thêm `"knowledge": 2` vào dict `di_hoc` và `"knowledge": 4` vào dict `doc_thu_vien` (dict `nghi_ngoi` giữ nguyên không key).
2. Sau 2 assert hiện có (`contains("Nghỉ ngơi")`) chèn:
```gdscript
	check(String(lbl.text).contains("Tri thức nhận: +6"), "knowledge total line +6")
	check(String(lbl.text).contains("Tiền:"), "money line intact")
```
3. Cuối test (sau assert `ky_luat` penalty, trước `s.free()`), sau khi đã bấm `BtnSleep`:
```gdscript
	s.refresh()
	check_eq(bool(String(lbl.text).contains("Tri thức nhận")), false, "knowledge line hidden when 0 (RF5)")
```

- [ ] **Step 2: Chạy test, verify FAIL**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_day_end.gd`
Expected: `FAILURES>0` — `Tri thức nhận` không có trong text.

- [ ] **Step 3: Implement `summarize.gd`**

Trong `refresh()`: sau vòng lặp append activity lines và dòng `Tiền:`, tính `var know: int = 0` — `for a in game_state.today_activities: if a.has("knowledge"): know += int(a["knowledge"])`; nếu `know > 0` → `lines.append("Tri thức nhận: +%d" % know)`. Không đổi thứ tự line `Tiền`/phạt hiện có, không đổi `_on_sleep`.

- [ ] **Step 4: Chạy test, verify PASS**

Run lại lệnh Step 2. Expected: `FAILURES=0`.

- [ ] **Step 5: Gate + smoke + commit + cross-check spec**

```bash
bash repair-shop-game/tests/run_suite.sh          # GATE PASS
godot --headless --path repair-shop-game --quit-after 60 res://scenes/main.tscn   # 0 SCRIPT ERROR
git add repair-shop-game/scripts/ui/summarize.gd repair-shop-game/tests/test_day_end.gd
git commit -m "feat: SUMMARIZE dong Tri thức nhận tong trong ngay"
```

Cross-check cuối (self-review trước khi báo done): đi lần spec §3-§7 — mỗi requirement chỉ tới đúng test đã pin ở trên; xác nhận `git status` không có `cafe.tscn` trong staged;5 Review Focus đều có test.
