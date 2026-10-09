# Spec — Tiến trình & Mở khoá (Unlock Engine + Workspace Tier)

- **Ngày:** 2026-10-09
- **Phạm vi:** DESIGN.md §7 — phần backend (bước 1 của 2; bước 2 = scenes + UI → spec `4b`)
- **Nguồn:** DESIGN.md §7 (bảng mở khoá, cung truyện, "không bị ép tiến — bỏ lỡ là mất thật")
- **Quyết định đã chốt với người chơi:**
  1. Full §7, tách **2 spec**: 4a backend (spec này) → 4b scenes + goal tracker UI.
  2. Điều kiện mở khoá diễn đạt bằng **biểu thức string** (`"knowledge >= 50 and uy_tin >= 30"`).
  3. Approach **A**: Godot `Expression` builtin — probe headless xác nhận: variables ✓, method call `has_project()` trên RefCounted base ✓, short-circuit ✓, parse error có code+text (vd err=31 "Unexpected character.") ✓.

## 1. Trong / ngoài scope

**Trong scope:**
- Unlock engine data-driven: `UnlockRule` (condition string) + `UnlockCore` (evaluate, query, event).
- Workspace tier model: `DESK → ROOM → SHOP`; `try_upgrade` validate-before-mutate.
- Permanent-unlock semantics (xem §4).
- Test headless TDD toàn bộ; dữ liệu `.tres` sinh bởi tool + test validate.

**Ngoài scope:**
- Tích hợp unlock vào catalog máy/khách/lỗi — file hiện có do session khác sở hữu; hook tích hợp để spec 4b / cycle của họ.
- UI goal tracker, cảnh 3 chỗ làm, mua dụng cụ (máy hàn…) — spec 4b.
- Sinh tri thức (đọc sách, cycle 2) / hoàn thành project (cycle 3) — cycle khác; spec này chỉ **tiêu thụ** các chỉ số đó qua field.

## 2. Thành phần

File mới, đều trong `scripts/progression/` — **không sửa file của session khác**.

### 2.1 `unlock_rule.gd` — Resource

```
class_name UnlockRule extends Resource
@export var id: StringName          # "may_co", "khach_giao_vien", ...
@export var target_kind: String     # "machine" | "customer" | "part" | "feature"
@export var target_id: StringName   # id trong catalog tương ứng (opaque với engine)
@export var condition: String       # Godot Expression, vd "knowledge >= 50"
@export var enabled: bool = true
```

### 2.2 `unlock_context.gd` — RefCounted (base cho Expression)

```
class_name UnlockContext extends RefCounted
var completed_projects: Array[StringName] = []
func has_project(id: StringName) -> bool
```

`UnlockCore.refresh()` copy `GameState.completed_projects` sang context trước khi evaluate.

### 2.3 `unlock_core.gd` — RefCounted

```
class_name UnlockCore extends RefCounted
signal unlock_changed(id: StringName)      # chỉ phát khi transition locked -> unlocked

func refresh(game_state: Node) -> void     # evaluate lại toàn bộ rule
func is_unlocked(id: StringName) -> bool
func unlocked_ids() -> Array[StringName]
func parse_errors() -> Array[String]       # "rule_id: <Expression error text>"
```

- Input variables khai báo khi `Expression.parse()`: `money, knowledge, uy_tin, ky_luat, workspace_tier` — đọc từ `game_state` tại thời điểm `refresh`.
- Base instance: `UnlockContext` (method `has_project`).
- Một `UnlockCore` instance sở hữu 2 set: `unlocked` (hiện mở) và `permanent` (đã từng mở — không bao giờ remove, xem §4).

### 2.4 `workspace_upgrades.gd` — Resource + logic

```
class_name WorkspaceUpgrade extends Resource
@export var to_tier: int             # 1 = ROOM, 2 = SHOP
@export var cost: int
@export var uy_tin_req: int
@export var condition: String        # thêm ràng buộc biểu thức, "" = không ràng buộc

class_name WorkspaceUpgrades extends RefCounted   # logic mua
static func try_upgrade(game_state: Node, defs: Array) -> String
    # "" = thành công; reason key: "max_tier" | "no_money" | "low_uy_tin" | "condition"
```

### 2.5 Dữ liệu

- `data/unlock_rules.tres` — sinh bởi `tools/build_progression.gd`. Rule khởi tạo (cycle hiện tại chưa có reading/project nên condition tiền tri thức/tier là mục tiêu dài hạn):
  - `may_co` — machine, `knowledge >= 50`
  - `may_phuc_tap` — machine, `knowledge >= 80`
  - `khach_giao_vien` — customer, `uy_tin >= 60`
  - `khach_phong_tin` — customer, `uy_tin >= 90 and workspace_tier >= 1`
- `data/workspace_upgrades.tres` — 2 defs: DESK→ROOM `cost 1_000_000, uy_tin_req 40`; ROOM→SHOP `cost 5_000_000, uy_tin_req 120`. Condition `""`.

### 2.6 `game_state.gd` — cộng 2 field (additive)

```
var workspace_tier: int = 0            # 0 DESK, 1 ROOM, 2 SHOP
var completed_projects: Array[StringName] = []
```

Đây là **điểm phối hợp** với cycle 3 (session khác sẽ đọc/ghi `completed_projects`) — điểm đụng duy nhất, tối thiểu.

## 3. Data flow

1. `refresh(gs)` gọi khi stat đổi (4b/cycle khác hook; 4a chỉ test gọi trực tiếp):
   - Với mỗi rule `enabled`: `parse` (cache theo rule id — parse 1 lần, execute nhiều) → `execute(inputs, ctx)`.
   - `true` + chưa từng mở → vào `unlocked` + `permanent`, phát `unlock_changed(id)` **một lần**.
   - `true` → vào `unlocked` (nếu chưa); `false` → **không remove** nếu đã trong `permanent` (§4); `false` + chưa từng mở → giữ locked.
   - `null` (kết quả) → ghi vào `parse_errors()`-style error list, coi như `false`, test gate sẽ chặn (§5).
2. `is_unlocked(id)` → O(1) lookup `unlocked`.
3. `try_upgrade(gs, defs)`:
   1. Tìm `defs` có `to_tier == gs.workspace_tier + 1`; không có → `"max_tier"`.
   2. `gs.money < cost` → `"no_money"`; `gs.uy_tin < uy_tin_req` → `"low_uy_tin"`; `condition != ""` && evaluate false → `"condition"`.
   3. Tất cả pass → **mới** trừ `money`, `workspace_tier = to_tier`, trả `""`.
   4. **Không mutate gì ở mọi nhánh fail** (validate-before-mutate, cùng pattern `change_map`).

## 4. Quyết định semantics: unlock vĩnh viễn

Rule có `money >= 100000` sẽ trả `false` trở lại khi người chơi tiêu tiền — nhưng **unlock đã nhận không được thu hồi** (mua xong dụng cụ mất quyền mở máy cổ = bug cảm nhận người chơi, DESIGN "bỏ lỡ là mất thật" nói về cơ hội chưa tới, không phải mất thứ đã đạt được).

- Rule nào đã từng `true` → id vào `permanent`; các `refresh` sau không bao giờ remove khỏi `unlocked` nữa.
- Điều kiện **tiêu cực** (ví dụ chặn theo `ky_luat`) không tồn tại trong bảng rule khởi tạo; nếu sau này cần, rule đó phải đặt `enabled` theo kiểu điều kiện khác — ngoài spec này.
- Test chứng minh: unlock bằng `money >= 100` khi money=200 → mở; set money=0 → `refresh` → vẫn `is_unlocked == true`.

## 5. Error handling

| Tình huống | Xử lý |
|---|---|
| Condition parse error | `parse_errors()` trả `"rule_id: <text>"`; test assert danh sách rỗng → gate đỏ khi dữ liệu sai |
| Identifier lạ (`null` khi execute) | Cũng vào error list; test execute mọi rule với ctx mặc định expect `true/false` (≠ `null`) |
| Rule `enabled = false` | Bỏ qua khi refresh, không lỗi |
| `try_upgrade` fail | Trả reason key; **không** trừ tiền / đổi tier / phát signal |
| GameState field thiếu (session khác đổi?) | `refresh` đọc với fallback `0`/`[]` — không crash headless |

Không `push_warning` im lặng — lỗi dữ liệu luôn phản ánh qua `parse_errors()` + test đỏ.

## 6. Test (TDD, RED → GREEN mỗi task)

- `tests/test_unlock_core.gd`:
  - Boundary từng input: `knowledge` 49/50, `uy_tin` 59/60 (rule `khach_giao_vien`), `uy_tin` 89/90 + `workspace_tier` 0/1 (rule `khach_phong_tin`).
  - `has_project`: rule thử `"has_project(\"p1\")"` với `completed_projects` có/không.
  - Short-circuit không lỗi; rule `enabled=false` không evaluate (không vào error list dù condition rác).
  - `unlock_changed` phát đúng 1 lần khi transition; không phát khi refresh lại (vẫn mở).
  - **Permanent**: money 200 unlock rule `money >= 100` → money=0 → refresh → vẫn mở.
  - Identifier lạ trong 1 rule test → `parse_errors()` có mặt rule đó.
  - Mọi rule trong `data/unlock_rules.tres` execute với ctx mặc định trả `bool`.
- `tests/test_workspace_upgrade.gd`:
  - `try_upgrade` fail từng nhánh: thiếu tiền / thiếu uy tin / condition sai → reason key + `money`/`workspace_tier` giữ nguyên.
  - Thành công: trừ đúng tiền, tier 0→1, trả `""`.
  - Nhảy tier (đầu vào defs thiếu bước giữa) → `"max_tier"`; tier đã = 2 → `"max_tier"`.
- Đăng ký vào `tests/run_tests.gd`; gate: `bash repair-shop-game/tests/run_suite.sh` → `TOTAL_FAILURES=0` + không `SCRIPT ERROR` (FAILURES xanh mà có SCRIPT ERROR = false green — đã ledger).

## 7. Out of scope / dời lại

- Goal tracker UI, cảnh chỗ làm, nút mua trong game → spec 4b.
- Đọc sách sinh `knowledge`, project hoàn thành điền `completed_projects` → cycle 2/3 (session khác); spec này chỉ dựng field + API.
- Catalog filter (`machine_catalog.is_available()`…) → tích hợp ở 4b/cycle họ, không sửa file họ trong spec này.
