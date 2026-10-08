# Week Schedule (Lịch tuần) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trợ thi Spec 3 — lịch tuần 7 ngày + ngày lễ (Resource), state thời gian trong GameState, đồng hồ Hybrid, gating địa điểm 2 mức, HUD giờ + màn hình lịch tuần (Tab).

**Architecture:** `WeekSchedule` Resource sinh bằng tool (`ResourceSaver`, không viết tay `.tres`) + `ScheduleLogic` static thuần (DI, không autoload) + GameState thêm `date/minute/mode` với `advance_to/end_day` + `ClockTimer` node tick thật chỉ khi `mode==REPAIR` + `change_map -> bool` gating + 2 CanvasLayer UI theo pattern `repair_panel` (tscn tối giản, `_build_ui()` programmatic).

**Tech Stack:** Godot 4.7.2 headless, GDScript, test framework `test_case.gd` (check/check_eq/check_near).

**Spec:** `docs/superpowers/specs/2026-10-08-week-schedule-design.md` (kèm Amendment §11 locations 7/7 map — bảng locations trong spec là nguồn dữ liệu đúng, đã sửa gate/classroom/street).

## Global Constraints

- **Gate:** `bash repair-shop-game/tests/run_suite.sh` phải ra `TOTAL_FAILURES=0` VÀ `GATE PASS`. Output chứa `SCRIPT ERROR` = fail kể cả TOTAL=0. Gate đỏ thì **không commit**.
- **Run single test:** `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/<ten_test>.gd` (helper tạo ở Task 1) → dòng `FAILURES=0` là pass.
- **Smoke** (Task sửa `main.tscn`): `godot --headless --path repair-shop-game --quit-after 60 res://scenes/main.tscn > /tmp/smoke.log 2>&1` rồi grep `SCRIPT ERROR` trong `/tmp/smoke.log` phải rỗng, rc=0. **macOS không có lệnh `timeout`** — đừng dùng.
- **Harness `-s` không có autoload** (`Engine.get_main_loop()==null`) → test tự `load("res://scripts/autoload/game_state.gd").new()`, tuyệt đối không identifier toàn cục `GameState`.
- **Đường dẫn repo có unicode** (`file nhảy cảm`) → mọi read/write file qua `python3` heredoc trong `bash`, không dùng file-tool trực tiếp.
- **Không sửa file session NPC:** `chibi-model/*`, `tests/test_npc_import.gd`.
- **GDScript:** `:=` infer từ Variant = parse error → luôn khai báo kiểu tường minh (`var x: int = f()`); test dùng `check/check_eq/check_near` của `test_case.gd`.
- **UI pattern:** `.tscn` chỉ có root CanvasLayer + script (như `repair_panel.tscn`), nodes dựng trong `_build_ui()`; test gọi `setup(...)` rồi `has_node("Root/...")`.
- **Debug keys** dùng hằng `KEY_F5/KEY_F6/KEY_F7/KEY_TAB` (không magic number).
- Commit từng task, message theo repo (`feat:`/`test:`/`docs:`). Không sửa test của task khác trừ step chỉ rõ.

## Review Focus

Spec im lặng nhưng người chơi dễ gặp — mỗi dòng có test trong task sở hữu:

1. **Boundary phút** (11:29/11:30, 13:44/13:45, 16:59/17:00, 21:59/22:00, 06:59/07:00): slot đổi đúng mốc, không khe hở, ngoài khung = null. → Task 1, test `test_schedule_logic.gd` (boundary block).
2. **Ngày lễ override ngày thường đúng thứ:** 30-04-2026 = T5 → cả ngày HOLIDAY thay SCHOOL; Tết khớp format `YYYY-MM-DD`; 01-05-2026 KHÔNG phải ngày lễ. → Task 1, test `test_schedule_logic.gd` (holiday block).
3. **end_day qua biên tháng/năm:** 31/10→01/11, 31/12→01/01, weekday tính tiếp đúng. → Task 3, test `test_game_state_time.gd`.
4. **Tick qua 22:00 khi `mode==REPAIR`:** `end_day` tự kích hoạt, mode về SCHEDULE, vòng `while` dừng — KHÔNG tick tiếp vào 07:00 sáng hôm sau. → Task 5, test `test_clock_timer.gd`.
5. **change_map deny** trả `false` và scene giữ nguyên (không mất map giữa chừng), allow trả `true`; CHOICE cho library/cafe/street/gate, deny schoolyard. → Task 4, test `test_map_gating.gd`.

---

### Task 1: WeekSchedule data + ScheduleLogic core + run_one helper + sinh .tres

**Files:**
- Create: `repair-shop-game/tests/run_one.gd`
- Create: `repair-shop-game/tests/test_schedule_logic.gd`
- Create: `repair-shop-game/scripts/data/time_slot.gd`
- Create: `repair-shop-game/scripts/data/day_schedule.gd`
- Create: `repair-shop-game/scripts/data/week_schedule.gd`
- Create: `repair-shop-game/scripts/schedule_logic.gd`
- Create: `repair-shop-game/tools/build_week_schedule.gd`
- Create: `repair-shop-game/data/week_schedule.tres` (sinh bởi tool)
- Modify: `repair-shop-game/tests/run_tests.gd` (đăng ký test cuối task)

**Interfaces:**
- Consumes: `test_case.gd` (`check/check_eq`), bảng slot §2 spec (đã amendment: SCHOOL `[schoolyard, classroom, gate]`, CHOICE `[library, cafe, street, gate]`, REPAIR `[workshop, street, gate]`).
- Produces:
  - `TimeSlot { start_minute: int, end_minute: int, kind: String, locations: Array[String], repair: bool }`
  - `DaySchedule { slots: Array[TimeSlot] }`
  - `WeekSchedule { days: Array[DaySchedule], holidays: PackedStringArray }` — `days[0]`=T2 … `days[6]`=CN
  - `ScheduleLogic.weekday(date: Dictionary) -> int` (1=T2..7=CN)
  - `ScheduleLogic.is_holiday(week, date) -> bool`
  - `ScheduleLogic.slots_for_day(week, date) -> Array` (holiday → mảng 1 slot HOLIDAY tự sinh `420..1320 [workshop]`)
  - `ScheduleLogic.current_slot(week, date, minute: int) -> Resource` (null ngoài 07:00–22:00; `end_minute` exclusive)
  - `res://data/week_schedule.tres` + tool `tools/build_week_schedule.gd`

- [ ] **Step 1: Viết `tests/run_one.gd` (single-test runner, an toàn parse error)**

```gdscript
extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 1:
		print("usage: -s res://tests/run_one.gd -- <test_path>")
		quit(1)
		return
	var script = load(args[0])
	if script == null or not (script is Script) or not (script as Script).can_instantiate():
		print("FAIL load: ", args[0])
		quit(1)
		return
	var case = script.new()
	case.run()
	print("FAILURES=", case.failures.size())
	for x in case.failures:
		print("FAIL: ", x)
	quit(0 if case.failures.is_empty() else 1)
```

- [ ] **Step 2: Chạy trên test có sẵn — verify hoạt động**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_scene_manager.gd`
Expected: `FAILURES=0`, rc=0.

- [ ] **Step 3: Viết test đỏ `tests/test_schedule_logic.gd`**

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var week = load("res://data/week_schedule.tres")
	check(week != null, "week_schedule.tres loads")
	if week == null:
		return
	check_eq(week.days.size(), 7, "7 days")
	check(week.holidays.size() >= 3, "3+ holidays")

	# weekday
	check_eq(ScheduleLogic.weekday({"year": 2026, "month": 10, "day": 5}), 1, "2026-10-05 Mon=1")
	check_eq(ScheduleLogic.weekday({"year": 2026, "month": 10, "day": 11}), 7, "2026-10-11 Sun=7")
	check_eq(ScheduleLogic.weekday({"year": 2026, "month": 4, "day": 30}), 4, "2026-04-30 Thu=4")

	var mon := {"year": 2026, "month": 10, "day": 5}
	# boundary
	var s419 = ScheduleLogic.current_slot(week, mon, 419)
	check(s419 == null, "06:59 null")
	var s420 = ScheduleLogic.current_slot(week, mon, 420)
	check(s420 != null and String(s420.kind) == "SCHOOL", "07:00 SCHOOL")
	var s689 = ScheduleLogic.current_slot(week, mon, 689)
	check(s689 != null and String(s689.kind) == "SCHOOL", "11:29 SCHOOL")
	var s690 = ScheduleLogic.current_slot(week, mon, 690)
	check(s690 != null and String(s690.kind) == "CHOICE", "11:30 CHOICE")
	var s824 = ScheduleLogic.current_slot(week, mon, 824)
	check(s824 != null and String(s824.kind) == "CHOICE", "13:44 CHOICE")
	var s825 = ScheduleLogic.current_slot(week, mon, 825)
	check(s825 != null and String(s825.kind) == "SCHOOL", "13:45 SCHOOL")
	var s1019 = ScheduleLogic.current_slot(week, mon, 1019)
	check(s1019 != null and String(s1019.kind) == "SCHOOL", "16:59 SCHOOL")
	var s1020 = ScheduleLogic.current_slot(week, mon, 1020)
	check(s1020 != null and String(s1020.kind) == "REPAIR", "17:00 REPAIR")
	var s1140 = ScheduleLogic.current_slot(week, mon, 1140)
	check(s1140 != null and String(s1140.kind) == "PROJECT", "19:00 PROJECT")
	var s1319 = ScheduleLogic.current_slot(week, mon, 1319)
	check(s1319 != null and String(s1319.kind) == "PROJECT", "21:59 PROJECT")
	var s1320 = ScheduleLogic.current_slot(week, mon, 1320)
	check(s1320 == null, "22:00 null")

	# T3: 17:00 FREE_HOME (khong REPAIR), 19:00 PROJECT
	var tue := {"year": 2026, "month": 10, "day": 6}
	var t3a = ScheduleLogic.current_slot(week, tue, 1020)
	check(t3a != null and String(t3a.kind) == "FREE_HOME", "T3 17:00 FREE_HOME")
	var t3b = ScheduleLogic.current_slot(week, tue, 1140)
	check(t3b != null and String(t3b.kind) == "PROJECT", "T3 19:00 PROJECT")

	# CN (2026-10-11)
	var sun := {"year": 2026, "month": 10, "day": 11}
	var c0 = ScheduleLogic.current_slot(week, sun, 420)
	check(c0 != null and String(c0.kind) == "FREE_HOME", "CN 07:00 FREE_HOME")
	var c1 = ScheduleLogic.current_slot(week, sun, 540)
	check(c1 != null and String(c1.kind) == "REPAIR", "CN 09:00 REPAIR")
	var c2 = ScheduleLogic.current_slot(week, sun, 720)
	check(c2 != null and String(c2.kind) == "BREAK", "CN 12:00 BREAK")
	var c3 = ScheduleLogic.current_slot(week, sun, 810)
	check(c3 != null and String(c3.kind) == "REPAIR", "CN 13:30 REPAIR")
	var c4 = ScheduleLogic.current_slot(week, sun, 1140)
	check(c4 != null and String(c4.kind) == "PROJECT", "CN 19:00 PROJECT")

	# holiday — 30-04-2026 (T5, MM-DD)
	var hol := {"year": 2026, "month": 4, "day": 30}
	check(ScheduleLogic.is_holiday(week, hol), "04-30 is holiday")
	var hs = ScheduleLogic.slots_for_day(week, hol)
	check_eq(hs.size(), 1, "holiday -> 1 slot")
	check(String(hs[0].kind) == "HOLIDAY", "holiday kind HOLIDAY")
	var hm = ScheduleLogic.current_slot(week, hol, 480)
	check(hm != null and String(hm.kind) == "HOLIDAY", "holiday overrides morning SCHOOL")
	# Tet 2026-02-17 (YYYY-MM-DD)
	var tet := {"year": 2026, "month": 2, "day": 17}
	check(ScheduleLogic.is_holiday(week, tet), "Tet YYYY-MM-DD matches")
	var may1 := {"year": 2026, "month": 5, "day": 1}
	check(not ScheduleLogic.is_holiday(week, may1), "01-05 not holiday")
```

- [ ] **Step 4: Chạy test — verify RED**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_schedule_logic.gd`
Expected: `FAIL load:` (script/test chưa tồn tại hoặc `ScheduleLogic` chưa parse) — hoặc `FAILURES>0` với `week_schedule.tres loads`.

- [ ] **Step 5: Implement data + logic + generator**

- `scripts/data/time_slot.gd`: `class_name TimeSlot extends Resource` với 5 var đúng Interface.
- `scripts/data/day_schedule.gd`: `class_name DaySchedule extends Resource`, `var slots: Array[TimeSlot] = []`.
- `scripts/data/week_schedule.gd`: `class_name WeekSchedule extends Resource`, `var days: Array[DaySchedule] = []`, `var holidays: PackedStringArray = PackedStringArray()`.
- `scripts/schedule_logic.gd`: `class_name ScheduleLogic extends RefCounted`, static:
  - `weekday` → nếu `Time.get_date_day_of_week(date)` không tồn tại trên 4.7 thì tính thủ công từ epochknown (test 2026-10-05=1, 2026-10-11=7, 2026-04-30=4 quyết định đúng/sai).
  - `is_holiday` → so `week.holidays` với `"%02d-%02d" % [month, day]` và `"%04d-%02d-%02d"` (3 format key đầy đủ).
  - `slots_for_day` → holiday trả mảng `[TimeSlot(420,1320,"HOLIDAY",["workshop"],false)]` (tự sinh mới mỗi lần gọi); else `week.days[weekday(date) - 1].slots`.
  - `current_slot` → duyệt mọi slot, `minute >= start and minute < end` thì trả; không khớp → `null`.
- `tools/build_week_schedule.gd`: `extends SceneTree`, build đúng bảng §2 spec (T2..T7 cùng rows; T3 khác 1 dòng; CN khác), `ResourceSaver.save(week, "res://data/week_schedule.tres")`, print `WROTE ... err=`, `quit`. Dùng helper `_slot(s, e, kind, locs, repair=false)` + `_day(rows)`, `week.days.append(...)` 7 lần, `week.holidays.assign(["04-30", "09-02", "2026-02-17"])`, `t.locations.assign(locs)` để khỏi lỗi typed-array.

Bảng rows chính xác (đã amendment §11):
- T2,T4,T5,T6,T7 (index 0,2,3,4,5): `420-690 SCHOOL [schoolyard, classroom, gate]` · `690-825 CHOICE [library, cafe, street, gate]` · `825-1020 SCHOOL [schoolyard, classroom, gate]` · `1020-1140 REPAIR [workshop, street, gate] repair=true` · `1140-1320 PROJECT [workshop]`
- T3 (index 1): như trên nhưng `1020-1140 FREE_HOME [workshop]` (repair=false)
- CN (index 6): `420-540 FREE_HOME [workshop]` · `540-720 REPAIR [workshop, street] repair=true` · `720-810 BREAK [workshop]` · `810-1140 REPAIR [workshop, street] repair=true` · `1140-1320 PROJECT [workshop]`

- [ ] **Step 6: Chạy generator rồi chạy test — verify GREEN**

Run: `godot --headless --path repair-shop-game -s res://tools/build_week_schedule.gd`
Expected: `WROTE res://data/week_schedule.tres err=0`
Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_schedule_logic.gd`
Expected: `FAILURES=0`

- [ ] **Step 7: Đăng ký test vào `run_tests.gd` + chạy gate**

Thêm `"res://tests/test_schedule_logic.gd",` vào `TEST_SCRIPTS`.
Run: `bash repair-shop-game/tests/run_suite.sh`
Expected: `TOTAL_FAILURES=0` + `GATE PASS`, không `SCRIPT ERROR`.

- [ ] **Step 8: Commit**

```bash
git add repair-shop-game/tests/run_one.gd repair-shop-game/tests/test_schedule_logic.gd repair-shop-game/tests/run_tests.gd repair-shop-game/scripts/data/ repair-shop-game/scripts/schedule_logic.gd repair-shop-game/tools/build_week_schedule.gd repair-shop-game/data/week_schedule.tres
git commit -m "feat: week schedule data + ScheduleLogic core"
```

---

### Task 2: ScheduleLogic gating 2 mức (allowed_locations / can_enter / is_repair_slot)

**Files:**
- Modify: `repair-shop-game/scripts/schedule_logic.gd`
- Modify: `repair-shop-game/tests/test_schedule_logic.gd` (append vào cuối `run()`)

**Interfaces:**
- Consumes: Task 1 (`current_slot`, `week`, `date`, `minute`).
- Produces:
  - `ScheduleLogic.allowed_locations(week, date, minute: int) -> Array` — `[]` khi ngoài khung / slot null (fail-closed); ngược lại `slot.locations` copy.
  - `ScheduleLogic.can_enter(week, date, minute: int, loc: String) -> bool`
  - `ScheduleLogic.is_repair_slot(week, date, minute: int) -> bool` — true khi `slot.kind=="REPAIR" and slot.repair`

- [ ] **Step 1: Append test đỏ (cuối `run()`, sau block holiday)**

```gdscript
	# --- Task 2: gating 2 muc ---
	var l_school = ScheduleLogic.allowed_locations(week, mon, 600)
	check_eq(l_school.size(), 3, "SCHOOL 3 places")
	check(l_school.has("schoolyard") and l_school.has("classroom") and l_school.has("gate"), "SCHOOL list")
	var l_choice = ScheduleLogic.allowed_locations(week, mon, 690)
	check_eq(l_choice.size(), 4, "CHOICE 4 places")
	check(l_choice.has("library") and l_choice.has("cafe") and l_choice.has("street") and l_choice.has("gate"), "CHOICE list")
	var l_rep = ScheduleLogic.allowed_locations(week, mon, 1020)
	check(l_rep.has("workshop") and l_rep.has("street") and l_rep.has("gate"), "REPAIR weekday list")
	var l_cn = ScheduleLogic.allowed_locations(week, sun, 540)
	check(l_cn.size() == 2 and l_cn.has("workshop") and l_cn.has("street"), "REPAIR CN list (no gate)")
	check(ScheduleLogic.is_repair_slot(week, mon, 1020), "weekday 17:00 repair")
	check(not ScheduleLogic.is_repair_slot(week, tue, 1020), "T3 17:00 not repair")
	check(ScheduleLogic.is_repair_slot(week, sun, 540), "CN 09:00 repair")
	check(not ScheduleLogic.is_repair_slot(week, mon, 1140), "19:00 not repair")
	check(not ScheduleLogic.is_repair_slot(week, mon, 690), "CHOICE not repair")
	check(ScheduleLogic.can_enter(week, mon, 600, "schoolyard"), "allow schoolyard in school")
	check(not ScheduleLogic.can_enter(week, mon, 600, "cafe"), "deny cafe in school")
	check(ScheduleLogic.can_enter(week, mon, 690, "cafe"), "allow cafe at CHOICE")
	check(not ScheduleLogic.can_enter(week, mon, 690, "schoolyard"), "deny schoolyard at CHOICE")
	var l_out = ScheduleLogic.allowed_locations(week, mon, 419)
	check_eq(l_out.size(), 0, "outside -> empty (fail-closed)")
	check(not ScheduleLogic.can_enter(week, mon, 419, "workshop"), "outside deny all")
	var l_hol = ScheduleLogic.allowed_locations(week, hol, 480)
	check_eq(l_hol.size(), 1, "holiday -> workshop only")
	check(not ScheduleLogic.can_enter(week, hol, 480, "schoolyard"), "holiday deny school")
```

- [ ] **Step 2: Chạy — verify RED**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_schedule_logic.gd`
Expected: `FAILURES>0` (3 lỗi: hàm chưa tồn tại — nếu parse error do identifier thì `FAIL load:` cũng là RED hợp lệ).

- [ ] **Step 3: Implement 3 hàm trong `schedule_logic.gd`**

`allowed_locations` = nếu `current_slot(...) == null` trả `[]`, ngược lại copy `slot.locations` (trả bản copy để caller không mutate data). `can_enter` = `allowed_locations(...).has(loc)`. `is_repair_slot` = slot không null, `String(slot.kind) == "REPAIR"` và `bool(slot.repair)`.

- [ ] **Step 4: Chạy single test + gate — verify GREEN**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_schedule_logic.gd` → `FAILURES=0`
Run: `bash repair-shop-game/tests/run_suite.sh` → `TOTAL_FAILURES=0` + `GATE PASS`

- [ ] **Step 5: Commit**

```bash
git add repair-shop-game/scripts/schedule_logic.gd repair-shop-game/tests/test_schedule_logic.gd
git commit -m "feat: schedule 2-level location gating"
```

---

### Task 3: GameState time state (date / minute / mode / advance_to / end_day)

**Files:**
- Modify: `repair-shop-game/scripts/autoload/game_state.gd`
- Create: `repair-shop-game/tests/test_game_state_time.gd`
- Modify: `repair-shop-game/tests/run_tests.gd`

**Interfaces:**
- Consumes: Task 1 (`WeekSchedule`, `ScheduleLogic`, `res://data/week_schedule.tres`).
- Produces (task sau dùng nguyên trạng):
  - `enum GameStateMode { SCHEDULE, REPAIR, MINIGAME, SUMMARIZE }`
  - `var mode: int = GameStateMode.SCHEDULE`
  - `var date: Dictionary = {"year": 2026, "month": 10, "day": 5}` (T2)
  - `var minute: int = 420`
  - `var week: WeekSchedule = preload("res://data/week_schedule.tres")`
  - `func slot() -> Resource` · `func advance_to(m: int) -> void` · `func end_day() -> void` · `func can_enter(loc: String) -> bool`

- [ ] **Step 1: Viết test đỏ `tests/test_game_state_time.gd`**

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var gs = gs_script.new()
	check_eq(gs.minute, 420, "start 07:00")
	check_eq(gs.date["year"], 2026, "start year")
	check_eq(gs.date["month"], 10, "start month")
	check_eq(gs.date["day"], 5, "start Mon Oct 5")
	check_eq(gs.mode, gs_script.GameStateMode.SCHEDULE, "start SCHEDULE")
	check(gs.week != null, "week preloaded")
	check_eq(gs.week.days.size(), 7, "week has 7 days")
	check_eq(gs_script.GameStateMode.size(), 4, "4 modes")

	gs.advance_to(690)
	check_eq(gs.minute, 690, "minute advanced")
	var s = gs.slot()
	check(s != null and String(s.kind) == "CHOICE", "11:30 CHOICE")
	check(gs.can_enter("cafe"), "can cafe at CHOICE")
	check(not gs.can_enter("schoolyard"), "deny schoolyard at CHOICE")

	# end_day tu kich hoat luc 22:00
	gs.advance_to(1320)
	check_eq(gs.minute, 420, "reset to 07:00")
	check_eq(gs.date["day"], 6, "date +1")
	check_eq(gs.mode, gs_script.GameStateMode.SCHEDULE, "back to SCHEDULE")

	# bien thang
	gs.date = {"year": 2026, "month": 10, "day": 31}
	gs.advance_to(1320)
	check_eq(gs.date["month"], 11, "Oct -> Nov")
	check_eq(gs.date["day"], 1, "day 1")

	# bien nam
	gs.date = {"year": 2026, "month": 12, "day": 31}
	gs.advance_to(1320)
	check_eq(gs.date["year"], 2027, "Dec 2026 -> Jan 2027")
	check_eq(gs.date["day"], 1, "Jan 1")

	# ngoai khung fail-closed
	gs.minute = 300
	check(gs.slot() == null, "05:00 null slot")
	check(not gs.can_enter("workshop"), "05:00 deny all")
```

- [ ] **Step 2: Chạy — verify RED**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_game_state_time.gd`
Expected: `FAIL load:` hoặc `FAILURES>0` (minute/date/mode chưa có).

- [ ] **Step 3: Implement trong `game_state.gd`**

Thêm enum + 4 var theo Interface (giữ nguyên toàn bộ field hiện có). `slot()` → `ScheduleLogic.current_slot(week, date, minute)`. `advance_to(m)` → `minute = m`; `if minute >= 1320: end_day()`. `end_day()` → `mode = SUMMARIZE`; `date` +1 ngày bằng `Time.get_unix_time_from_datetime_dict` → `Time.get_datetime_dict_from_unix_time` (chỉ giữ year/month/day); `minute = 420`; `mode = SCHEDULE`. `can_enter(loc)` → `ScheduleLogic.can_enter(week, date, minute, loc)`.

Lưu ý: `preload(.tres)` chạy lúc parse script — Task 1 đã commit `.tres`, và mọi test load `game_state.gd` đều qua được.

- [ ] **Step 4: Chạy single + test cũ + gate**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_game_state_time.gd` → `FAILURES=0`
Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_game_state.gd` → `FAILURES=0` (test cũ không vỡ)
Run: `bash repair-shop-game/tests/run_suite.sh` → `TOTAL_FAILURES=0` + `GATE PASS`

- [ ] **Step 5: Đăng ký + Commit**

Thêm `"res://tests/test_game_state_time.gd",` vào `TEST_SCRIPTS`.

```bash
git add repair-shop-game/scripts/autoload/game_state.gd repair-shop-game/tests/test_game_state_time.gd repair-shop-game/tests/run_tests.gd
git commit -m "feat: GameState date/minute/mode + day rollover"
```

---

### Task 4: change_map gating → bool

**Files:**
- Modify: `repair-shop-game/scripts/autoload/scene_manager.gd:21` (`change_map`)
- Create: `repair-shop-game/tests/test_map_gating.gd`
- Modify: `repair-shop-game/tests/run_tests.gd`

**Interfaces:**
- Consumes: Task 3 (`gs.can_enter(loc)`, `gs.advance_to`), Task 1 (`LOCATIONS` 7 map).
- Produces: `static func change_map(parent: Node3D, player: CharacterBody3D, loc: String, gs: Node) -> bool` — `false` khi loc sai / load fail / bị gate; `true` khi swap thành công. Kiểm tra thứ tự: `LOCATIONS.has` → gating (`gs != null and gs.has_method("can_enter") and not bool(gs.call("can_enter", loc))` → `return false`) → load → mutate → trả `true`.

- [ ] **Step 1: Viết test đỏ `tests/test_map_gating.gd`**

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var sm = load("res://scripts/autoload/scene_manager.gd")
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var main = load("res://scenes/main.tscn").instantiate()
	var player = CharacterBody3D.new()
	player.name = "Player"
	player.add_to_group("player")
	main.add_child(player)
	var gs = gs_script.new()

	# T2 07:00 SCHOOL: gate cho phep
	var ok = sm.change_map(main, player, "gate", gs)
	check_eq(ok, true, "allow gate in school slot")
	check(main.has_node("Gate"), "Gate swapped in")
	check(not main.has_node("Workshop"), "Workshop gone")
	check_eq(gs.current_location, "gate", "location updated")

	# deny: cafe luc 07:00 -> false, scene giu nguyen
	var before: int = main.get_child_count()
	var denied = sm.change_map(main, player, "cafe", gs)
	check_eq(denied, false, "deny cafe in school slot")
	check_eq(main.get_child_count(), before, "scene unchanged on deny")
	check(main.has_node("Gate"), "Gate still present")
	check_eq(gs.current_location, "gate", "location unchanged on deny")

	# CHOICE 11:30: cafe allow, schoolyard deny
	gs.advance_to(690)
	check_eq(sm.change_map(main, player, "cafe", gs), true, "allow cafe at CHOICE")
	check(main.has_node("Cafe"), "Cafe present")
	check_eq(sm.change_map(main, player, "schoolyard", gs), false, "deny schoolyard at CHOICE")
	check(main.has_node("Cafe"), "Cafe unchanged after deny")

	# invalid loc van false
	check_eq(sm.change_map(main, player, "xxx", gs), false, "invalid loc false")
	main.free()

	# source pin
	var f = FileAccess.open("res://scripts/autoload/scene_manager.gd", FileAccess.READ)
	check(f != null and f.get_as_text().contains("-> bool"), "change_map returns bool")
	check(f != null and f.get_as_text().contains("can_enter"), "gates via can_enter")
```

- [ ] **Step 2: Chạy — verify RED**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_map_gating.gd`
Expected: `FAILURES>0` — `change_map` hiện trả `void`, `check_eq(null?, true)` fail + gating chưa có.

- [ ] **Step 3: Sửa `change_map` theo Interface (kiểm tra thứ tự ở trên)**

Lưu ý thứ tự: gate-check **trước** load và **trước** vòng xóa map — deny không được phép đụng scene. Trả `false`/`true` ở mọi nhánh.

- [ ] **Step 4: Chạy test mới + test cũ + gate**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_map_gating.gd` → `FAILURES=0`
Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_scene_manager.gd` → `FAILURES=0` (test cũ: gs default T2 07:00 SCHOOL `[schoolyard, classroom, gate]` → `gate` VẪN được phép — bảng amended chính là chốt chặn ở đây)
Run: `bash repair-shop-game/tests/run_suite.sh` → `TOTAL_FAILURES=0` + `GATE PASS`

- [ ] **Step 5: Đăng ký + Commit**

Thêm `"res://tests/test_map_gating.gd",` vào `TEST_SCRIPTS`.

```bash
git add repair-shop-game/scripts/autoload/scene_manager.gd repair-shop-game/tests/test_map_gating.gd repair-shop-game/tests/run_tests.gd
git commit -m "feat: schedule-gated change_map returns bool"
```

---

### Task 5: ClockTimer (hybrid tick + F5/F6/F7)

**Files:**
- Create: `repair-shop-game/scripts/clock_timer.gd`
- Create: `repair-shop-game/tests/test_clock_timer.gd`
- Modify: `repair-shop-game/tests/run_tests.gd`

**Interfaces:**
- Consumes: Task 3 (`gs.mode/mode enum/advance_to/end_day/minute/date`), signal pattern.
- Produces:
  - `class_name ClockTimer extends Node`
  - `signal minute_changed(old_minute: int, new_minute: int)`
  - `const SECONDS_PER_GAME_MINUTE := 1.0`
  - `func setup(gs: Node) -> void` (set `game_state`, pattern `repair_panel.setup`)
  - `func tick(delta: float) -> void` — chỉ chạy khi `game_state.mode == REPAIR`; mỗi `SECONDS_PER_GAME_MINUTE` → `advance_to(minute+1)`; emit `minute_changed`; `while` loop phải break khi mode != REPAIR (sau `end_day`).
  - `_unhandled_input`: `KEY_F5` toggle `mode` SCHEDULE<->REPAIR, `KEY_F6` `advance_to(minute+30)` + emit, `KEY_F7` `end_day()` + emit; bỏ qua `echo` và `not key.pressed`; guard `game_state == null`.
  - `_ready` (game thật): `game_state = get_node_or_null("/root/GameState")`.

- [ ] **Step 1: Viết test đỏ `tests/test_clock_timer.gd`**

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var ct_script = load("res://scripts/clock_timer.gd")
	check(ct_script != null, "clock_timer.gd loads")
	if ct_script == null:
		return
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var gs = gs_script.new()
	var ct = ct_script.new()
	ct.setup(gs)
	var box := [-1, -1]
	ct.minute_changed.connect(func(old_m, new_m): box[0] = old_m; box[1] = new_m)

	# SCHEDULE: khong tick
	ct.tick(5.0)
	check_eq(gs.minute, 420, "no tick in SCHEDULE")

	# REPAIR: 1 game min / SECONDS_PER_GAME_MINUTE
	gs.mode = gs_script.GameStateMode.REPAIR
	ct.tick(2.5)
	check_eq(gs.minute, 422, "2.5s -> +2 min")
	check_eq(box[0], 420, "signal old")
	check_eq(box[1], 422, "signal new")
	check_near(ct._acc, 0.5, 0.001, "acc remainder 0.5")
	ct.tick(1.0)
	check_eq(gs.minute, 423, "remainder + 1s completes a minute")
	check_near(ct._acc, 0.5, 0.001, "acc still 0.5 after full cycle")

	# F5 toggle + release ignore
	var ev = InputEventKey.new()
	ev.keycode = KEY_F5
	ev.pressed = true
	ct._unhandled_input(ev)
	check_eq(gs.mode, gs_script.GameStateMode.SCHEDULE, "F5 press -> SCHEDULE")
	ct.tick(3.0)
	check_eq(gs.minute, 423, "no tick after toggle off")
	ct._unhandled_input(ev)
	check_eq(gs.mode, gs_script.GameStateMode.REPAIR, "F5 press -> REPAIR again")
	ev.pressed = false
	ct._unhandled_input(ev)
	check_eq(gs.mode, gs_script.GameStateMode.REPAIR, "F5 release ignored")

	# F6 +30
	ev.keycode = KEY_F6
	ev.pressed = true
	ct._unhandled_input(ev)
	check_eq(gs.minute, 453, "F6 +30 min")
	check_eq(box[1], 453, "F6 emits")

	# F7 end_day
	ev.keycode = KEY_F7
	ct._unhandled_input(ev)
	check_eq(gs.minute, 420, "F7 -> 07:00")
	check_eq(gs.date["day"], 6, "F7 date +1")
	check_eq(box[1], 420, "F7 emits")

	# tick qua 22:00: end_day, ve SCHEDULE, KHONG tiep tuc (Review Focus #4)
	gs.mode = gs_script.GameStateMode.REPAIR
	gs.minute = 1319
	ct.tick(2.0)
	check_eq(gs.minute, 420, "crossed 22:00 -> 07:00")
	check_eq(gs.date["day"], 7, "date +1 after midnight")
	check_eq(gs.mode, gs_script.GameStateMode.SCHEDULE, "mode SCHEDULE after end_day")
	ct.tick(60.0)
	check_eq(gs.minute, 420, "not ticking after end_day")
	check_eq(gs.date["day"], 7, "date untouched by extra ticks")

	ct.free()
```

- [ ] **Step 2: Chạy — verify RED**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_clock_timer.gd`
Expected: `FAIL load:` (chưa có `clock_timer.gd`).

- [ ] **Step 3: Implement `scripts/clock_timer.gd`**

Theo Interface. Body cốt lõi `tick`:

```gdscript
func tick(delta: float) -> void:
	if game_state == null or game_state.mode != GS.GameStateMode.REPAIR:
		return
	_acc += delta
	while game_state.mode == GS.GameStateMode.REPAIR and _acc >= SECONDS_PER_GAME_MINUTE:
		_acc -= SECONDS_PER_GAME_MINUTE
		var old_m: int = game_state.minute
		game_state.advance_to(old_m + 1)
		minute_changed.emit(old_m, game_state.minute)
```

(`GS` = `const GS = preload("res://scripts/autoload/game_state.gd")` — tránh identifier toàn cục; guard `mode != REPAIR` trong `while` chính là chặn lỗi Review Focus #4.) F6/F7 handler: capture `old_m` trước, gọi `advance_to`/`end_day`, emit `minute_changed`.

- [ ] **Step 4: Chạy single + gate**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_clock_timer.gd` → `FAILURES=0`
Run: `bash repair-shop-game/tests/run_suite.sh` → `TOTAL_FAILURES=0` + `GATE PASS`

- [ ] **Step 5: Đăng ký + Commit**

Thêm `"res://tests/test_clock_timer.gd",` vào `TEST_SCRIPTS`.

```bash
git add repair-shop-game/scripts/clock_timer.gd repair-shop-game/tests/test_clock_timer.gd repair-shop-game/tests/run_tests.gd
git commit -m "feat: hybrid clock timer with F5/F6/F7 debug"
```

---

### Task 6: HUD (giờ + ngày + slot)

**Files:**
- Create: `repair-shop-game/scenes/ui/hud.tscn`
- Create: `repair-shop-game/scripts/ui/hud.gd`
- Create: `repair-shop-game/tests/test_hud.gd`
- Modify: `repair-shop-game/tests/run_tests.gd`

**Interfaces:**
- Consumes: Task 3 (`gs.minute/date/slot()`), Task 1 (`ScheduleLogic.weekday`), signal `minute_changed` Task 5 (optional — `setup(gs, clock)` clock có thể `null`).
- Produces:
  - `hud.tscn`: root `CanvasLayer` tên `HUD` + script (mô hình `repair_panel.tscn`, `load_steps=2`).
  - `func setup(gs: Node, clock: Node = null) -> void` — set state, `_build_ui()` nếu chưa, `refresh()`; nếu `clock != null` → connect `minute_changed` → `refresh()`.
  - `func refresh() -> void` — set `Root/TimeLabel.text = "%02d:%02d · %s · %s"` (giờ từ `minute`, thứ từ weekday, nhãn slot).
  - `static func slot_label(kind: String) -> String` — map: `SCHOOL` "Đi học", `CHOICE` "Tự chọn", `REPAIR` "Ca sửa máy", `FREE_HOME` "Ở nhà", `PROJECT` "Làm project", `BREAK` "Nghỉ", `HOLIDAY` "Ngày lễ", `""` (rỗng/null slot) "Ngoài lịch".
  - Thứ map: 1..7 → `T2,T3,T4,T5,T6,T7,CN`.
  - `_build_ui()`: `Root` (Control full-rect, mouse ignore) chứa `Root/TimeLabel` (Label, position 16,8, font size lớn hơn mặc định không bắt buộc).

- [ ] **Step 1: Viết test đỏ `tests/test_hud.gd`**

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var packed = load("res://scenes/ui/hud.tscn") as PackedScene
	check(packed != null, "hud.tscn loads")
	if packed == null:
		return
	var hud = packed.instantiate()
	check(hud is CanvasLayer, "root CanvasLayer")
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var gs = gs_script.new()
	var hud_script = load("res://scripts/ui/hud.gd")
	hud.setup(gs, null)
	check(hud.has_node("Root/TimeLabel"), "TimeLabel exists")
	var lbl = hud.get_node("Root/TimeLabel") as Label
	check(String(lbl.text).contains("07:00"), "shows 07:00")
	check(String(lbl.text).contains("T2"), "shows Mon T2")
	check(String(lbl.text).contains("Đi học"), "shows school label")

	check_eq(hud_script.slot_label("SCHOOL"), "Đi học", "label SCHOOL")
	check_eq(hud_script.slot_label("CHOICE"), "Tự chọn", "label CHOICE")
	check_eq(hud_script.slot_label("REPAIR"), "Ca sửa máy", "label REPAIR")
	check_eq(hud_script.slot_label("FREE_HOME"), "Ở nhà", "label FREE_HOME")
	check_eq(hud_script.slot_label("PROJECT"), "Làm project", "label PROJECT")
	check_eq(hud_script.slot_label("BREAK"), "Nghỉ", "label BREAK")
	check_eq(hud_script.slot_label("HOLIDAY"), "Ngày lễ", "label HOLIDAY")
	check_eq(hud_script.slot_label(""), "Ngoài lịch", "label empty -> Ngoai lich")

	# ngoai khung
	gs.minute = 300
	hud.refresh()
	check(String(lbl.text).contains("Ngoài lịch"), "outside range shows Ngoai lich")

	# CHOICE
	gs.minute = 690
	hud.refresh()
	check(String(lbl.text).contains("11:30"), "shows 11:30")
	check(String(lbl.text).contains("Tự chọn"), "shows choice label")

	# signal hook voi clock (task 5)
	var ct_script = load("res://scripts/clock_timer.gd")
	if ct_script != null:
		var ct = ct_script.new()
		hud.setup(gs, ct)
		gs.mode = gs_script.GameStateMode.REPAIR
		ct.tick(1.0)
		check(String(lbl.text).contains("11:31"), "clock tick updates HUD")
		ct.free()
	hud.free()
```

- [ ] **Step 2: Chạy — verify RED**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_hud.gd`
Expected: `FAIL load:` / `hud.tscn loads` fail.

- [ ] **Step 3: Implement `hud.tscn` + `hud.gd`**

`tscn` đúng mô hình `repair_panel.tscn` (root CanvasLayer + ExtResource script). `hud.gd` theo Interface; `_ready()` lookup `/root/GameState` + tìm `ClockTimer` làm sibling (`get_parent().get_node_or_null("ClockTimer")`) rồi `setup(gs, clock)` — trong test gọi `setup()` trực tiếp (free-standing không có `_ready`).

- [ ] **Step 4: Chạy single + gate**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_hud.gd` → `FAILURES=0`
Run: `bash repair-shop-game/tests/run_suite.sh` → `TOTAL_FAILURES=0` + `GATE PASS`

- [ ] **Step 5: Đăng ký + Commit**

Thêm `"res://tests/test_hud.gd",` vào `TEST_SCRIPTS`.

```bash
git add repair-shop-game/scenes/ui/hud.tscn repair-shop-game/scripts/ui/hud.gd repair-shop-game/tests/test_hud.gd repair-shop-game/tests/run_tests.gd
git commit -m "feat: clock HUD with slot label"
```

---

### Task 7: Màn lịch tuần (Tab) + wire 3 node vào main.tscn + smoke

**Files:**
- Create: `repair-shop-game/scenes/ui/schedule_screen.tscn`
- Create: `repair-shop-game/scripts/ui/schedule_screen.gd`
- Create: `repair-shop-game/tests/test_schedule_screen.gd`
- Modify: `repair-shop-game/scenes/main.tscn` (3 node: `HUD`, `ScheduleScreen`, `ClockTimer`)
- Modify: `repair-shop-game/tests/run_tests.gd`

**Interfaces:**
- Consumes: Task 1 (`ScheduleLogic.slots_for_day/weekday`, `week.holidays`), Task 3 (`gs.date`), Task 6 pattern, Task 5 (`ClockTimer` node name).
- Produces:
  - `schedule_screen.tscn`: root `CanvasLayer` tên `ScheduleScreen`, `visible = false` + script.
  - `func setup(gs: Node) -> void` — set state, `_build_ui()`, `refresh()`.
  - `_build_ui()`: `Root` chứa `Root/Days` (HBoxContainer) với 7 cột `Root/Days/Day0..Day6` (VBoxContainer) — mỗi cột: `Header` (Label "T2".."CN") + `Row0..RowN` (Label, text `HH:MM–HH:MM · <tên slot>`); và `Root/HolidayList` (ItemList, item = mỗi entry `week.holidays`).
  - `refresh()`: tính thứ Hai của tuần hiện tại từ `gs.date` (`Time` utils: unix của date − `(weekday-1)*86400`), cột `i` dùng `date = thứ Hai + i ngày` gọi `slots_for_day` — đúng 7 cột kể cả holiday (cột nào trùng holiday chỉ có 1 dòng HOLIDAY).
  - `_unhandled_input`: `KEY_TAB` toggle `visible`, bỏ qua `echo`/`not key.pressed`; guard `game_state == null`.
  - `main.tscn`: thêm `[ext_resource]` hud.tscn, schedule_screen.tscn, clock_timer.gd + 3 node con của `Main` (HUD instance, ScheduleScreen instance, ClockTimer Node+script); bump `load_steps`.

- [ ] **Step 1: Viết test đỏ `tests/test_schedule_screen.gd`**

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var packed = load("res://scenes/ui/schedule_screen.tscn") as PackedScene
	check(packed != null, "schedule_screen.tscn loads")
	if packed == null:
		return
	var scr = packed.instantiate()
	check(scr is CanvasLayer, "root CanvasLayer")
	check(not scr.visible, "starts hidden")
	var gs_script = load("res://scripts/autoload/game_state.gd")
	var gs = gs_script.new()
	scr.setup(gs)
	for i in range(7):
		check(scr.has_node("Root/Days/Day%d" % i), "day column %d" % i)
	var hdr0 = scr.get_node("Root/Days/Day0/Header") as Label
	check_eq(String(hdr0.text), "T2", "col0 header T2")
	var hdr6 = scr.get_node("Root/Days/Day6/Header") as Label
	check_eq(String(hdr6.text), "CN", "col6 header CN")
	var day0 = scr.get_node("Root/Days/Day0")
	check(day0.get_child_count() >= 6, "T2 column: header + 5 rows")
	var row0 = scr.get_node("Root/Days/Day0/Row0") as Label
	check(String(row0.text).contains("07:00"), "row0 shows 07:00")
	var day6 = scr.get_node("Root/Days/Day6")
	check(day6.get_child_count() >= 6, "CN column: header + 5 rows")
	check(scr.has_node("Root/HolidayList"), "holiday list exists")
	var hlist = scr.get_node("Root/HolidayList") as ItemList
	check(hlist.item_count >= 3, "3 holidays listed")

	# Tab toggle qua truc tiep _unhandled_input (khong can tree)
	var ev = InputEventKey.new()
	ev.keycode = KEY_TAB
	ev.pressed = true
	scr._unhandled_input(ev)
	check(scr.visible, "Tab press -> visible")
	ev.pressed = false
	scr._unhandled_input(ev)
	check(scr.visible, "release ignored")
	ev.pressed = true
	scr._unhandled_input(ev)
	check(not scr.visible, "Tab press again -> hidden")

	# source pin
	var f = FileAccess.open("res://scripts/ui/schedule_screen.gd", FileAccess.READ)
	check(f != null and f.get_as_text().contains("KEY_TAB"), "Tab pinned")
	check(f != null and f.get_as_text().contains("slots_for_day"), "renders via slots_for_day")
	scr.free()
```

- [ ] **Step 2: Chạy — verify RED**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_schedule_screen.gd`
Expected: `FAIL load:` / tscn null.

- [ ] **Step 3: Implement `schedule_screen.tscn` + `schedule_screen.gd`**

Theo Interface (pattern `hud.gd`/`repair_panel`).

- [ ] **Step 4: Chạy single test — verify GREEN (chưa wire main)**

Run: `godot --headless --path repair-shop-game -s res://tests/run_one.gd -- res://tests/test_schedule_screen.gd` → `FAILURES=0`

- [ ] **Step 5: Wire `main.tscn` — thêm HUD, ScheduleScreen, ClockTimer**

`python3` heredoc sửa `main.tscn`: bump `load_steps` (+3), thêm 3 `ext_resource`, thêm 3 node sau `Camera3D` (hoặc cuối file): `HUD` instance, `ScheduleScreen` instance, `ClockTimer` type Node + `script`. Lưu ý cả 3 name đúng chuẩn để `hud.gd _ready` tìm được sibling.

- [ ] **Step 6: Smoke + toàn bộ suite**

Run: `godot --headless --path repair-shop-game --quit-after 60 res://scenes/main.tscn > /tmp/smoke.log 2>&1; grep -c "SCRIPT ERROR" /tmp/smoke.log`
Expected: `0` (in ra `0`), rc=0.
Run: `bash repair-shop-game/tests/run_suite.sh` → `TOTAL_FAILURES=0` + `GATE PASS` (đặc biệt `test_scene_manager`/`test_main_scene` không vỡ vì thêm node).

- [ ] **Step 7: Đăng ký + Commit**

Thêm `"res://tests/test_schedule_screen.gd",` vào `TEST_SCRIPTS`.

```bash
git add repair-shop-game/scenes/ui/schedule_screen.tscn repair-shop-game/scripts/ui/schedule_screen.gd repair-shop-game/tests/test_schedule_screen.gd repair-shop-game/scenes/main.tscn repair-shop-game/tests/run_tests.gd
git commit -m "feat: weekly schedule screen (Tab) + main scene wiring"
```

---

## Completion checklist

- [ ] 7 task xanh, mỗi task: single test `FAILURES=0` → suite `TOTAL_FAILURES=0 GATE PASS` → commit.
- [ ] Task 7: smoke `main.tscn` rc=0, không `SCRIPT ERROR`.
- [ ] Cuối plan: dispatch reviewer whole-branch (package `review-<base>...<head>.diff` theo mẫu Spec 2) + fix pass nếu cần.
