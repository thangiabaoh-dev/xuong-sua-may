# Spec — Lịch tuần & khung giờ (Schedule Engine, bản hợp nhất)

- **Ngày:** 2026-10-08 (amend 1 — hợp nhất với implementation của session song song)
- **Cycle:** 1/3 trong chuỗi *Lịch tuần → Đọc sách → Project*
- **Nguồn:** DESIGN.md §4 (lịch tuần), §8 (state machine)
- **Tình huống:** session song song đã build nền schedule (6 commit `a8e8adf…9cf50b6`, suite xanh). Spec này **giữ nền của họ** và bổ sung phần thiếu. Hai ruling cũ (Q1/Q2) được giữ sau khi so sánh.

## 1. Quyết định đã chốt

| # | Câu hỏi | Quyết định |
|---|---|---|
| 1 | Đồng hồ | **Action-driven** — phút trôi qua activity/`RepairSession._add_minutes`; **bỏ** tick realtime `1s=1min` của `ClockTimer` (double-count budget, trái ruling) |
| 2 | Gate | **Gate hoạt động, không gate di chuyển** — `can_enter` chuyển thành advisory, `change_map` không từ chối |
| 3 | Scope UI | Engine + HUD (panel hoạt động) + panel SUMMARIZE |
| 4 | Ca sửa vs RepairSession | **Budget chung của ca** (120′ ngày thường, 510′ CN gộp 2 window); dở dang khi hết → `LOST_TIME` |
| 5 | Đọc sách/project | Tách spec riêng (cycle 2/3); cycle 1 = **hook rỗng** |
| 6 | Trigger | **Hybrid** — đúng vị trí + bấm xác nhận |
| 7 | Bỏ học | Đỏ được, phạt `ky_luat` khi thiếu slot học |
| 8 | Mô hình lịch | **Theo nền họ: `date` year/month/day thật (unix)** — thay ruling epoch `%7` cũ; lễ hardcode `"MM-DD"`/`"YYYY-MM-DD"` |
| 9 | Kiến trúc | **Nền họ**: `ScheduleLogic` static + `WeekSchedule/DaySchedule/TimeSlot .tres` + `GameState` autoload; **bổ sung**: `ActivityDef` + `ScheduleCore` (RefCounted) cho activity/budget/penalty |
| 10 | Xung đột Q1/Q2 vs code họ | Chọn **theo Q1/Q2** (bỏ realtime tick, nới movement gate) |

## 2. Giữ nguyên nền họ (R1)

| Thành phần | File | Ghi chú |
|---|---|---|
| Data tuần | `data/week_schedule.tres` + `tools/build_week_schedule.gd` | Đủ DESIGN §4: weekday 5 slot, T3 `FREE_HOME` 17–19h, CN 2 ca (`540–720`, `810–1140`) + `BREAK`, lễ `04-30`, `09-02`, `2026-02-17` |
| Resources | `scripts/data/{time_slot,day_schedule,week_schedule}.gd` | `TimeSlot{start_minute,end_minute,kind,locations,repair}` |
| Logic | `scripts/schedule_logic.gd` | `weekday()` unix thật, `is_holiday()`, `slots_for_day()`, `current_slot()`, `is_repair_slot()` |
| State | `scripts/autoload/game_state.gd` | `mode` enum SCHEDULE/REPAIR/MINIGAME/SUMMARIZE, `date`, `minute`, `week`, `slot()`, `advance_to()`, `end_day()` |
| UI | `scripts/ui/hud.gd` (label `HH:MM · T3 · Đi học`), `scripts/ui/schedule_screen.gd` (Tab) | |
| Clock | `scripts/clock_timer.gd` + node trong `main.tscn` | Giữ node + signal `minute_changed` + debug F5/F6/F7 |
| Tests | 6 test file schedule của họ | Xanh, giữ (trừ `test_map_gating` sửa semantics) |

## 3. Đồng hồ (R2 — theo Q1)

- `ClockTimer.tick()` **không còn tự tăng phút theo wall-clock** trong `mode == REPAIR`; `_process` chỉ giữ debug key. Signal `minute_changed` vẫn phát từ mọi đường gọi `advance_to`.
- Phút game chỉ đến từ:
  1. `try_activity()` (mới, §4) — `minute += …`;
  2. `RepairSession._add_minutes` (đã có) — gọi thêm `advance_to(minute + n)` **và** `shift_tick(n)` (§5).
- `advance_to(m)` / `end_day()` giữ hành vi hiện tại (≥1320 → end_day) — `end_day()` sẽ đổi theo §6 (hiện SUMMARIZE trước, không lướt qua).
- Debug: F5/F6/F7 giữ nguyên công dụng test, ghi chú rõ là debug-only.

## 4. Activity system (R3 — phần mới)

### 4.1 `ActivityDef` (Resource, thêm vào builder tool)

```gdscript
class_name ActivityDef extends Resource
@export var id: String           # "di_hoc", "doc_thu_vien"…
@export var label: String
@export var required_location: String = ""   # "" = mọi nơi
@export var minutes: int                    # phút consume
@export var hook: String = ""               # cycle 2/3 điền effect; cycle 1 rỗng
```

`TimeSlot` thêm `@export var activities: Array[ActivityDef] = []`; builder tool set activity cho từng slot:

| Slot (kind) | Activities (đúng chỗ + bấm → consume trọn slot, clamp cuối slot) |
|---|---|
| `SCHOOL` | `di_hoc` — cần `classroom`, 270′/195′ |
| `CHOICE` | chọn 1: `doc_thu_vien` (library) / `project_ca_phe` (cafe) — 135′ |
| `REPAIR` (khung mở) | `mo_panel` (workshop, chỉ mở RepairPanel — không consume phút) **hoặc** fallback `nghi_tai_nha` / `doc_sach_nha` (workshop) — 120′ |
| `FREE_HOME` (T3, CN sáng) | 1 trong 4: `lam_project_som` / `doc_sach_nha` / `don_kho` / `nghi_ngoi` (workshop) — 120′ |
| `PROJECT` | `lam_project` (workshop, 180′, hook cycle 3) |
| `BREAK` (CN) | `nghi_giac` (workshop, 90′) |
| `HOLIDAY` | `su_kien_doi_thuong` (hook cycle 2/3, 900′) |

### 4.2 `ScheduleCore` (RefCounted — logic thuần, test headless)

```gdscript
func available(gs) -> Array[ActivityDef]         # activities slot hiện tại — KHÔNG lọc location; slot HOLIDAY runtime → tự sinh su_kien_doi_thuong
func reason_for(gs, act) -> String               # "" | "Ngoài lịch" | "Cần ở: <loc>"
func try_activity(gs, id: String) -> Dictionary  # {ok, reason}; tìm act trong available + reason_for
```

- Thành công → `minutes += min(activity.minutes, slot.end − minutes)`; clamp `[0, 1320]`, không bao giờ giảm; chạm 1320 → `end_day()` (phát `schedule_changed`).
- Sai → `{ok:false, reason}` (`"Ngoài khung giờ"`, `"Cần ở: thư viện"`, `"Ngoài lịch"`) — **không** đổi state; id lạ → thêm `push_error`.
- `mo_panel` đặc biệt: hợp lệ → cho `RepairPanel.open()` (state → REPAIR theo §6), không consume phút.

### 4.3 Gate di chuyển → advisory (Q2)

- `scene_manager.change_map`: bỏ nhánh từ chối khi `can_enter == false`; gọi `gs.can_enter()` chỉ để `push_warning` (giữ API, test sửa theo).
- `TimeSlot.locations` giữ dữ liệu (dùng cho hint `required_location` và đối chiếu với activity), không còn chặn.

## 5. Budget ca sửa (R4)

- `GameState.shift_used: int = 0` — reset ở `begin_new_day()` (end_day chỉ dừng ở SUMMARIZE).
- `ScheduleCore.shift_budget(gs) -> int`: tổng `end−start` của các slot `repair=true` trong ngày (weekday 120, CN 510, T3/lễ 0).
- `shift_tick(gs, n) -> bool`: **chỉ tính khi đang trong slot `REPAIR`** → `shift_used += n`; trả `false` khi vượt budget; ngoài slot → không cộng, trả `true` (không làm cháy test nền họ chạy ở phút 420).
- **Gate đơn:** `RepairPanel.open_new_order()` thêm check — `ScheduleLogic.is_repair_slot(...) && shift_used < shift_budget && mode != SUMMARIZE`; không đủ → disabled + lý do (không tạo `OrderFactory.make()`).
- **Đóng ca:** chạm cuối slot `REPAIR` hoặc hết budget mà session còn dở → `Result.LOST_TIME`, đóng panel, mode → SCHEDULE. Budget CN tính gộp 2 window (giữa window là slot `BREAK` bình thường).

## 6. Ngày mới & hình phạt (R4)

- **`end_day()` sửa:** mode → SUMMARIZE và **dừng** (không tự set lại SCHEDULE); hiện `summarize.tscn`. Nút "Ngủ → ngày kế" → tính phạt, `date += 1 ngày` (unix như code họ), `minute = 420`, `shift_used = 0`, mode → SCHEDULE.
- **`GameState.today_activities: Array` (mới):** mọi `try_activity` thành công push `{id, label, minutes}` — dùng cho panel SUMMARIZE (liệt kê) và tính phút học (`SCHOOL` activities) cho phạt §6b; reset ở cuối ngày.
- **Panel SUMMARIZE:** liệt kê hoạt động đã làm trong ngày (tên + phút), tiền thu/chi, hình phạt học đường; 1 nút ngủ.
- **Phạt học đường:** `expected = 450` (2 slot SCHOOL ngày thường); `thiếu = max(0, expected − phút học đã làm)`; `ky_luat -= 10 * ceil(thiếu / 450.0)`; `< 50` → `night_banned()` (đã có).
- Đang `mode == REPAIR` mà chạm 1320 → force `LOST_TIME` (đã có result) **trước** khi hiện SUMMARIZE.

## 7. UI (R4)

- **HUD** (`hud.gd` có sẵn): giữ label; thêm **panel hoạt động** — list `ScheduleCore.available()`, nút bấm → `try_activity()`; sai chỗ → disabled + reason; `mode != SCHEDULE` → ẩn panel. Trong ca sửa thêm nhãn `Ca còn 85/120'`.
- **`summarize.tscn` (mới):** instantiate trong HUD khi `mode == SUMMARIZE` (xem §6).
- ScheduleScreen (Tab) giữ nguyên.

## 8. Error handling

| Tình huống | Xử lý |
|---|---|
| `.tres` hỏng/thiếu | fallback load thất bại → `push_error`, `week = null`, HUD hiện "Ngoài lịch", không crash |
| Activity id lạ / key lễ sai format | `{ok:false}` / `is_holiday` bỏ entry + `push_warning` |
| `minute` dữ liệu ngoài [0,1320] | clamp + warning |
| 22:00 khi `mode == REPAIR` | force `LOST_TIME` trước SUMMARIZE |
| Sai location/khung giờ | `{ok:false, reason}` cho UI hint — không đổi state |

## 9. Test (TDD RED→GREEN từng task)

- **5 test nền họ phải amend** (hành vi đổi theo ruling, nội dung giữ, chỉ sửa assertion; plan chỉ rõ từng block):
  - `test_map_gating` — semantics advisory: `change_map` luôn thành công, `can_enter == false` chỉ → warning.
  - `test_game_state_time` — `advance_to(1320)` giờ dừng ở `SUMMARIZE`; rollover qua `begin_new_day()`; thêm clamp + null-week.
  - `test_clock_timer` — bỏ assertion "tick tăng phút realtime"; mục F7 → SUMMARIZE; giữ F5/F6.
  - `test_hud` — block "ct.tick cập nhật HUD" → `advance_to` + `schedule_changed`.
  - `test_repair_panel` — `state.advance_to(1020)` trước `setup()` (vào slot REPAIR để qua gate).
- **2 test nền họ giữ nguyên:** `test_schedule_logic`, `test_schedule_screen`.
- Mới:
  - `test_activities_data.gd` — `.tres` có activities đúng bảng §4.1 (id/location/minutes/hook rỗng).
  - `test_activities.gd` — `try_activity`: đúng chỗ/đúng khung → phút tăng đúng (boundary clamp cuối slot); sai chỗ/sai khung/id lạ/`mode != SCHEDULE` → `{ok:false}`, phút không đổi; HOLIDAY synthesize; key lễ sai format → push_warning (source pin).
  - `test_shift_budget.gd` — `shift_budget` weekday 120 / CN 510 / T3 = 0; `shift_tick` chỉ tính trong slot, tích lũy qua BREAK; session hết budget / chạm 1320 → `LOST_TIME` + clamp.
  - `test_repair_gate.gd` — ngoài khung/budget hết → không tạo đơn; trong khung → `session != null`.
  - `test_day_end.gd` — `advance_to(1320)` → SUMMARIZE; bấm ngủ → `date` +1, `minute = 420`, `shift_used = 0`, mode SCHEDULE, phạt −10.
  - `test_school_penalty.gd` — thiếu 450′ → −10, thiếu 449′ → −10, đủ/vượt → không phạt (cycle 1 không có −20).
  - `test_hud_activity.gd` (scene) — panel list đúng activity, enable/disable theo location, không nhân đôi nút, auto-refresh qua `schedule_changed`, budget label 120.
- 25+ test cũ còn lại không sửa (5 file amend ở trên là ngoại lệ duy nhất).
- Debug key F5/F6/F7 không tham gia assertion gameplay.

## 10. Out of scope (cycle 1)

- Tri thức/thưởng đọc sách → **cycle 2**; mốc project + uy tín/giới thiệu → **cycle 3**
- Save/load; đơn tự tới; realtime clock; audio; bỏ F5/F6/F7 (giữ debug)
