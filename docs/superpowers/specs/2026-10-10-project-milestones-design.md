# Spec — Cycle 3: Project milestones / Uy tín / Giới thiệu

- **Ngày:** 2026-10-10
- **Branch:** cắt từ `feat/schedule-engine` @ `76cdafd`
- **Trạng thái:** design đã duyệt (brainstorming), chờ review spec → viết plan
- **Spec trước:** `2026-10-08-schedule-engine-design.md` §10 (giao cycle 3: "mốc project + uy tín/giới thiệu"), `2026-10-09-progression-unlock-design.md` (điểm phối hợp duy nhất: `completed_projects` + `UnlockContext.has_project`), `2026-10-10-knowledge-reading-design.md` (format hook cycle 2, cycle 3 dùng lại)

## 1. Mục tiêu

Hoàn thành hook `lam_project` / `lam_project_som` / `project_ca_phe` (cycle 1 để rỗng): mỗi project hoàn thành ghi `completed_projects` + tăng `project_count`, thưởng `uy_tin` theo loại activity, mở 2 khách mới qua milestone ("giới thiệu"), kèm phản hồi toast + SUMMARIZE.

Người chơi làm project hằng ngày (slot PROJECT 180′ mỗi ngày) → tích `project_count` → mốc 1/3 mở khách → kết hợp uy_tin sẵn có (60/90) tạo progression kép.

## 2. Scope

**Trong scope:**
- 2 key hook mới: `complete_project:<id>`, `uy_tin:<n>` (mở rộng whitelist cycle 2)
- Field mới `game_state.project_count` + input `project_count` trong `UnlockCore.INPUT_NAMES`
- 3 hook data trong builder + regen `week_schedule.tres`
- 2 customer `.tres` mới + 2 rule `project_count` trong `build_progression.gd` → regen `unlock_rules.tres`
- Toast `Hoàn thành project! +N uy_tin` + SUMMARIZE `Project hoàn thành: +N uy_tin`

**Ngoài scope (YAGNI):**
- Spawn khách / đơn tự tới (schedule-engine §10 out of scope)
- Thưởng tiền từ project
- Toast khi unlock khách (workplace tracker đã hiện bright ✓)
- Gating catalog máy/khách khi sinh đơn — spec tích hợp riêng
- `ban_hoc` giữ rule trống (khách cũ không đổi)

## 3. Cơ chế hook (approach 1 — đã duyệt)

### 3.1 Format

Dùng lại format cycle 2: `"key:value[,key:value]*"` — cycle 3 mở rộng whitelist:

| Key | Value | Hành vi |
|---|---|---|
| `knowledge_rate` | float ≥ 0 (cycle 2) | không đổi |
| `complete_project` | id (string không rỗng, `[a-z0-9_]+`) | `project_count += 1`; append id vào `completed_projects` **chỉ khi chưa có** |
| `uy_tin` | int ≥ 0 | `gs.uy_tin = clampi(uy_tin + n, 0, 100)` |

- Đa key/pair: xử lý độc lập, pair lỗi warn + bỏ qua (pattern cycle 2 §6).
- `completed_projects` = id ổn định (chống trùng) cho rule `has_project("p_cafe")`; `project_count` = số lần hoàn thành (mọi lần tính, kể cả lặp) cho rule milestone.
- `project_count` không bao giờ giảm.

### 3.2 Gains trả về

- `complete_project` chạy成功 → gains thêm `{"project": "<id>"}` (id cuối cùng nếu nhiều pair — thực tế mỗi activity 1 pair).
- `uy_tin` > 0 → gains thêm `{"uy_tin": n}`.
- `today_activities` entry thêm key `"project": id` / `"uy_tin": n` khi có (pattern cycle 2 thêm `"knowledge"`).

## 4. Bảng data

### 4.1 Hooks (builder `build_week_schedule.gd` → regen `week_schedule.tres`)

| Activity | Slot | hook |
|---|---|---|
| `lam_project` | PROJECT 180′ | `complete_project:p_noibo,uy_tin:10` |
| `lam_project_som` | FREE_HOME 120′ | `complete_project:p_som,uy_tin:6` |
| `project_ca_phe` | CHOICE 135′ (cafe) | `complete_project:p_cafe,uy_tin:8` |

### 4.2 Rules (builder `build_progression.gd` → regen `unlock_rules.tres`)

```gdscript
_rule("khach_truong_nhom", "customer", "project_count >= 1", "Trưởng nhóm")
_rule("khach_giam_doc", "customer", "project_count >= 3", "Giám đốc")
```

### 4.3 Khách mới (`data/customers/*.tres`, catalog tự scan)

**`truong_nhom` — "Trưởng nhóm"** (`unlock_rule = &"khach_truong_nhom"`)
- giới thiệu sau project đầu tiên; tone thân → tip 15%, trung tính → 0, khó → `lost_order`
- `risk_warning`: "Trưởng nhóm giới thiệu việc — tone khô là mất mối quan hệ ngay."

**`giam_doc` — "Giám đốc"** (`unlock_rule = &"khach_giam_doc"`)
- mốc 3 project; tone thân → tip 20%, trung tính → tip 5%, khó → `lost_order`
- `risk_warning`: "Giám đốc khó tính — sai một đơn là mất hợp đồng dài hạn."

(Reactions 3 tone viết tiếng Việt đầy đủ trong lúc implement; test assert theo data — user sửa tên/copy được sau.)

## 5. Phản hồi UI

### 5.1 HUD toast

- Trigger: `_on_activity` khi `gains` có key `"project"` (không cần `ok` khác).
- String: `Hoàn thành project! +%d uy_tin` với N = `gains.get("uy_tin", 0)` — nếu activity không có `uy_tin` pair thì `+0` (mọi project activity đều có uy_tin pair theo §4.1 nên thực tế N ≥ 6).
- Dùng lại `_toast()` + `Root/Toast` (cycle 2).

### 5.2 SUMMARIZE

- Dòng `Project hoàn thành: +%d uy_tin` — tổng `uy_tin` từ entries `today_activities` có key `"project"`.
- Ẩn khi tổng = 0. Đứng sau dòng `Tiền:` (cùng khu với dòng cycle 2 — dòng cycle 2 `Tri thức nhận` giữ nguyên, có thể cả 2 cùng hiện).

## 6. State & unlock

```gdscript
# game_state.gd — thêm 1 field
var project_count: int = 0
```

- `UnlockCore.INPUT_NAMES` thêm `"project_count"` (đọc qua `_int_field(game_state, "project_count")` — field int sẵn).
- Không đổi `UnlockContext` (`has_project` + `completed_projects` đã có từ spec 4a).
- Refresh unlock **lazy**: workplace mở → `refresh()` (cơ chế sẵn, cycle 3 không thêm trigger).
- `begin_new_day()` KHÔNG reset `project_count` / `completed_projects` (permanent như `knowledge_remainder`).

## 7. Error handling

| Tình huống | Hành vi |
|---|---|
| Hook rỗng / pair thiếu `:` / key lạ | pattern cycle 2 — warn + bỏ qua pair, không crash |
| `complete_project:` (id rỗng) | `push_warning` + bỏ qua pair (không count, không append) |
| id không khớp `[a-z0-9_]+` (vd có space/hoặc chữ hoa) | `push_warning` + bỏ qua pair (giữ id ổn định cho rule) |
| id đã tồn tại trong `completed_projects` | `project_count` vẫn += 1, **không** append trùng |
| `uy_tin:-5` / value không phải int | `push_warning` + bỏ qua pair |
| `uy_tin` vượt 100 | clamp về 100 (giống repair) |
| Builder ghi key ngoài whitelist / value sai | **build fail** (`push_error` + `quit(1)` — mở rộng whitelist cycle 2) |
| Activity fail (`ok:false`) | không chạy hook (đã có từ cycle 2) |

## 8. Testing (TDD — RED trước khi implement)

**Mới:**
- `tests/test_project_hook.gd` (+`.uid`, register cuối `run_tests.gd`):
  - `complete_project:p_x` lần 1 → `completed_projects == ["p_x"]`, `project_count == 1`
  - cùng id lần 2 → `project_count == 2`, `completed_projects` vẫn `== ["p_x"]` (chống trùng)
  - `uy_tin:8` → uy_tin tăng 8; clamp 100 (uy_tin 95 + 8 → 100)
  - id rỗng → warn, không count (source pin `push_warning`)
  - gains chứa `project`/`uy_tin`

**Amend (test cũ, giữ nguyên assertion cũ):**
- `test_activities.gd`: `try_activity("lam_project")` → `gains.project == "p_noibo"`, `gains.uy_tin == 10`, `gs.project_count == 1`, `today_activities[-1]` có 2 key.
- `test_activities_data.gd`: 3 hook mới đúng chuỗi §4.1 (append assertion, không sửa assertion cycle 2).
- `test_unlock_core.gd` / `test_unlock_data.gd`: rule `khach_truong_nhom` unlock khi `project_count >= 1`, chưa unlock khi 0; `khach_giam_doc` khi >= 3.
- `test_customer_catalog.gd`: 2 khách mới có trong catalog + `unlock_rule` đúng id (amend nếu test assert số lượng).
- `test_hud_activity.gd`: bấm `lam_project` → toast `Hoàn thành project! +10 uy_tin`.
- `test_day_end.gd`: entries có `project` → dòng `Project hoàn thành: +N uy_tin`; entries không có → ẩn.

**Gate:** `bash repair-shop-game/tests/run_suite.sh` → `TOTAL_FAILURES=0` + không `SCRIPT ERROR` → `GATE PASS`; smoke `--quit-after 60` 0 SCRIPT ERROR trước mỗi commit.

## 9. Files

| | File |
|---|---|
| Mới | `tests/test_project_hook.gd` (+`.uid`), `data/customers/truong_nhom.tres`, `data/customers/giam_doc.tres` |
| Sửa | `scripts/data/hook_runner.gd` (whitelist + 2 key), `scripts/autoload/game_state.gd` (+`project_count`), `scripts/progression/unlock_core.gd` (+INPUT), `scripts/ui/hud.gd` (toast branch), `scripts/ui/summarize.gd` (dòng mới), `tools/build_week_schedule.gd` (3 hook + validate), `tools/build_progression.gd` (2 rule), `data/week_schedule.tres` + `data/unlock_rules.tres` (regen), tests (6 file amend + `run_tests.gd` register) |

## 10. Cam kết plan

- `game_state.gd` chỉ **thêm** `project_count` (không đổi field khác; `begin_new_day` không reset).
- `unlock_core.gd` chỉ thêm 1 input name (không đổi logic refresh/unlock/pattern).
- KHÔNG sửa `main.tscn`, `unlock_rules` data file tay (chỉ qua builder), `ban_hoc.tres`.
- Exact strings: `Hoàn thành project! +%d uy_tin`, `Project hoàn thành: +%d uy_tin` (test assert đúng chuỗi).
- `.uid` files commit kèm; KHÔNG stage file dirty của user (`cafe.tscn`, `animation_*.gd`, `generate_chibi.py`, WIP `run_tests.gd` dòng `test_outfit`).
