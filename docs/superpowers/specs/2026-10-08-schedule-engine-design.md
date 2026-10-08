# Spec — Lịch tuần & khung giờ (Schedule Engine)

- **Ngày:** 2026-10-08
- **Cycle:** 1/3 trong chuỗi *Lịch tuần → Đọc sách → Project*
- **Nguồn:** DESIGN.md §4 (lịch tuần & khung giờ), §8 (state machine, SCHEDULE Resource)
- **Trạng thái hiện có:** `GameState` 13 dòng (money/knowledge/uy_tin/ky_luat/inventory/current_location), KHÔNG đồng hồ/ngày; `RepairSession` có `elapsed` vs `deadline_min` từng đơn; `SceneManager` cho đổi map bằng phím 1–7 tự do; `repair_panel.gd` tự `open_new_order()` khi mở.

## 1. Quyết định đã chốt với người chơi

| # | Câu hỏi | Quyết định |
|---|---|---|
| 1 | Đồng hồ chạy thế nào | **Action-driven** — phút game chỉ tăng khi player xác nhận hành động; không clock thật |
| 2 | Gate tới mức nào | **Gate hoạt động, không gate di chuyển** — portal/phím 1–7 giữ nguyên |
| 3 | Scope UI | **Engine + HUD giờ/ngày + panel SUMMARIZE tối giản** |
| 4 | Ca sửa vs RepairSession | **Budget chung của ca** (120′ ngày thường); đơn dở dang khi hết budget/19:00 → `LOST_TIME` |
| 5 | Hoạt động ngoài ca sửa | Đọc sách & project làm **thật**, nhưng tách thành spec riêng (cycle 2 & 3) — cycle 1 để **hook rỗng** |
| 6 | Trigger trôi slot | **Hybrid** — đúng vị trí + bấm xác nhận mới consume phút |
| 7 | Bỏ học | **Đỏ được nhưng phạt `ky_luat`** nếu thiếu slot học trong ngày |
| 8 | Mô hình lịch | **Tuần tuần hoàn `day_index % 7` (epoch = T2) + bảng ngày lễ hardcode theo tháng/ngày** |
| 9 | Kiến trúc | **Approach 1** — `ScheduleCore` RefCounted (logic thuần, test headless) + `GameState` autoload mỏng + `hud.tscn` CanvasLayer child của `Main` |

## 2. Dữ liệu & lịch

### 2.1 DayTemplate Resource (`data/schedule/*.tres`)

```
DayTemplate (Resource)
  id: String
  slots: Array[SlotDef]

SlotDef (Resource)
  start_min: int          # phút trong ngày, 0 = 00:00
  end_min: int
  kind: enum { SCHOOL, CHOICE, FREE, REPAIR_SHIFT, PROJECT, REST, EVENT }
  activities: Array[ActivityDef]

ActivityDef (Resource)
  id: String              # vd "di_hoc"
  label: String           # "Đi học"
  required_location: String   # "" = bất kỳ; "classroom"; "library"... (nhóm, không cụ thể portal)
  minutes: int            # phút consume khi xác nhận
  hook: String            # cycle 2/3 điền effect; cycle 1 = rỗng
```

File: `weekday.tres`, `t3.tres`, `sunday.tres`, `holiday.tres` — pattern load như `customer_catalog.gd`.

### 2.2 Khung ngày thường (T2, T4, T5, T6, T7)

| Slot | start→end | kind | Activities |
|---|---|---|---|
| Đi học sáng | 420→690 (07:00–11:30) | SCHOOL | `di_hoc` (cần `classroom`, 270′, trọn slot) |
| Trưa | 690→825 (11:30–13:45) | CHOICE | chọn 1 trọn slot: `doc_thu_vien` (library) / `project_ca_phe` (cafe) |
| Đi học chiều | 825→1020 (13:45–17:00) | SCHOOL | `di_hoc` (classroom, 195′, trọn slot) |
| Ca sửa | 1020→1140 (17:00–19:00) | REPAIR_SHIFT | **khung mở**: mở RepairPanel (workshop) **hoặc** fallback `nghi_tai_nha` / `doc_sach_nha` (stub) |
| Project | 1140→1320 (19:00–22:00) | PROJECT | `lam_project` (workshop, 180′, trọn slot, hook rỗng) |

### 2.3 Thứ 3 (`t3.tres`)

Y hệt ngày thường, trừ: **17:00–19:00 không có `REPAIR_SHIFT`** → slot FREE với 4 lựa chọn trọn slot: `lam_project_som`, `doc_sach_nha`, `don_kho`, `nghi_ngoi` (tất cả stub, `required_location` = workshop/nhà).

### 2.4 Chủ nhật (`sunday.tres`)

- 09:00–12:00 (540→720) `REPAIR_SHIFT` window 1
- 12:00–13:30 (720→810) REST — `nghi_giac` stub
- 13:30–19:00 (810→1140) `REPAIR_SHIFT` window 2
- 19:00–22:00 (1140→1320) PROJECT — `lam_project`
- Không slot học. Budget ca CN = 180+330 = 510′ (tính gộp 2 window).

### 2.5 Ngày lễ (`holiday.tres`)

Không `REPAIR_SHIFT`. Slots EVENT stub (đi chơi / về quê / sum họp — `hook` rỗng, consume slot). Bảng hardcode:

```gdscript
const HOLIDAYS := { "4/30": "labour", "9/2": "independence", "1/1": "newyear_approx" }
```

Đếm tháng/ngày liên tục từ epoch (bảng ngày/tháng 12 tháng, không cần năm thật, không cần 29/2). `1/1` là xấp xỉ Tết dương lịch thay cho Tết âm (đủ để demo loại ngày lễ; data tinh chỉnh không cần đổi code). Key lễ sai định dạng → bỏ entry + `push_warning`.

### 2.6 Tuần & epoch

- `day_index: int = 0` → `DOW = ["T2","T3","T4","T5","T6","T7","CN"][day_index % 7]`
- `day_template(day_index)`: nếu `(month, day)` nằm trong `HOLIDAYS` → `holiday.tres`, còn lại theo thứ.

## 3. Đồng hồ & API

### 3.1 GameState mở rộng (autoload, giữ field cũ)

```gdscript
var day_index: int = 0
var minutes: int = 420          # 07:00 đầu ngày
var state: int = State.SCHEDULE # SCHEDULE → REPAIR → MINIGAME → SUMMARIZE (DESIGN §8)
var shift_used: int = 0         # phút budget ca đã dùng
```

- Mở `RepairPanel` hợp lệ → `state = REPAIR`; panel vào phase minigame → `MINIGAME`; xong → `REPAIR`; đóng ca → `SCHEDULE`.
- `minutes ≥ 1320` (22:00) → `SUMMARIZE`; bấm "Ngủ" → `day_index += 1`, `minutes = 420`, `shift_used = 0`, về `SCHEDULE`.
- Game bắt đầu: `day_index=0` (T2), `minutes=420`, `state=SCHEDULE`.

### 3.2 `ScheduleCore` (RefCounted — logic thuần, không phụ thuộc scene tree)

```gdscript
func slot_at(minutes: int) -> SlotDef
func day_template(day_index: int) -> DayTemplate        # có override lễ
func available_activities(gs) -> Array[ActivityDef]     # đúng khung giờ + đúng location
func try_activity(gs, id: String) -> Dictionary         # {ok: bool, reason: String}
func shift_tick(n: int) -> bool                         # trừ budget; false = hết ca
func shift_budget(day_template) -> int                  # tổng phút REPAIR_SHIFT trong ngày
```

- `try_activity` kiểm: (1) `state == SCHEDULE`, (2) activity thuộc slot hiện tại, (3) `gs.current_location` khớp `required_location`; thành công → `minutes += min(activity.minutes, slot.end_min - minutes)`, phát signal `slot_changed` / `day_ended` (khi `minutes` chạm 1320).
- Sai → `{ok:false, reason}` + `push_error`, **không** đổi state.
- Clamp mọi đường: `minutes ∈ [0, 1320]`, không bao giờ giảm.
- UI lấy lý do từ `reason` để hiện hint (`"Cần ở: thư viện"`), nút disabled khi sai chỗ (biết trước, không chặn di chuyển).

### 3.3 Hình phạt học đường

`school_minutes_expected` của ngày thường = 270+195 = 450. Ở SUMMARIZE: `thiếu = max(0, expected − đã làm)`; `ky_luat -= 10 * ceil(thiếu / 450.0)` (thiếu 1–450′ → −10, 451–900′ → −20…). `ky_luat < 50` → `night_banned()` (đã có sẵn).

## 4. Tích hợp ca sửa

- **Budget:** `shift_used` cộng dồn từ `RepairSession._add_minutes` (mọi phút sửa của mọi đơn trong ngày) qua `shift_tick(n)`. Reset khi sang ngày.
- **Nhận đơn:** giữ nguyên `RepairPanel.open_new_order()` + `OrderFactory.make()` — chỉ gọi được khi: đang slot `REPAIR_SHIFT` **và** `shift_used < shift_budget` **và** `state != SUMMARIZE` (state `SCHEDULE/REPAIR/MINIGAME` đều cho qua — đơn kế trong cùng phiên panel đang mở phải qua được gate). Không đủ → disabled + lý do. (Đơn vẫn *player-initiated* như hiện tại — đơn tự tới là sau.)
- **Đóng ca:** chạm cuối slot hoặc hết budget mà session còn dở → `Result.LOST_TIME`, đóng panel, về `SCHEDULE`. Đang `REPAIR` mà chạm 22:00 → force `LOST_TIME` **trước** khi hiện SUMMARIZE.
- **Khung mở:** không nhận đơn nào thì dùng slot repair cho fallback activities (consume `minutes` bình thường) — DESIGN §4.4.
- **T3/lễ:** template không có slot `REPAIR_SHIFT` → `available_activities` không trả "mở panel" → `open_new_order` không bao giờ được gọi.
- **CN:** budget gộp 2 window; giữa 2 window là slot REST bình thường.

## 5. UI

### 5.1 `hud.tscn`

CanvasLayer, thêm 1 dòng instance vào `main.tscn` — child của `Main`, **ngoài** node map → sống qua `SceneManager.change_map` (thay map con, không đụng `Main`).

- Thanh trên: `T2 · 07:00 · Đi học` — ngày từ `day_index`, đồng hồ từ `minutes`, tên slot hiện tại. Trong ca: thêm `Ca còn 85/120'` (`shift_budget` của ngày — CN hiện 510).
- Panel hoạt động: list `available_activities()`; đúng chỗ → bấm được → `try_activity()`; sai chỗ → disabled + hint; `state != SCHEDULE` → ẩn.

### 5.2 `summarize.tscn`

Instantiate trong HUD khi `state == SUMMARIZE`:

- Liệt kê hoạt động trong ngày (tên + phút), tiền thu/chi, hình phạt học đường (nếu thiếu slot).
- 1 nút **"Ngủ → ngày kế"** → rollover (§3.1).

## 6. Error handling

| Tình huống | Xử lý |
|---|---|
| `.tres` template thiếu/hỏng | fallback `weekday.tres` + `push_error` |
| Activity id lạ / key lễ sai format | `{ok:false}` / bỏ entry + `push_warning`, không crash |
| `minutes` dữ liệu ngoài [0,1320] | clamp + warning |
| 22:00 khi `state == REPAIR` | force `LOST_TIME` trước SUMMARIZE |
| Sai location/khung giờ | `{ok:false, reason}` cho UI hint — không đổi state |

## 7. Test (TDD, RED→GREEN mỗi task)

- `test_schedule_core.gd` (logic thuần, headless):
  - `slot_at()` ranh giới: 420/689/690/824/825/1019/1020/1139/1140/1319/1320
  - `day_template()`: `day_index%7` (0=T2, 1=T3, 6=CN) + override lễ
  - `available_activities()`: sai chỗ → reason; sai khung → vắng; T3 không có mở panel; CN 2 window; khung mở có fallback
  - `try_activity()`: đúng → `minutes` tăng đúng; clamp cuối slot; id lạ/state sai → không đổi
  - budget `shift_tick` + `shift_budget` (CN=510); rollover 22:00 → SUMMARIZE → ngày kế; phạt học đường
  - clamp: `minutes` ∈ [0,1320], không giảm
- Test HUD/scene (pattern `test_npc_import.gd`): instantiate `hud.tscn`, set `minutes`/location → assert label + enable/disable nút.
- Test gate `RepairPanel`: ngoài khung/budget hết → không tạo đơn.
- 25 test cũ không sửa — `GameState` chỉ thêm field.

## 8. Out of scope (cycle 1)

- Tri thức/thưởng từ đọc sách → **cycle 2 (spec riêng)**
- Mốc project + uy tín/giới thiệu khách → **cycle 3 (spec riêng)**
- Save/load (game chưa có hệ save)
- Đơn tự tới (giữ player-initiated)
- Audio, realtime clock, network
