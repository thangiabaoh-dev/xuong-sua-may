# Schedule Engine (Lịch tuần & khung giờ) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bổ sung lên nền schedule sẵn có: activity system (đúng khung + đúng chỗ + bấm → consume phút), budget ca sửa + `LOST_TIME`, gate nhận đơn theo khung giờ, panel SUMMARIZE + rollover có phạt học đường, HUD panel hoạt động, `change_map` advisory.

**Architecture:** Giữ `WeekSchedule/TimeSlot .tres` + `ScheduleLogic` static + `GameState` autoload của session song song. Logic mới nằm trong `ScheduleCore` (RefCounted thuần, test headless). `ClockTimer` bỏ tick realtime theo ruling Q1; `can_enter` chuyển advisory theo Q2. UI theo pattern `_build_ui()` programmatic trong CanvasLayer.

**Tech Stack:** Godot 4.7.2 headless, GDScript, test `test_case.gd` (`check/check_eq/check_near`), runner `run_one.gd` + gate `run_suite.sh`.

**Spec:** `docs/superpowers/specs/2026-10-08-schedule-engine-design.md` (kèm amend §9: 5 test file phải sửa assertion — `test_clock_timer`, `test_hud`, `test_game_state_time`, `test_repair_panel`, `test_map_gating`).

## Global Constraints

- **Gate:** `bash repair-shop-game/tests/run_suite.sh` → phải ra `TOTAL_FAILURES=0` VÀ `GATE PASS`. Output chứa `SCRIPT ERROR` = fail kể cả TOTAL=0. Gate đỏ thì **không commit**.
- **Run single test:** `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/<ten_test>.gd` → dòng `FAILURES=0` là pass.
- **Smoke** (task sửa `main.tscn`/UI lớn): `godot --headless --path repair-shop-game --quit-after 60 res://scenes/main.tscn > /tmp/smoke.log 2>&1`; grep `SCRIPT ERROR` trong `/tmp/smoke.log` phải rỗng, rc=0. **macOS không có `timeout`** — đừng dùng.
- **Harness `-s` không có autoload** → test tự `load("res://scripts/autoload/game_state.gd").new()`, không identifier toàn cục `GameState`.
- **GDScript:** `:=` infer từ Variant = parse error → luôn khai báo kiểu tường minh (`var x: int = f()`).
- **Repo có unicode path** (`file nhảy cảm`) → sửa file lớn qua heredoc/python3 trong bash nếu file-tool lỗi.
- **Session song song đang commit cùng nhánh:** `git add` **chỉ từng file của task**, tuyệt đối không `git add -A`/`git add .`.
- **Không sửa file phiên NPC:** `chibi-model/*`, `tests/test_npc_import.gd`.
- **UI pattern:** `.tscn` root CanvasLayer + script, dựng node trong `_build_ui()`; test `setup(...)` rồi `has_node("Root/...")`.
- Debug keys giữ hằng `KEY_F5/KEY_F6/KEY_F7/KEY_TAB`.
- Commit từng task, message theo repo (`feat:`/`test:`/`docs:`); chỉ sửa test được step chỉ rõ trong task đó.

## Review Focus

Spec im lặng nhưng người chơi dễ gặp — mỗi dòng có test trong task sở hữu:

1. **Sửa dở khi phút chạm 22:00** → phiên phải ra `LOST_TIME` TRƯỚC khi mode sang SUMMARIZE, không mất kết quả. → Task 5, `test_shift_budget.gd` (block "1320 giữa ca").
2. **Budget CN gộp 2 window, không reset giữa BREAK** — `shift_used` chỉ reset ở `begin_new_day`. → Task 5, `test_shift_budget.gd` (block CN).
3. **`try_activity` gọi sai (id lạ / sai chỗ / sai khung / mode != SCHEDULE) không làm lệch phút, trả reason đúng.** → Task 4, `test_activities.gd` (invalid table).
4. **end_day qua biên tháng/năm vẫn đúng khi đổi sang dừng ở SUMMARIZE** (31/10→1/11, 31/12→1/1/2027). → Task 3, amend `test_game_state_time.gd` giữ block, chèn `begin_new_day()`.
5. **Ngoài khung sửa workshop không tạo đơn; trong khung có; budget hết → không tạo; có đơn thì `session != null`.** → Task 5, `test_repair_gate.gd`.

---

### Task 1: `ActivityDef` + `TimeSlot.activities` + builder + sinh `.tres`

**Files:**
- Create: `repair-shop-game/scripts/data/activity_def.gd`
- Modify: `repair-shop-game/scripts/data/time_slot.gd` (thêm field), `repair-shop-game/tools/build_week_schedule.gd` (gắn activities)
- Test: `repair-shop-game/tests/test_activities_data.gd`
- Modify: `repair-shop-game/tests/run_tests.gd` (đăng ký)

**Interfaces:**
- Produces: `class_name ActivityDef extends Resource` với `@export var id: String`, `label: String`, `required_location: String = ""`, `minutes: int`, `hook: String = ""`. `TimeSlot.activities: Array[ActivityDef] = []`.
- Data sinh bởi builder (không viết tay `.tres`): đúng bảng spec §4.1 — `SCHOOL`→`[di_hoc]` (cần `classroom`, 270 sáng/195 chiều — builder truyền theo slot), `CHOICE`→`[doc_thu_vien@library 135, project_ca_phe@cafe 135]`, `REPAIR`→`[mo_panel@workshop 0, nghi_tai_nha@workshop 120, doc_sach_nha@workshop 120]`, `FREE_HOME`→`[lam_project_som, doc_sach_nha, don_kho, nghi_ngoi @workshop 120]`, `PROJECT`→`[lam_project@workshop 180]`, `BREAK`→`[nghi_giac@workshop 90]`. **`HOLIDAY` không nằm trong `.tres`** (slot do `ScheduleLogic.slots_for_day` tạo runtime, `.tres` không có ngày lễ) → Task 4 synthesize.

- [ ] **Step 1: Viết test đỏ `tests/test_activities_data.gd`**

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var week = load("res://data/week_schedule.tres")
	check(week != null, "week loads")
	if week == null:
		return
	var mon = week.days[0]  # T2
	check_eq(mon.slots.size(), 5, "T2 5 slots")
	var school0 = mon.slots[0]
	check_eq(school0.activities.size(), 1, "SCHOOL 1 activity")
	check_eq(String(school0.activities[0].id), "di_hoc", "di_hoc id")
	check_eq(String(school0.activities[0].required_location), "classroom", "di_hoc @classroom")
	check_eq(int(school0.activities[0].minutes), 270, "sang 270")
	check_eq(int(mon.slots[2].activities[0].minutes), 195, "chieu 195")
	check_eq(int(mon.slots[1].activities.size()), 2, "CHOICE 2 activities")
	check_eq(String(mon.slots[3].activities[0].id), "mo_panel", "REPAIR mo_panel first")
	check_eq(int(mon.slots[3].activities[0].minutes), 0, "mo_panel 0 min")
	check_eq(int(mon.slots[4].activities[0].minutes), 180, "PROJECT 180")
	var t3 = week.days[1]
	check_eq(String(t3.slots[3].kind), "FREE_HOME", "T3 no REPAIR")
	check_eq(t3.slots[3].activities.size(), 4, "FREE_HOME 4 choices")
	var cn = week.days[6]
	check_eq(cn.slots.size(), 5, "CN 5 slots")
	check_eq(String(cn.slots[2].kind), "BREAK", "CN slot2 BREAK")
	check_eq(String(cn.slots[2].activities[0].id), "nghi_giac", "CN BREAK activity")
	check_eq(int(cn.slots[2].activities[0].minutes), 90, "CN BREAK 90")
	check_eq(week.days[0].slots[0].activities[0].hook, "", "hook empty cycle1")
```

- [ ] **Step 2: Chạy — verify RED**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_activities_data.gd`
Expected: FAIL (activities null/invalid)

- [ ] **Step 3: Implement**

`scripts/data/activity_def.gd`: class với 5 `@export` đúng Interfaces. `time_slot.gd`: thêm `@export var activities: Array[ActivityDef] = []`. `build_week_schedule.gd`: helper `_act(id, label, loc, minutes)` trả `ActivityDef`; gắn vào `_slot(...)` (đổi `_slot` nhận thêm `acts: Array = []`); các dòng rows truyền activities; slot `SCHOOL` sáng 270 / chiều 195 (rows hiện tại phân biệt được qua start/end — tính `minutes = e - s` cho `di_hoc`).

- [ ] **Step 4: Sinh lại `.tres` + chạy test — verify GREEN**

Run: `godot --headless --path repair-shop-game -s res://tools/build_week_schedule.gd` (in `WROTE ... err=0`), rồi run_one `test_activities_data.gd` → `FAILURES=0`

- [ ] **Step 5: Đăng ký + gate**

Đăng ký path vào `run_tests.gd`; Run: `bash repair-shop-game/tests/run_suite.sh` → `GATE PASS`

- [ ] **Step 6: Commit**

```bash
git add repair-shop-game/scripts/data/activity_def.gd repair-shop-game/scripts/data/time_slot.gd repair-shop-game/tools/build_week_schedule.gd repair-shop-game/data/week_schedule.tres repair-shop-game/tests/test_activities_data.gd repair-shop-game/tests/run_tests.gd
git commit -m "feat: ActivityDef + TimeSlot.activities + builder data"
```

---

### Task 2: Bỏ tick realtime ClockTimer (Q1) + amend `test_clock_timer`/`test_hud`

**Files:**
- Modify: `repair-shop-game/scripts/clock_timer.gd`
- Test (amend): `repair-shop-game/tests/test_clock_timer.gd`, `repair-shop-game/tests/test_hud.gd`

**Interfaces:**
- Consumes: `GameState.advance_to(m)`, `end_day()` (hành vi cũ, Task 3 mới đổi).
- Produces: `ClockTimer` **không còn tự tăng `minute` theo wall-clock** — `tick(delta)` chỉ là no-op giữ chỗ (hoặc phát signal nếu phút đổi bên ngoài); `_process` giữ nguyên debug F5/F6/F7; signal `minute_changed(old, new)` giữ nguyên, F6/F7 phát signal như cũ.

- [ ] **Step 1: Amend test đỏ `test_clock_timer.gd`** — chỉ đổi các mục **tick realtime**; GIỮ NGUYÊN mọi assertion F6/F7/rollover (Task 3 mới đổi end_day, Task 3 sẽ amend tiếp file này):

```gdscript
# 1) Muc "mode=REPAIR roi ct.tick(delta) tang minute" (khoang dong 18-25): doi thanh
gs.mode = gs_script.GameStateMode.REPAIR
var m_before: int = gs.minute
ct.tick(5.0)
check_eq(gs.minute, m_before, "tick does not advance minute")

# 2) Muc "tick qua 22:00" (Review Focus #4 cu, cuoi file): tick khong con chay minute
gs.mode = gs_script.GameStateMode.REPAIR
gs.minute = 1319
ct.tick(2.0)
check_eq(gs.minute, 1319, "tick never crosses 22:00 by itself")
ct.tick(60.0)
check_eq(gs.minute, 1319, "still no realtime advance")
```

- [ ] **Step 2: Amend `test_hud.gd`** — block signal hook cuối file: thay `ct.tick(1.0)` + expect `11:31` bằng:

```gdscript
gs.advance_to(691)
hud.refresh()
check(String(lbl.text).contains("11:31"), "refresh shows 11:31")
```

- [ ] **Step 3: Chạy 2 test — verify RED**

Run: run_one `test_clock_timer.gd` và run_one `test_hud.gd`
Expected: FAIL ở assertion "tick does not advance minute"

- [ ] **Step 4: Implement `clock_timer.gd`**

Xóa nhánh `_acc`/while trong `tick()` (giữ `func tick(_delta: float) -> void` rỗng hoặc chỉ no-op); `_process` gọi debug input giữ nguyên; F6/F7 vẫn `advance_to`/`end_day` + phát `minute_changed` như cũ.

- [ ] **Step 5: Chạy 2 test — verify GREEN** rồi gate

Run: run_one cả 2 → `FAILURES=0`; `bash repair-shop-game/tests/run_suite.sh` → `GATE PASS`

- [ ] **Step 6: Commit**

```bash
git add repair-shop-game/scripts/clock_timer.gd repair-shop-game/tests/test_clock_timer.gd repair-shop-game/tests/test_hud.gd
git commit -m "feat: bo tick realtime ClockTimer (action-driven theo spec)"
```

---

### Task 3: `GameState`: `end_day` dừng ở SUMMARIZE + `begin_new_day()` + fields

**Files:**
- Modify: `repair-shop-game/scripts/autoload/game_state.gd`
- Test (amend): `repair-shop-game/tests/test_game_state_time.gd`, `repair-shop-game/tests/test_clock_timer.gd` (chỉ block F7)

**Interfaces:**
- Produces (Task 5/6/4/7 dùng):
  - `var shift_used: int = 0`
  - `var today_activities: Array = []` — mỗi phần tử `{"id": String, "label": String, "minutes": int}`
  - `signal schedule_changed()` — phát ở cuối `advance_to`, `end_day`, `begin_new_day` (HUD/Summarize nghe để refresh)
  - `func advance_to(m: int) -> void`: `minute = clampi(m, 0, 1320)` rồi `if minute >= 1320: end_day()` (clamp là mới — chặn `advance_to(1325)` làm minute=1325)
  - `func end_day() -> void`: **chỉ** `mode = GameStateMode.SUMMARIZE` + phát `schedule_changed` (không reset minute, không đổi date)
  - `func begin_new_day() -> void`: phạt (nếu `thiếu = 450 - school_minutes_done() > 0` → `ky_luat -= 10 * int(ceil(float(thiếu)/450.0))`), `date += 1 ngày` (unix như code cũ), `minute = 420`, `shift_used = 0`, `today_activities.clear()`, `mode = SCHEDULE`, phát `schedule_changed`
  - `func school_minutes_done() -> int` — tổng phút `di_hoc` trong `today_activities`
  - `func slot()` và `func can_enter(loc)` — guard `if week == null: return null` / `return false` (spec §8: data hỏng không crash)
  - `advance_to(1320)` vẫn gọi `end_day()` (đã có)

- [ ] **Step 1: Amend test đỏ `test_game_state_time.gd`** — 3 block end_day/biên:

```gdscript
	gs.advance_to(1320)
	check_eq(gs.minute, 1320, "minute stays at 22:00 in SUMMARIZE")
	check_eq(gs.date["day"], 5, "date NOT advanced until sleep")
	check_eq(gs.mode, gs_script.GameStateMode.SUMMARIZE, "stops at SUMMARIZE")
	check_eq(gs.school_minutes_done(), 0, "no school minutes yet")
	gs.begin_new_day()
	check_eq(gs.minute, 420, "reset 07:00 after sleep")
	check_eq(gs.date["day"], 6, "date +1 after sleep")
	check_eq(gs.mode, gs_script.GameStateMode.SCHEDULE, "back to SCHEDULE")
	check_eq(gs.shift_used, 0, "shift_used reset")
	check_eq(gs.today_activities.size(), 0, "activities reset")

	# bien thang
	gs.date = {"year": 2026, "month": 10, "day": 31}
	gs.advance_to(1320)
	check_eq(gs.mode, gs_script.GameStateMode.SUMMARIZE, "Oct 31 stops SUMMARIZE")
	gs.begin_new_day()
	check_eq(gs.date["month"], 11, "Oct -> Nov")
	check_eq(gs.date["day"], 1, "day 1")

	# bien nam
	gs.date = {"year": 2026, "month": 12, "day": 31}
	gs.advance_to(1320)
	check_eq(gs.mode, gs_script.GameStateMode.SUMMARIZE, "Dec 31 stops SUMMARIZE")
	gs.begin_new_day()
	check_eq(gs.date["year"], 2027, "Dec 2026 -> Jan 2027")
	check_eq(gs.date["day"], 1, "Jan 1")

	# clamp minute
	gs.advance_to(2000)
	check_eq(gs.minute, 1320, "advance_to clamps at 1320")

	# null week khong crash (spec §8)
	gs.week = null
	check(gs.slot() == null, "null week -> slot null")
	check(not gs.can_enter("workshop"), "null week -> can_enter false")
	gs.week = load("res://data/week_schedule.tres")

	# ngoai khung fail-closed
	gs.minute = 300
	check(gs.slot() == null, "05:00 null slot")
	check(not gs.can_enter("workshop"), "05:00 deny all")
```

Amend thêm `test_clock_timer.gd` — mục **F7 end_day** (Task 2 giữ nguyên, nay đổi):

```gdscript
	# F7 -> SUMMARIZE (khong con auto reset)
	ev.keycode = KEY_F7
	ev.pressed = true
	ct._unhandled_input(ev)
	check_eq(int(gs.mode), int(gs_script.GameStateMode.SUMMARIZE), "F7 -> SUMMARIZE")
	check_eq(gs.date["day"], 5, "date unchanged until sleep (van 5/10)")
	gs.begin_new_day()
	check_eq(gs.minute, 420, "reset after sleep")
	check_eq(gs.date["day"], 6, "date +1 after sleep")
	check_eq(int(gs.mode), int(gs_script.GameStateMode.SCHEDULE), "SCHEDULE after sleep")
```

(Lưu ý: block "tick qua 22:00" cuối file Task 2 đã đổi thành không-tick; assertion cũ về date+1 sau tick bị xóa ở Task 2 rồi — không sửa lại.)

- [ ] **Step 2: Chạy — verify RED** (run_one `test_game_state_time.gd` fail "SUMMARIZE"; run_one `test_clock_timer.gd` fail "F7 -> SUMMARIZE")

- [ ] **Step 3: Implement trong `game_state.gd`**

Theo đúng Interfaces (signal + clamp + guard null week + begin_new_day + school_minutes_done); phạt: `var miss: int = 450 - school_minutes_done(); if miss > 0: ky_luat -= 10 * int(ceil(float(miss) / 450.0))`.

- [ ] **Step 4: Chạy — verify GREEN** rồi gate

Run: run_one `test_game_state_time.gd` + run_one `test_clock_timer.gd` → `FAILURES=0`; `bash repair-shop-game/tests/run_suite.sh` → `GATE PASS`

- [ ] **Step 5: Commit**

```bash
git add repair-shop-game/scripts/autoload/game_state.gd repair-shop-game/tests/test_game_state_time.gd repair-shop-game/tests/test_clock_timer.gd
git commit -m "feat: end_day dung tai SUMMARIZE + begin_new_day + clamp + signals"
```

---

### Task 4: `ScheduleCore` — `available` / `reason_for` / `try_activity`

**Files:**
- Create: `repair-shop-game/scripts/schedule_core.gd`
- Modify: `repair-shop-game/scripts/schedule_logic.gd` (chỉ thêm push_warning key lễ sai format — §8)
- Test: `repair-shop-game/tests/test_activities.gd`
- Modify: `repair-shop-game/tests/run_tests.gd`

**Interfaces:**
- Consumes: `ActivityDef` + `TimeSlot.activities` (T1), `GameState.minute/mode/today_activities/GameStateMode` (T3), `ScheduleLogic.current_slot/weekday` (nền họ).
- Produces (Task 6/7 dùng):
  - `class_name ScheduleCore extends RefCounted` (static thuần — không giữ state)
  - `static func available(gs: Node) -> Array[ActivityDef]` — activities của slot hiện tại (**không** lọc theo location); slot null → `[]`; **slot runtime `HOLIDAY` chưa có activities → tự sinh 1 `ActivityDef{id:"su_kien_doi_thuong", minutes:900, required_location:""}`**
  - `static func reason_for(gs: Node, act: ActivityDef) -> String` — `""` = làm được; `"Ngoài lịch"` (mode != SCHEDULE); `"Cần ở: %s"` với `act.required_location` khi location khác (chỉ khi `required_location != ""`)
  - `static func try_activity(gs: Node, id: String) -> Dictionary` — trả `{ok: bool, reason: String}`; tìm act trong `available(gs)` (id không có → `{false, "Ngoài khung giờ"}`); kiểm mode/location qua `reason_for`; ok → `minutes += min(act.minutes, slot.end_minute - minute)` (clamp ≥0), push `today_activities` (`mo_panel` **không** push, không consume), chạm `>= 1320` → `gs.end_day()`, trả `ok:true`
  - `schedule_logic.is_holiday`: entry có `length` khác 5 và khác 10 → `push_warning("holiday key sai format: %s" % h)` rồi skip (vẫn match entry hợp lệ)

- [ ] **Step 1: Viết test đỏ `tests/test_activities.gd`**

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var gs = load("res://scripts/autoload/game_state.gd").new()
	var core = load("res://scripts/schedule_core.gd")
	check(core != null, "schedule_core loads")
	if core == null:
		return
	# T2 07:00, di tai workshop -> SCHOOL slot, di_hoc bi chan vi khong o lop
	gs.current_location = "workshop"
	var acts = core.available(gs)
	check_eq(acts.size(), 1, "SCHOOL has 1 activity")
	check_eq(String(acts[0].id), "di_hoc", "di_hoc")
	check_eq(core.reason_for(gs, acts[0]), "Cần ở: classroom", "wrong location reason")
	var r = core.try_activity(gs, "di_hoc")
	check_eq(r.ok, false, "fail wrong location")
	check_eq(gs.minute, 420, "minute unchanged on fail")

	# dung cho
	gs.current_location = "classroom"
	check_eq(core.reason_for(gs, acts[0]), "", "ok at classroom")
	r = core.try_activity(gs, "di_hoc")
	check_eq(r.ok, true, "di_hoc ok")
	check_eq(gs.minute, 690, "consume 270 -> 11:30")

	# id la
	r = core.try_activity(gs, "khong_ton_tai")
	check_eq(r.ok, false, "unknown id fails")
	check_eq(gs.minute, 690, "minute unchanged unknown id")

	# khong dung khung (11:30 CHOICE: khong con di_hoc)
	gs.current_location = "classroom"
	r = core.try_activity(gs, "di_hoc")
	check_eq(r.ok, false, "di_hoc not in CHOICE slot")

	# CHOICE dung cho
	gs.current_location = "library"
	r = core.try_activity(gs, "doc_thu_vien")
	check_eq(r.ok, true, "doc_thu_vien ok")
	check_eq(gs.minute, 825, "consume 135 -> 13:45")

	# mode khong phai SCHEDULE
	gs.mode = load("res://scripts/autoload/game_state.gd").GameStateMode.REPAIR
	gs.current_location = "classroom"
	r = core.try_activity(gs, "di_hoc")
	check_eq(r.ok, false, "blocked when not SCHEDULE")
	check_eq(gs.minute, 825, "minute unchanged in REPAIR")

	# mo_panel khong consume phut
	gs.mode = load("res://scripts/autoload/game_state.gd").GameStateMode.SCHEDULE
	gs.minute = 1020
	gs.current_location = "workshop"
	r = core.try_activity(gs, "mo_panel")
	check_eq(r.ok, true, "mo_panel ok")
	check_eq(gs.minute, 1020, "mo_panel consumes 0")

	# clamp cuoi slot: 1139 + di 120 (nghi_tai_nha) khong vuot 1140
	gs.minute = 1139
	r = core.try_activity(gs, "nghi_tai_nha")
	check_eq(r.ok, true, "clamp ok")
	check_eq(gs.minute, 1140, "clamped at slot end")

	# cham 1320 -> end_day
	gs.minute = 1320 - 10
	gs.current_location = "workshop"
	r = core.try_activity(gs, "lam_project")
	check_eq(r.ok, true, "project ok")
	check_eq(int(gs.mode), int(load("res://scripts/autoload/game_state.gd").GameStateMode.SUMMARIZE), "end_day at 1320")

	# ngay le — slot runtime khong co activities, core tu sinh
	gs.begin_new_day()
	gs.date = {"year": 2026, "month": 4, "day": 30}
	gs.minute = 600
	gs.current_location = "street"
	var hacts = core.available(gs)
	check_eq(hacts.size(), 1, "holiday 1 activity")
	check_eq(String(hacts[0].id), "su_kien_doi_thuong", "holiday activity id")
	check_eq(core.reason_for(gs, hacts[0]), "", "holiday activity anywhere")
	r = core.try_activity(gs, "su_kien_doi_thuong")
	check_eq(r.ok, true, "holiday ok")
	check_eq(gs.minute, 1320, "900 clamp to 1320")

	# key le sai format: khong crash + push_warning (source pin, spec §8)
	var sl = load("res://scripts/schedule_logic.gd")
	gs.week.holidays.append("sai-format")
	check_eq(bool(sl.is_holiday(gs.week, {"year": 2026, "month": 10, "day": 5})), false, "bad key not holiday")
	var f = FileAccess.open("res://scripts/schedule_logic.gd", FileAccess.READ)
	check(f != null and f.get_as_text().contains("push_warning"), "malformed holiday key warns")
```

- [ ] **Step 2: Chạy — verify RED** (fail "schedule_core loads")

- [ ] **Step 3: Implement**

Theo Interfaces: `scripts/schedule_core.gd` (available có nhánh synthesize `HOLIDAY`, try_activity tìm id qua `available`); thêm 1 `push_warning` trong `schedule_logic.is_holiday` cho entry sai format. Lưu ý: `lam_project` 180′ nhưng slot PROJECT 1140→1320; test set minute 1310 → clamp còn 10 → 1320 → `end_day()`.

- [ ] **Step 4: Chạy — verify GREEN** rồi đăng ký + gate

- [ ] **Step 5: Commit**

```bash
git add repair-shop-game/scripts/schedule_core.gd repair-shop-game/scripts/schedule_logic.gd repair-shop-game/tests/test_activities.gd repair-shop-game/tests/run_tests.gd
git commit -m "feat: ScheduleCore available/reason_for/try_activity + holiday warn"
```

---

### Task 5: Budget ca sửa + gate `open_new_order` + `LOST_TIME`

**Files:**
- Modify: `repair-shop-game/scripts/schedule_core.gd`, `repair-shop-game/scripts/repair/repair_session.gd`, `repair-shop-game/scripts/ui/repair_panel.gd`
- Test (amend): `repair-shop-game/tests/test_repair_panel.gd`
- Test: `repair-shop-game/tests/test_shift_budget.gd`, `repair-shop-game/tests/test_repair_gate.gd`
- Modify: `repair-shop-game/tests/run_tests.gd`

**Interfaces:**
- Consumes: `GameState.shift_used/mode/date` (T3), `ScheduleLogic.is_repair_slot(week, date, minute)` (nền họ), `RepairSession._add_minutes` + `game_state` ref.
- Produces (T6/T7 dùng):
  - `static func shift_budget(gs: Node) -> int` — tổng `end_minute - start_minute` các slot `repair == true` của ngày hiện tại (weekday 120; CN 180+330=510; T3/lễ 0). Không ở slot nào vẫn tính cả ngày (budget của ngày).
  - `static func shift_tick(gs: Node, n: int) -> bool` — **chỉ khi `is_repair_slot(...)`** mới `gs.shift_used += n`; trả `gs.shift_used < shift_budget(gs)`; ngoài slot repair → không cộng, trả `true`.
  - `RepairSession._add_minutes(n)` — thứ tự: `elapsed += n`; (1) `forced = not ScheduleCore.shift_tick(game_state, n)`; (2) `game_state.advance_to(game_state.minute + n)` (advance LUÔN chạy — phút đã tiêu là thật; nếu vượt 1320 → clamp + `end_day` → mode SUMMARIZE); (3) nếu `mode == SUMMARIZE` → `forced = true`; (4) `forced` → `result = Result.LOST_TIME`, `state = State.RESULT`, trả `true`; ngược lại `_check_timeout()` như cũ.
  - `RepairPanel.open_new_order()` — đầu hàm, nếu **không** thỏa `is_repair_slot && shift_used < shift_budget && mode != SUMMARIZE` → `session = null`, `_last_log = reason`, `_render()` (màn "Hết đơn hôm nay"/lý do), **không** gọi `OrderFactory.make`.

- [ ] **Step 1: Viết test đỏ `tests/test_shift_budget.gd`**

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var gs = load("res://scripts/autoload/game_state.gd").new()
	var core = load("res://scripts/schedule_core.gd")
	var gscript = load("res://scripts/autoload/game_state.gd")
	# vao slot REPAIR cua T2 de shift_tick co tinh
	gs.minute = 1020
	check_eq(core.shift_budget(gs), 120, "weekday budget 120")
	check_eq(core.shift_tick(gs, 100), true, "100 < 120 ok")
	check_eq(int(gs.shift_used), 100, "shift_used 100")
	check_eq(core.shift_tick(gs, 30), false, "130 >= 120 exhausted")

	# ngoai slot repair -> khong tinh
	gs.shift_used = 0
	gs.minute = 420
	check_eq(core.shift_tick(gs, 50), true, "no-op outside repair slot")
	check_eq(int(gs.shift_used), 0, "not counted outside repair")

	# CN: window1 + BREAK + window2 gop budget
	gs.date = {"year": 2026, "month": 10, "day": 11}  # CN
	gs.shift_used = 0
	check_eq(core.shift_budget(gs), 510, "CN budget 510")
	gs.minute = 540  # REPAIR window1
	check_eq(core.shift_tick(gs, 180), true, "window1 used 180")
	gs.minute = 760  # BREAK 12:40 — khong tinh, khong reset
	check_eq(core.shift_tick(gs, 30), true, "BREAK no-op")
	check_eq(int(gs.shift_used), 180, "shift_used survives BREAK")
	gs.minute = 810  # window2
	check_eq(core.shift_tick(gs, 330), false, "510 exhausted at end window2")

	# T3 khong co ca sua
	gs.date = {"year": 2026, "month": 10, "day": 6}  # T3
	check_eq(core.shift_budget(gs), 0, "T3 budget 0")

	var rs_script = load("res://scripts/repair/repair_session.gd")

	# session het budget giua ca -> LOST_TIME
	gs.date = {"year": 2026, "month": 10, "day": 5}
	gs.minute = 1030
	gs.mode = gscript.GameStateMode.REPAIR
	gs.shift_used = 110
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 1
	var order1 = load("res://scripts/orders/order_factory.gd").make(rng1, 0, 0)
	var sess1 = rs_script.new(order1, gs, rng1)
	var hit1 = sess1._add_minutes(20)  # 110+20=130 > 120
	check_eq(hit1, true, "budget forced timeout true")
	check_eq(int(sess1.result), int(rs_script.Result.LOST_TIME), "LOST_TIME on budget exhaust")
	check_eq(int(gs.shift_used), 130, "counted 20 in slot")

	# 1320 giua ca -> LOST_TIME + clamp + SUMMARIZE (Review Focus #1)
	gs.shift_used = 0
	gs.minute = 1310
	gs.mode = gscript.GameStateMode.REPAIR
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 2
	var order2 = load("res://scripts/orders/order_factory.gd").make(rng2, 0, 0)
	var sess2 = rs_script.new(order2, gs, rng2)
	var hit2 = sess2._add_minutes(15)  # 1310 + 15 = 1325
	check_eq(hit2, true, "timeout true")
	check_eq(int(sess2.result), int(rs_script.Result.LOST_TIME), "LOST_TIME before SUMMARIZE")
	check_eq(int(gs.mode), int(gscript.GameStateMode.SUMMARIZE), "mode SUMMARIZE")
	check_eq(int(gs.minute), 1320, "minute clamped at 1320")
```

- [ ] **Step 2: Viết test đỏ `tests/test_repair_gate.gd`**

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var packed := load("res://scenes/repair_panel.tscn") as PackedScene
	var panel = packed.instantiate()
	var gs = load("res://scripts/autoload/game_state.gd").new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# 07:00 SCHOOL: khong tao don
	panel.setup(gs, rng)
	check(panel.session == null, "no session outside repair slot")
	# vao 17:00 REPAIR: tao don
	gs.advance_to(1020)
	panel.open_new_order()
	check(panel.session != null, "session in repair slot")
	# het budget: khong tao don moi
	gs.shift_used = 9999
	panel.open_new_order()
	check(panel.session == null, "no session when budget exhausted")
	panel.free()
```

- [ ] **Step 3: Chạy 2 test — verify RED** (run_one từng cái → fail đúng assertion đầu: `shift_budget` chưa tồn tại / `session == null`)

- [ ] **Step 4: Implement** — `schedule_core.gd` thêm 2 static method; `repair_session._add_minutes` đúng Interfaces (advance LUÔN chạy, forced gộp budget + SUMMARIZE); `repair_panel.open_new_order` gate đầu hàm.

- [ ] **Step 5: GREEN + amend `test_repair_panel.gd` + gate**

Amend `test_repair_panel.gd` — thêm ngay sau `var state = ...new()`:

```gdscript
	state.advance_to(1020)  # T2 17:00 — vao slot REPAIR de panel duoc phep tao don
```

Run: run_one `test_shift_budget.gd`, `test_repair_gate.gd`, `test_repair_panel.gd`, `test_repair_session.gd` → tất cả `FAILURES=0`; `bash repair-shop-game/tests/run_suite.sh` → `GATE PASS`
(Nếu `test_repair_panel` cháy budget giữa chừng do test tự burn >120′: thêm `state.shift_used = 0` tại vị trí test mở đơn kế — chỉ trong file test này.)

- [ ] **Step 6: Commit**

```bash
git add repair-shop-game/scripts/schedule_core.gd repair-shop-game/scripts/repair/repair_session.gd repair-shop-game/scripts/ui/repair_panel.gd repair-shop-game/tests/test_shift_budget.gd repair-shop-game/tests/test_repair_gate.gd repair-shop-game/tests/test_repair_panel.gd repair-shop-game/tests/run_tests.gd
git commit -m "feat: budget ca sửa + LOST_TIME + gate open_new_order theo khung giờ"
```

---

### Task 6: Panel SUMMARIZE + rollover + phạt học đường

**Files:**
- Create: `repair-shop-game/scenes/ui/summarize.tscn`, `repair-shop-game/scripts/ui/summarize.gd`
- Modify: `repair-shop-game/scripts/ui/hud.gd` (instantiate summarize khi `mode == SUMMARIZE`)
- Test: `repair-shop-game/tests/test_day_end.gd`, `repair-shop-game/tests/test_school_penalty.gd`
- Modify: `repair-shop-game/tests/run_tests.gd`

**Interfaces:**
- Consumes: `GameState.end_day/begin_new_day/school_minutes_done/today_activities/money` (T3), `ScheduleCore.available` (T4 — không dùng ở đây), HUD `_build_ui` pattern.
- Produces (T7 phụ tham chiếu):
  - `summarize.gd` (CanvasLayer, `_build_ui()`): node `Root/LblSummary` (multiline label), `Root/BtnSleep` ("Ngủ → ngày kế").
  - `func setup(gs: Node) -> void` — dựng UI + `refresh()`: text liệt kê `today_activities` (mỗi dòng `label — phút′`), dòng tiền `money`, dòng phạt `Phạt học đường: −10 ky_luat` (nếu `450 - school_minutes_done() > 0`, công thức Task 3); nút bấm → `gs.begin_new_day()` (HUD tự ẩn panel qua signal `schedule_changed` — summarize standalone trong test không có HUD vẫn an toàn).
  - `hud.gd`: trong `setup()` nối `game_state.schedule_changed.connect(refresh)` (guard `is_connected`; test standalone không có parent HUD vẫn an toàn — handler của HUD xử lý toggle); trong `refresh()`, khi `mode == SUMMARIZE` → hiện node summarize (instantiate 1 lần, cache), ẩn activity box; ngược lại ẩn summarize. (Connection này T7 dùng lại, guard khiến idempotent.)
  - Nhóm `"summarize"` không cần thiết — test gọi trực tiếp `setup/refresh`.

- [ ] **Step 1: Viết test đỏ `tests/test_day_end.gd`**

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var gs = load("res://scripts/autoload/game_state.gd").new()
	var packed := load("res://scenes/ui/summarize.tscn") as PackedScene
	check(packed != null, "summarize.tscn loads")
	if packed == null:
		return
	var s = packed.instantiate()
	s.setup(gs)
	check(s.has_node("Root/LblSummary"), "summary label")
	check(s.has_node("Root/BtnSleep"), "sleep button")

	# ngay moi: 3 hoat dong + 20 phut hoc
	gs.today_activities = [
		{"id": "di_hoc", "label": "Đi học", "minutes": 20},
		{"id": "nghi_ngoi", "label": "Nghỉ ngơi", "minutes": 120},
		{"id": "doc_thu_vien", "label": "Đọc thư viện", "minutes": 135},
	]
	gs.advance_to(1320)
	check_eq(int(gs.mode), int(load("res://scripts/autoload/game_state.gd").GameStateMode.SUMMARIZE), "mode SUMMARIZE")
	s.refresh()
	var lbl = s.get_node("Root/LblSummary") as Label
	check(String(lbl.text).contains("Đi học"), "lists activities")
	check(String(lbl.text).contains("Nghỉ ngơi"), "lists all")
	var day_before = int(gs.date["day"])
	var ky_before = int(gs.ky_luat)
	(s.get_node("Root/BtnSleep") as Button).pressed.emit()
	check_eq(int(gs.date["day"]), day_before + 1, "date +1")
	check_eq(int(gs.minute), 420, "minute 07:00")
	check_eq(int(gs.mode), int(load("res://scripts/autoload/game_state.gd").GameStateMode.SCHEDULE), "SCHEDULE after sleep")
	check_eq(int(gs.shift_used), 0, "shift reset")
	check_eq(int(gs.ky_luat), ky_before - 10, "penalty -10 for 430 missing")
	s.free()
```

(Phạt: thiếu `450-20=430` → `ceil(430/450)=1` → −10.)

- [ ] **Step 2: Viết test đỏ `tests/test_school_penalty.gd`**

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var gs = load("res://scripts/autoload/game_state.gd").new()
	# du hoc (450) -> khong phat
	gs.today_activities = [{"id": "di_hoc", "label": "Đi học", "minutes": 450}]
	check_eq(gs.school_minutes_done(), 450, "done 450")
	var ky0: int = int(gs.ky_luat)
	gs.begin_new_day()
	check_eq(int(gs.ky_luat), ky0, "full school no penalty")
	# thieu dung 450 -> -10
	gs.today_activities = []
	var ky1: int = int(gs.ky_luat)
	gs.begin_new_day()
	check_eq(int(gs.ky_luat), ky1 - 10, "missing 450 -> -10")
	# thieu 449 (du 1 phut di hoc) van -10 (ceil(449/450)=1)
	gs.today_activities = [{"id": "di_hoc", "label": "Đi học", "minutes": 1}]
	check_eq(gs.school_minutes_done(), 1, "done 1")
	var ky2: int = int(gs.ky_luat)
	gs.begin_new_day()
	check_eq(int(gs.ky_luat), ky2 - 10, "missing 449 -> -10")
	# vuot qua expected -> khong am
	gs.today_activities = [{"id": "di_hoc", "label": "Đi học", "minutes": 451}]
	check_eq(gs.school_minutes_done(), 451, "done 451")
	var ky3: int = int(gs.ky_luat)
	gs.begin_new_day()
	check_eq(int(gs.ky_luat), ky3, "over-complete no penalty")
```

(Lưu ý implementer: với `expected = 450` và `thiếu = max(0, 450-done)`, công thức `10*ceil(thiếu/450.0)` chỉ cho kết quả 0 hoặc −10 — `thiếu` không bao giờ >450. Không có case −20 trong cycle 1.)

- [ ] **Step 3: Chạy 2 test — verify RED**

- [ ] **Step 4: Implement** — `summarize.tscn` (root CanvasLayer + script, `load_steps=2` như `repair_panel.tscn`), `summarize.gd` theo Interfaces; `hud.gd` cache + toggle trong `refresh()`.

- [ ] **Step 5: Chạy — verify GREEN** rồi đăng ký + gate + smoke**

Run: run_one 2 test → `FAILURES=0`; gate → `GATE PASS`; smoke `--quit-after 60` main.tscn → không `SCRIPT ERROR`

- [ ] **Step 6: Commit**

```bash
git add repair-shop-game/scenes/ui/summarize.tscn repair-shop-game/scripts/ui/summarize.gd repair-shop-game/scripts/ui/hud.gd repair-shop-game/tests/test_day_end.gd repair-shop-game/tests/test_school_penalty.gd repair-shop-game/tests/run_tests.gd
git commit -m "feat: panel SUMMARIZE + begin_new_day + phat hoc duong"
```

---

### Task 7: HUD panel hoạt động + nhãn budget + `mo_panel`

**Files:**
- Modify: `repair-shop-game/scripts/ui/hud.gd`, `repair-shop-game/scripts/ui/repair_panel.gd` (group)
- Test: `repair-shop-game/tests/test_hud_activity.gd`
- Modify: `repair-shop-game/tests/run_tests.gd`

**Interfaces:**
- Consumes: `ScheduleCore.available/reason_for/try_activity` (T4), `shift_budget/shift_tick` (T5), `GameState.shift_used/mode`, HUD `_build_ui` + `refresh()` hiện có.
- Produces:
  - `hud.gd`: `_build_ui()` thêm `Root/ActivityBox` (VBox, bottom-left `position (16, 560)`), `Root/LblBudget` (Label, cạnh TimeLabel). `setup()` nối `game_state.schedule_changed.connect(refresh)` (guard `is_connected` — `setup` có thể gọi 2 lần, test_hud cũ đã làm vậy; T3 signal — phút sửa trong RepairSession tự update HUD, không cần F6). `refresh()` tái tạo nút trong `ActivityBox` từ `ScheduleCore.available(game_state)` — mỗi activity 1 `Button` tên `Btn_<id>`, text `label`; `reason_for != ""` → `disabled = true` + `tooltip_text = reason`; bấm (enabled) → `ScheduleCore.try_activity(game_state, id)` rồi `refresh()`. Ẩn `ActivityBox` + `LblBudget` khi `mode != SCHEDULE`. `LblBudget` hiện `Ca còn %d/%d'` (`shift_budget - shift_used` / `shift_budget`) chỉ khi `ScheduleLogic.is_repair_slot(...)`; nút `mo_panel` bấm → `get_tree()` null-guard rồi `get_first_node_in_group("repair_panel")` gọi `_on_open()` (null thì bỏ qua — test headless không ở trong tree).
  - `repair_panel.gd` `_ready()`: `add_to_group("repair_panel")`.

- [ ] **Step 1: Viết test đỏ `tests/test_hud_activity.gd`**

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var packed = load("res://scenes/ui/hud.tscn") as PackedScene
	check(packed != null, "hud loads")
	if packed == null:
		return
	var hud = packed.instantiate()
	var gs = load("res://scripts/autoload/game_state.gd").new()
	hud.setup(gs, null)
	check(hud.has_node("Root/ActivityBox"), "ActivityBox exists")
	check(hud.has_node("Root/LblBudget"), "budget label exists")

	# T2 07:00 workshop: 1 nut, disabled (khong o lop)
	gs.current_location = "workshop"
	hud.refresh()
	var box = hud.get_node("Root/ActivityBox")
	check(box.has_node("Btn_di_hoc"), "di_hoc button in SCHOOL")
	check_eq(box.get_child_count(), 1, "exactly 1 button after refresh")
	hud.refresh()
	check_eq(hud.get_node("Root/ActivityBox").get_child_count(), 1, "no duplicate buttons on re-refresh")
	var b = box.get_node("Btn_di_hoc") as Button
	check_eq(b.disabled, true, "disabled wrong location")
	check(String(b.tooltip_text).contains("classroom"), "tooltip location")

	# sang lop -> enable
	gs.current_location = "classroom"
	hud.refresh()
	b = hud.get_node("Root/ActivityBox/Btn_di_hoc") as Button
	check_eq(b.disabled, false, "enabled at classroom")
	check_eq(String(hud.get_node("Root/LblBudget").text), "", "budget hidden outside repair")

	# 17:00 — advance_to KHONG goi refresh thu cong, HUD tu update qua schedule_changed
	gs.current_location = "workshop"
	gs.advance_to(1020)
	check(hud.get_node("Root/ActivityBox").has_node("Btn_mo_panel"), "mo_panel auto-refreshed in REPAIR")
	check(String(hud.get_node("Root/LblBudget").text).contains("120"), "budget label 120")

	# nhat don: bnut mo_panel -> try ok, minute khong doi
	var m0: int = int(gs.minute)
	var r = load("res://scripts/schedule_core.gd").try_activity(gs, "mo_panel")
	check_eq(r.ok, true, "mo_panel try ok")
	check_eq(int(gs.minute), m0, "minute unchanged")

	# REPAIR mode -> an panel
	gs.mode = load("res://scripts/autoload/game_state.gd").GameStateMode.REPAIR
	hud.refresh()
	check_eq(hud.get_node("Root/ActivityBox").visible, false, "hidden in REPAIR")
	hud.free()
```

- [ ] **Step 2: Chạy — verify RED**

- [ ] **Step 3: Implement** — theo Interfaces; tái tạo ActivityBox mỗi `refresh()` (clear children cũ, tránh node nhân đôi).

- [ ] **Step 4: Chạy — verify GREEN** rồi gate + smoke (HUD là node trong `main.tscn` → smoke áp dụng)

- [ ] **Step 5: Commit**

```bash
git add repair-shop-game/scripts/ui/hud.gd repair-shop-game/scripts/ui/repair_panel.gd repair-shop-game/tests/test_hud_activity.gd repair-shop-game/tests/run_tests.gd
git commit -m "feat: HUD activity panel + budget label + mo_panel"
```

---

### Task 8: `change_map` advisory (Q2) + amend `test_map_gating`

**Files:**
- Modify: `repair-shop-game/scripts/autoload/scene_manager.gd`
- Test (amend): `repair-shop-game/tests/test_map_gating.gd`

**Interfaces:**
- Consumes: `gs.can_enter(loc)` (vẫn giữ nguyên trên GameState).
- Produces: `change_map(...) -> bool` **luôn đổi map thành công** khi `loc` hợp lệ (trả `true`); nếu `gs.can_enter(loc) == false` → `push_warning("change_map: %s ngoài khung giờ (advisory)" % loc)` nhưng **vẫn vào**. Chỉ `loc` lạ/load fail → `false`.

- [ ] **Step 1: Amend test đỏ `test_map_gating.gd`** — đổi assertion deny → allow-warning:

```gdscript
	# luc 07:00 SCHOOOL: khong con chan — advisory (Q2)
	var before: int = main.get_child_count()
	var ok2 = sm.change_map(main, player, "cafe", gs)
	check_eq(ok2, true, "advisory: cafe allowed in school slot")
	check(main.has_node("Cafe"), "Cafe swapped in")
	check_eq(gs.current_location, "cafe", "location updated advisory")
	check_eq(main.get_child_count(), before, "child count stable")

	gs.advance_to(690)
	check_eq(sm.change_map(main, player, "schoolyard", gs), true, "advisory: schoolyard at CHOICE")
	check(main.has_node("Schoolyard"), "Schoolyard present")
	check_eq(sm.change_map(main, player, "xxx", gs), false, "invalid loc still false")

	# source pin
	var f = FileAccess.open("res://scripts/autoload/scene_manager.gd", FileAccess.READ)
	check(f != null and f.get_as_text().contains("-> bool"), "change_map returns bool")
	check(f != null and f.get_as_text().contains("can_enter"), "still consults can_enter (warning)")
	check(f != null and f.get_as_text().contains("push_warning"), "advisory warns")
```

(Giữ nguyên block đầu `allow gate in school slot` + block CHOICE allow; chỉ đổi 2 block deny + pin.)

- [ ] **Step 2: Chạy — verify RED** (deny vẫn false → fail "advisory: cafe allowed")

- [ ] **Step 3: Implement `change_map`** — bỏ nhánh `return false` khi `can_enter` false; thay bằng `push_warning` rồi tiếp tục load/swap.

- [ ] **Step 4: Chạy — verify GREEN** (run_one `test_map_gating.gd` + `test_scene_manager.gd` + `test_game_state_time.gd`) rồi gate

- [ ] **Step 5: Commit**

```bash
git add repair-shop-game/scripts/autoload/scene_manager.gd repair-shop-game/tests/test_map_gating.gd
git commit -m "feat: change_map advisory theo Q2 — warning thay vi chan"
```

---

### Task 9: Gate toàn bộ + smoke + đối chiếu spec

**Files:**
- Modify (nếu cần fixup): file nào gate bắt lỗi
- Test: không tạo mới

**Interfaces:** — (verification task)

- [ ] **Step 1: Chạy gate全套**

Run: `bash repair-shop-game/tests/run_suite.sh` → `TOTAL_FAILURES=0` + `GATE PASS`

- [ ] **Step 2: Smoke main**

Run: `godot --headless --path repair-shop-game --quit-after 60 res://scenes/main.tscn > /tmp/smoke.log 2>&1; grep -c "SCRIPT ERROR" /tmp/smoke.log`
Expected: `0` (rc grep = 1 khi không có match — chấp nhận; fail chỉ khi xuất hiện `SCRIPT ERROR`)

- [ ] **Step 3: Đối chiếu spec**

So 1-1 spec §4.1 (bảng activities), §5 (budget/gate), §6 (SUMMARIZE/phạt), §9 (5 test amend — `test_clock_timer`, `test_hud`, `test_game_state_time`, `test_repair_panel`, `test_map_gating`) — nếu thiếu gì → sửa + gate lại.

- [ ] **Step 4: Commit fixup (nếu có)**

```bash
git add <file fixup>
git commit -m "fix: hoan thien schedule engine theo spec"
```
