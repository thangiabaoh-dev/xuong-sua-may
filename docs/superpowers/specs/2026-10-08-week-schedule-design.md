# Spec: Lịch tuần & khung giờ (Spec 3/3)

- Ngày: 2026-10-08
- Đường dẫn: `docs/superpowers/specs/2026-10-08-week-schedule-design.md`
- Nguồn: `repair-shop-game/DESIGN.md` §4 (lịch tuần), §8 (state + schedule trong Resource)
- Tiền đề đã duyệt: Spec 1 (7 map), Spec 2 (SceneManager wiring + gating seam `change_map -> bool`)
- Approaches đã chốt (user "chọn A"): Resource + `ScheduleLogic` thuần + HUD + màn lịch tuần

## 1. Mục tiêu & phạm vi

Xây subsystem lịch tuần: dữ liệu lịch 7 ngày + ngày lễ, state thời gian trong `GameState`, đồng hồ Hybrid, gating địa điểm 2 mức, HUD giờ và màn hình lịch tuần (phím Tab). Test headless TDD.

**Time model — Hybrid (user chốt):** clock tick **thời gian thật chỉ khi `state == REPAIR`**; ngoài ca thời gian advance theo hoạt động (spec sau) / debug key.

**Gating — 2 mức (user chốt):** slot chặt (`SCHOOL`, `REPAIR`) → đúng chỗ; slot mở (`CHOICE`, `FREE_HOME`, `BREAK`, `PROJECT`) → danh sách chỗ được phép của slot.

### Non-goals
- Vòng sửa máy thật (`REPAIR/MINIGAME` transition, đơn, mini-game) — spec riêng.
- Hoạt động đọc sách / project / dọn kho / nghỉ (§6) — spec sau; Spec 3 chỉ dựng slot framework.
- Nội dung tổng kết ngày (SUMMARIZE là stub).
- Sự kiện ngày lễ (đi chơi, về quê).
- Save/load, menu chọn hoạt động, toast khi bị từ chối vào chỗ.

## 2. Dữ liệu: `WeekSchedule` Resource

`scripts/data/week_schedule.gd` (`class_name WeekSchedule extends Resource`) + `data/week_schedule.tres`.

```
WeekSchedule
  days: Array[DaySchedule]        # 7 phần tử, index 0..6 = T2..CN (weekday Godot 1..7)
  holidays: PackedStringArray     # "MM-DD" (30-04, 09-02) và/hoặc "YYYY-MM-DD" (Tết)

DaySchedule (Resource)
  slots: Array[TimeSlot]

TimeSlot (Resource)
  start_minute: int   # inclusive
  end_minute: int     # exclusive
  kind: String        # SCHOOL | CHOICE | REPAIR | FREE_HOME | PROJECT | BREAK | HOLIDAY
  locations: Array[String]  # key map (khớp SceneManager.LOCATIONS)
  repair: bool = false      # true = khung mở nhận đơn
```

### Bảng slot (mốc nguồn: DESIGN §4)

Ngày thường T2, T4, T5, T6, T7:

| phút | kind | locations | repair |
|---|---|---|---|
| 07:00–11:30 | SCHOOL | [schoolyard] | false |
| 11:30–13:45 | CHOICE | [library, cafe] | false |
| 13:45–17:00 | SCHOOL | [schoolyard] | false |
| 17:00–19:00 | REPAIR | [workshop] | **true** (mở — hết đơn thì ở nhà làm việc khác) |
| 19:00–22:00 | PROJECT | [workshop] | false |

Thứ 3: như trên, nhưng `17:00–19:00` = `FREE_HOME [workshop]` (§4.2 — bỏ ca sửa, 4 lựa chọn do spec hoạt động sau).

Chủ nhật: `07:00–09:00 FREE_HOME [workshop]` · `09:00–12:00 REPAIR [workshop] repair=true` · `12:00–13:30 BREAK [workshop]` · `13:30–19:00 REPAIR [workshop] repair=true` · `19:00–22:00 PROJECT [workshop]`.

Ngày lễ (date khớp `holidays`): `slots_for_day` **tự sinh** slot `07:00–22:00 HOLIDAY [workshop] repair=false` (không lưu trong data) — không đơn, không trường.

### Quy ước ngoài khung
- Game day = 07:00→22:00. `minute < 420` hoặc `>= 1320` là trạng thái ngoài lịch: **không có slot data** (không thêm kind SLEEP — deviation có chủ đích), `current_slot` trả `null`, `can_enter` trả `false` (fail-closed). `advance_to` tự gọi `end_day()` khi `minute >= 1320`, nên ngoài lịch chỉ tới được qua debug key.
- Không có khung trống: mọi phút trong 07:00–22:00 thuộc đúng 1 slot (end_minute exclusive, sort theo start).

## 3. `ScheduleLogic` — static, thuần (DI, không autoload)

`scripts/schedule_logic.gd` (`class_name ScheduleLogic`) — pattern như `change_map`, nhận `week` qua tham số (harness `-s` không có autoload — xem ledger Spec 2).

```gdscript
static func weekday(date: Dictionary) -> int          # Time.get_date_day_of_week, 1=T2..7=CN
static func is_holiday(week, date) -> bool            # match "MM-DD" hoặc "YYYY-MM-DD"
static func slots_for_day(week, date) -> Array        # holiday -> [HOLIDAY tự sinh], else days[weekday-1] slots
static func current_slot(week, date, minute) -> Resource  # null nếu ngoài 07:00-22:00
static func is_repair_slot(week, date, minute) -> bool
static func allowed_locations(week, date, minute) -> Array  # []; fail-closed
static func can_enter(week, date, minute, loc: String) -> bool
```

Indexing: weekday Godot `1..7` (T2..CN) → `days` array index `weekday - 1` (days[0] = T2). Test pin điều này.

**2 mức:** `can_enter` = `allowed_locations.has(loc)`; `allowed_locations` trả `slot.locations` (slot đã encode mức: strict = 1 phần tử, mở = nhiều). `REPAIR repair=true` vẫn strict `[workshop]` — "mở" nghĩa là được nhận đơn *hoặc* làm việc khác **tại chỗ đó** (§4.4), không phải đi chỗ khác.

## 4. GameState — state thời gian

Thêm vào `game_state.gd`:

```gdscript
enum GameStateMode { SCHEDULE, REPAIR, MINIGAME, SUMMARIZE }  # §8 — Spec 3 chỉ dùng SCHEDULE <-> SUMMARIZE
var mode: int = GameStateMode.SCHEDULE
var date: Dictionary = {"year": 2026, "month": 10, "day": 5}   # T2 2026-10-05
var minute: int = 420                                          # 07:00
var week: WeekSchedule = preload("res://data/week_schedule.tres")

func slot() -> Resource                                        # ScheduleLogic.current_slot(...)
func advance_to(m: int) -> void                                # set minute; nếu >= 1320 -> end_day()
func end_day() -> void                                         # mode=SUMMARIZE (stub) -> date+1 (Time utils) -> minute=420, mode=SCHEDULE
func can_enter(loc: String) -> bool                            # delegate
```

`date+1` qua `Time.get_unix_time_from_datetime_dict` + `Time.get_datetime_dict_from_unix_time` (qua ngày/chuẩn hoá tháng đúng).

Autoload-absent rule: test tự `load("game_state.gd").new()` + truyền `week` nếu cần — không reference global `GameState`.

## 5. Đồng hồ Hybrid — `ClockTimer`

`scripts/clock_timer.gd` (`class_name ClockTimer extends Node`), instance trong `main.tscn`.

- `_process(delta)` → nếu `gs.mode == REPAIR`: `acc += delta`; mỗi `SECONDS_PER_GAME_MINUTE = 1.0` (const, chỉnh tay) → `gs.advance_to(gs.minute + 1)`.
- `func tick(delta: float) -> void` — logic thuần trong đây, `_process` chỉ gọi → test gọi trực tiếp headless.
- Phát tín hiệu `minute_changed(old, new)` để HUD update.
- **Spec 3 chưa có vòng sửa:** debug key **F5** toggle `mode` `SCHEDULE <-> REPAIR` (giả lập ca để thấy clock chạy). **F6** `advance_to(minute+30)`, **F7** `end_day()` ngay. Debug keys được phép bypass gating.
- Thuộc `ClockTimer` để tách khỏi `scene_manager` (map keys 1–7).

## 6. Gating — sửa `SceneManager.change_map`

```gdscript
static func change_map(parent, player, loc, gs) -> bool:
    # (mới) nếu gs != null và not gs.can_enter(loc): return false
    # ... phần cũ (validate trước mutate, xóa hết map, spawn) ...
    return true
```

- Trả `false` + **không đổi scene** khi bị chặn. `void -> bool` không phá test cũ (assert qua side-effect).
- Handler số 1–7: nếu `false` → bỏ qua im lặng (HUD đang hiển thị slot hiện tại — player tự hiểu; toast là non-goal).
- `test_scene_manager.gd` cũ phải giữ pass; test mới thêm case deny.

## 7. UI

### `scenes/ui/hud.tscn` + `hud.gd` (CanvasLayer)
- Label `TimeLabel` (`HH:MM · T2 · Đi học` — giờ, thứ (T2..CN), `slot.kind` map sang nhãn: SCHOOL="Đi học", CHOICE="Tự chọn", REPAIR="Ca sửa máy", FREE_HOME="Ở nhà", PROJECT="Làm project", BREAK="Nghỉ", HOLIDAY="Ngày lễ", null="Ngoài lịch").
- Hook `ClockTimer.minute_changed` + init từ `gs`. Không ghi ngoài y=0..40px.

### `scenes/ui/schedule_screen.tscn` + `schedule_screen.gd` (CanvasLayer, `visible=false`)
- Phím **Tab** (`_unhandled_input`, bỏ qua echo) toggle.
- Bảng 7 cột `T2..CN`: mỗi cột liệt kê slot `start–end` + nhãn kind của ngày đó (tính thứ Hai của tuần hiện tại, cột thứ i (0..6) lấy `date` = thứ Hai + i ngày rồi gọi `ScheduleLogic.slots_for_day` — thứ tự cột luôn T2→CN, nội dung theo template ngày thường/T3/CN/holiday của tuần đó).
- Cột ngày hôm nay tô nổi bật. Mục "Ngày lễ" liệt kê `week.holidays`.
- Không pause clock (áp lực §2.4).

### `main.tscn`
Thêm 3 instance: `HUD`, `ScheduleScreen`, `ClockTimer`. Đây là lần đầu spec này được sửa `main.tscn` (Spec 2 cấm — ràng buộc từng spec).

## 8. Testing (TDD, headless)

| File | Bắt |
|---|---|
| `test_schedule_logic.gd` | weekday(2026-10-05)=1; slot T3 có FREE_HOME ≠ REPAIR; CN có 2 REPAIR + BREAK; boundary 11:29/11:30; holiday 2 format; allowed_locations strict/mở/fail-closed; can_enter |
| `test_game_state_time.gd` | init 420/T2; advance_to(11:30) → CHOICE; advance_to(1320) → end_day tự kích hoạt (date+1, minute=420, mode về SCHEDULE — SUMMARIZE chỉ là trạng thái giữa, không kéo dài); state enum 4 giá trị |
| `test_map_gating.gd` | change_map bị deny giờ học (false, scene không đổi); allow `workshop` lúc 17:00; CHOICE cho library+cafe,deny schoolyard; return true ở case allow |
| `test_schedule_screen.gd` | instantiate `schedule_screen.tscn`/`hud.tscn`: đủ 7 cột, holiday list, TimeLabel tồn tại; source-pin update hook |
| `test_clock_timer.gd` | `tick()` khi REPAIR advance minute; khi SCHEDULE không advance; F5/F6/F7 handler source-pin |

Đăng ký vào `run_tests.gd`; gate cũ `bash repair-shop-game/tests/run_suite.sh` → `TOTAL_FAILURES=0 GATE PASS` + boot smoke `godot --headless --path repair-shop-game --quit-after 60 res://scenes/main.tscn` không `SCRIPT ERROR`.

## 9. Deviation / quyết định có chủ đích

1. **Không có kind SLEEP trong data** — ngoài 07:00–22:00 là `null` slot, fail-closed (xem §2).
2. **`change_map` `void -> bool`** — Spec 2 amend đã tiên lượng; test cũ không vỡ.
3. **F5–F7 bypass gating** — dev tool; gating chỉ áp 1–7.
4. **Clock giả lập F5** cho tới khi spec vòng sửa máy ra mắt (hybrid chọn ở mức spec).
5. **Không toast khi bị chặn** — non-goal, HUD đủ thông tin.
6. `week` preload trong GameState — `.tres` phải tồn tại trước khi autoload `_init` chạy; test cũng load được trực tiếp.

## 10. Ràng buộc kỹ thuật kế thừa

- Harness `godot --headless -s tests/run_tests.gd`; không autoload trong test → mọi thứ thuần/DI.
- Không sửa file của session NPC (`chibi-model/*`, `test_npc_import.gd`, `verify_npcs.py`).
- Gate + smoke đỏ thì không commit.
