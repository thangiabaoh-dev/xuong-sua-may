# Spec — Cycle 2: Tri thức / Thưởng đọc sách

- **Ngày:** 2026-10-10
- **Branch:** cắt từ `feat/schedule-engine` @ `11320a6`
- **Trạng thái:** design đã duyệt (brainstorming), chờ review spec → viết plan
- **Spec trước:** `2026-10-08-schedule-engine-design.md` (§10 giao cycle 2), `2026-10-09-progression-unlock-design.md` (chỉ tiêu thụ knowledge, không sinh)

## 1. Mục tiêu

Điền hook rỗng của cycle 1: các hoạt động đọc sách / đi học / sự kiện sinh `knowledge`,
để người chơi tích lũy tri thức theo ngày → mở khoá **Máy cổ** (`knowledge >= 50`) và
**Máy phức tạp** (`knowledge >= 80`) qua `UnlockRule`, đồng thời mở pool máy khó hơn
qua `MachineDef.min_knowledge`.

Nhịp chơi: **chậm** — tri thức là mục tiêu dài hạn, unlock 50 ở khoảng tuần 3-4,
80 ở tuần 5-6 (tích đều, không bắt buộc đọc sách mỗi ngày).

## 2. Scope

**Trong scope:**
- 4 hoạt động sinh knowledge: `doc_sach_nha`, `doc_thu_vien`, `di_hoc`, `su_kien_doi_thuong`
- Mechanism `ActivityDef.hook` (format key–value) + executor mới
- Phản hồi: toast trên HUD + dòng tổng trong SUMMARIZE

**Ngoài scope (YAGNI):**
- Đọc sách không sinh uy_tin/tiền
- Không có catalog sách riêng trong kho (`InventoryPanel` cycle inventory không đổi)
- Không toast khi unlock milestone (workplace tracker đã hiển thị ✓)
- Cycle 3 (`lam_project` → `completed_projects`) đi spec riêng, chỉ dùng lại format hook

## 3. Hook mechanism (approach 1 — đã duyệt)

### 3.1 Format

`ActivityDef.hook: String` — cycle 1 đã khai báo, để rỗng `""` cho mọi activity.

Cycle 2 định nghĩa:

```
"key:value[,key:value]*"
```

Cycle 2 chỉ dùng một key: **`knowledge_rate`** — đơn vị **knowledge/phút** (float ≥ 0).

Ví dụ: `hook = "knowledge_rate:0.02"`.

Cycle 3 sẽ dùng key mới (`complete_project`) cùng format — đa hiệu ứng về sau chỉ cần
thêm cặp `key:value` (vd `"knowledge_rate:0.02,uy_tin:1"`) nếu có nhu cầu.

### 3.2 Executor — `scripts/data/hook_runner.gd` (mới)

Static API, pattern `ScheduleLogic` / `WorkspaceUpgrades` (headless-testable):

```gdscript
static func apply(gs: Node, hook: String, consumed: int) -> Dictionary
```

- Hook `""` → trả `{}`, không làm gì.
- Parse từng cặp `key:value` (tách `,` rồi `:`) — **mỗi pair xử lý độc lập**, pair lỗi
  chỉ bị bỏ qua + `push_warning`, không crash (bảng §8).
- Key `knowledge_rate`:
  - `gain_f = rate × consumed` (phút thực consume, đã clamp bởi slot end)
  - `gs.knowledge_remainder += gain_f`
  - `N = int(gs.knowledge_remainder)`; `gs.knowledge_remainder -= N`
  - `gs.knowledge += N` → trả `{"knowledge": N}` (N = 0 thì không thêm key)
- Key lạ / value không parse được float / rate < 0 → `push_warning` + bỏ qua pair.
- `knowledge` không bao giờ giảm (rate luôn ≥ 0 nhờ validate ở builder + check ở runner).

**Remainder:** field mới `game_state.gd`:

```gdscript
var knowledge_remainder: float = 0.0
```

- Không reset trong `begin_new_day` (phần lẻ của hôm trước vẫn còn giá trị).
- Đơn vị: chia 1.0 — khi `knowledge_remainder >= 1.0` mới chuyển thành int.

### 3.3 Tích hợp — `ScheduleCore.try_activity`

Sau khi tính `consumed` và trước khi return `{"ok": true, ...}`:

```gdscript
var gains := HookRunner.apply(gs, act.hook, consumed)
# push vào today_activities nếu gains["knowledge"] > 0 (xem §5)
return {"ok": true, "reason": "", "gains": gains}
```

- Dictionary trả về thêm key `gains` (Dict, có thể rỗng `{}`) — **không đổi** key cũ
  `ok` / `reason` (mọi test hiện tại đều check 2 key này).
- Lỗi (`ok: false`) → không chạy hook, không có `gains`.

## 4. Bảng rate (data, builder)

`tools/build_week_schedule.gd` ghi hook khi build → regen `data/week_schedule.tres`.

| Activity | Slot | phút trọn | rate/phút | gain ước tính |
|---|---|---|---|---|
| `doc_sach_nha` | WORKSHOP (CHỌN) 120′ | 120 | 0.020 | ~2.4 |
| `doc_thu_vien` | LIBRARY (CHỌN) 135′ | 135 | 0.030 | ~4.0 |
| `di_hoc` | SCHOOL 270′/195′ | 270 | 0.008 | ~2.2 |
| `su_kien_doi_thuong` | HOLIDAY 900′ | 900 | 0.010 | ~9.0 |

- Rate là **data** — chỉnh balance không cần sửa code (chỉ regen `.tres`).
- Builder validate: rate ≥ 0, key thuộc whitelist {`knowledge_rate`} → lỗi build nếu sai.
- Check nhịp (chậm): đi học đều ~2/ngày + đọc thỉnh thoảng 2-4/lần
  → ~10-15/tuần → unlock 50 ở tuần ~3-4, 80 ở tuần ~5-6.

## 5. Phản hồi UI

### 5.1 HUD toast

- `scripts/ui/hud.gd`: thêm `_lbl_toast: Label` (khung nhỏ phía trên giữa,
  pattern toast `workplace_screen.gd` — 1.5s `Tween`, chỉ hiện khi node in-tree).
- `_on_activity`: sau `ok && gains.knowledge > 0` → hiện `+N tri thức`
  (`N = gains.knowledge`).
- Hiện tại `_on_activity` chỉ mở SUMMARIZE/reload — thêm nhánh toast, không đổi flow cũ.

### 5.2 SUMMARIZE dòng tổng

- `today_activities` dict thêm field `"knowledge": int` **chỉ khi gain > 0**
  (dict hiện có `id/label/minutes` — thêm field không phá test cũ check `minutes`).
- `scripts/ui/summarize.gd`: dòng mới `Tri thức nhận: +Tổng` — tổng từ
  `sum(a.knowledge)` của `today_activities` (không tính lại từ rate).
- Ẩn dòng khi tổng = 0.

## 6. Error handling

| Tình huống | Hành vi |
|---|---|
| Hook `""` (mo_panel, nghi, ...) | `{}`, không warn |
| Key lạ `foo:1` | `push_warning` + bỏ qua pair |
| Value không phải float / rate < 0 | `push_warning` + bỏ qua pair |
| Pair lỗi trong chuỗi nhiều cặp | bỏ qua pair lỗi, vẫn chạy pair tốt |
| Activity ngoài khung giờ | `try_activity` trả `ok:false` — hook **không** chạy |
| Slot hết → phút clamp | gain tính trên phút thực consume (ít hơn nếu bị cắt) |
| Builder ghi key không whitelist | **build fail** (push_error + dừng) |

## 7. Testing (TDD — RED trước khi implement)

**Mới:**
- `tests/test_hook_runner.gd` (+ `.uid`, register cuối `run_tests.gd`):
  - hook rỗng → `{}` + state không đổi
  - `knowledge_rate:0.03` × 135′ → knowledge +4, remainder ≈ 0.05
  - **remainder accumulation:** gain 0.6 hai lần → lần 1 `+0`, lần 2 `+1`, remainder ≈ 0.2
  - key lạ → warning, pair tốt kế bên vẫn chạy
  - rate âm / value rác → warning, knowledge không đổi
  - nhiều cặp `"knowledge_rate:0.01"` (đơn, không crash)

**Amend (test cũ, giữ nguyên entry):**
- `test_activities.gd`: `try_activity("doc_thu_vien")` → `gains.knowledge == 4`,
  `gs.knowledge` tăng đúng; `mo_panel` → `gains` rỗng; `ok:false` → không có gains.
- `test_activities_data.gd`: 4 activity có hook khớp regex
  `^knowledge_rate:\d+(\.\d+)?$`; rate ≥ 0.
- `test_hud_activity.gd`: bấm hoạt động đọc → `_lbl_toast` hiện `+N tri thức`,
  sau 1.5s ẩn; activity không hook → không toast.
- `test_day_end.gd`: hôm có đọc → SUMMARIZE dòng `Tri thức nhận: +Tổng` đúng tổng;
  hôm không đọc → dòng ẩn.

**Gate:** `bash repair-shop-game/tests/run_suite.sh` → `TOTAL_FAILURES=0`,
không `SCRIPT ERROR` → `GATE PASS`; smoke `godot --headless ... --quit-after 60`
0 SCRIPT ERROR trước mỗi commit.

## 8. Files

| | File |
|---|---|
| Mới | `scripts/data/hook_runner.gd` (+`.uid`), `tests/test_hook_runner.gd` (+`.uid`) |
| Sửa | `scripts/schedule_core.gd` (gains), `scripts/autoload/game_state.gd` (+remainder), `tools/build_week_schedule.gd` (hook values + validate), `data/week_schedule.tres` (regen), `scripts/ui/hud.gd` (toast), `scripts/ui/summarize.gd` (dòng tổng) |
| Test sửa | `test_activities.gd`, `test_activities_data.gd`, `test_hud_activity.gd`, `test_day_end.gd`, `run_tests.gd` (register 1 entry) |

## 9. Cam kết plan (từ Global Constraints các plan trước)

- KHÔNG sửa `unlock_core.gd` / `workspace_upgrades.gd` (chỉ tiêu thụ knowledge có sẵn).
- `game_state.gd` chỉ **thêm** `knowledge_remainder` (không đổi field hiện có).
- `main.tscn` không đổi (HUD scene riêng nếu cần — check khi plan).
- `.uid` files được commit (repo convention).
- Exact strings: `+N tri thức`, `Tri thức nhận: +Tổng` (test assert đúng chuỗi này).
