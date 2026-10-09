# Spec 4b — Màn hình Chỗ làm (backdrop + nâng cấp + goal tracker)

- **Ngày:** 2026-10-09
- **Phụ thuộc:** Spec 4a (`2026-10-09-progression-unlock-design.md`) — UnlockCore, unlock_changed, WorkspaceUpgrades, workspace_tier đã có và đã merge.
- **Trạng thái:** Chờ review của người chơi.

## 1. Mục tiêu

Cho người chơi xem chỗ làm hiện tại theo tier (bàn học → phòng → tiệm), nâng cấp bằng tiền + uy tín, và thấy tiến trình mở khoá (milestone + danh sách khách). Scope = **Backdrop + panel nâng cấp** trong **1 scene riêng mở từ HUD** (đã chốt ở brainstorm).

Không có: map chơi được, HUD nhúng tracker, autoplay/hoạt ảnh.

## 2. Components & interfaces

### 2.1 Scene `scenes/ui/workplace_screen.tscn` + `scripts/ui/workplace_screen.gd`

Structure (code-built children theo pattern `hud.gd::_build_ui`):

- **Backdrop** — đọc `game_state.workspace_tier` (clamp 0..2), 3 preset Node2D:
  - tier 0 `desk`: mặt bàn + đèn bàn
  - tier 1 `room`: + kệ tường + ổ cắm
  - tier 2 `shop`: + biển hiệu + quầy
  - Primitive tối giản, style low-poly DESIGN.md §8. Không asset ngoài.
- **UpgradePanel** — hiện tier hiện tại → tier kế (`data/workspace_upgrades.tres`: ROOM 1.000.000/uy_tin 40; SHOP 5.000.000/uy_tin 120), nút "NÂNG CẤP" (tắt khi tier = 2).
- **GoalTracker** — 2 khối:
  - *Milestones*: mỗi enabled rule trong `data/unlock_rules.tres` →1 dòng: tên rule (`UnlockRule.label`, field thêm ở §2.4) + % (`min(giá trị hiện tại / ngưỡng)`, rule nhiều điều kiện lấy % nhỏ nhất) + dấu ✓ khi `core.is_unlocked(id)`.
  - *Khách*: `CustomerCatalog.load_all()` →1 dòng/khách; nếu `customer.unlock_rule != ""` và chưa unlock → hàng mờ (`modulate.a = 0.4`) + ghi chú `Chưa mở` (cần gì → xem mục Milestones phía trên); unlock_rule rỗng = luôn thấy.
- **Toast** — `Label` transient trong scene: hiện text1.5s rồi ẩn (dùng cho kết quả nâng cấp, §3.2–3.3).
- **Đóng:** nút ✕ + `Esc` → ẩn overlay (giữ instance); mở lại từ HUD → refresh trạng thái (main.tscn giữ nguyên, scene load động).

### 2.2 UnlockCore — scene-local

- Tạo trong `_ready()`: `setup(UnlockRuleSet.load_all_from res://data/unlock_rules.tres)` → `refresh(game_state)` → nghe `unlock_changed` → chỉ cập nhật ô milestone tương ứng (emit-once semantic từ 4a).
- Refresh lại sau mỗi lần upgrade thành công. **Không** autoload mới, **không** sửa `game_state.gd`.

### 2.3 HUD — entry point

- `scripts/ui/hud.gd::_build_ui()` +1 `Button` "CHỖ LÀM" (additive).
- Click → `load("res://scenes/ui/workplace_screen.tscn").instantiate()` → `add_child` overlay full-rect (không sửa `main.tscn`).

### 2.4 Catalog & data hooks

- `scripts/progression/unlock_rule.gd` +1 field: `@export var label: String = ""`.
- `tools/build_progression.gd`: gán nhãn 4 rule — `may_co`→"Máy cổ", `may_phuc_tap`→"Máy phức tạp", `khach_giao_vien`→"Khách giáo viên", `khach_phong_tin`→"Khách phòng tin" → chạy lại tool regen `data/unlock_rules.tres`.
- `scripts/customer_def.gd` +1 field: `@export var unlock_rule: StringName = &""`.
- `data/customers/*.tres`: `ban_hoc` → `&""` (luôn mở), `giao_vien` → `&"khach_giao_vien"`, `hoai_niem` → `&"khach_phong_tin"`.
- Không helper mới trong `CustomerCatalog` — screen tự filter (đơn giản, 1 chỗ dùng).

### 2.5 Files

| Loại | File |
|---|---|
| Mới | `scenes/ui/workplace_screen.tscn`, `scripts/ui/workplace_screen.gd`, `tests/test_workplace_screen.gd` |
| Sửa (additive) | `scripts/ui/hud.gd` (+1 nút), `scripts/customer_def.gd` (+1 field), `scripts/progression/unlock_rule.gd` (+1 field), `tools/build_progression.gd` (+label), `data/unlock_rules.tres` (regen), `data/customers/*.tres` (3 file +1 dòng), `tests/run_tests.gd` (+đăng ký) |
| Không sửa | `game_state.gd`, `main.tscn`, `unlock_core.gd`, `workspace_upgrades.gd` |

## 3. Behavior

1. Mở scene → backdrop theo tier hiện tại; tracker đã refresh (milestone + khách đúng trạng thái GameState).
2. Upgrade thành công (`try_upgrade` trả `""`): `money` trừ, `workspace_tier` +1 (logic 4a, validate-before-mutate) → toast "Đã mở chỗ làm mới!" → backdrop rebuild → core refresh → tracker cập nhật.
3. Upgrade fail: toast theo reason key — `no_money`→"Chưa đủ tiền", `low_uy_tin`→"Uy tín còn thấp", `condition`→"Điều kiện chưa đạt", `max_tier`→"Đã là tiệm rồi"; **không mutate** `money`/`workspace_tier`.
4. Milestone mở khoá trong lúc scene đang mở (upgrade thỏa điều kiện uy_tin/tier) → `unlock_changed` phát → ô đó chuyển ✓ ngay, không cần mở lại.
5. Đóng bằng ✕ hoặc `Esc` (ẩn overlay), mở lại từ HUD → trạng thái đọc lại từ GameState (không cache cũ).

## 4. Error handling

| Tình huống | Xử lý |
|---|---|
| `core.parse_errors()` ≠ rỗng sau setup/refresh | Dòng warning đỏ trong tracker + `push_warning` (fail-safe; data đã validate bằng test) |
| `customer.unlock_rule` trỏ id không có trong rules | Test data chặn trước (§5.5); runtime coi như chưa unlock + warning |
| `workspace_tier` ngoài 0..2 | Clamp về 2 |
| `workspace_upgrades.tres` / `unlock_rules.tres` load lỗi (null) | Panel/tracker hiện "Thiếu dữ liệu progression", nút nâng cấp tắt |
| GameState null (test cô lập) | Screen không instantiate crash — guard `_ready`; các test dùng mock |

## 5. Test list (`test_workplace_screen.gd`, headless, `GameState.new()` làm mock)

1. **Backdrop theo tier:** tier 0/1/2 → node preset đúng tên hiện, tier 9 → clamp về shop.
2. **Upgrade qua UI — fail:** `money` < cost → toast reason đúng, `money`/`workspace_tier` giữ nguyên tuyệt đối.
3. **Upgrade qua UI — success:** money đủ + uy_tin đủ → tier+1, tiền trừ đúng, backdrop đổi preset, tracker refresh.
4. **Tracker milestones:** số dòng = số enabled rule; `knowledge 0 → 100` + refresh → dòng `may_co` chuyển trạng thái unlock.
5. **Tracker khách + catalog hook:** `giao_vien` với uy_tin 0 → hàng mờ; uy_tin 60 + refresh → sáng; mọi `customer.unlock_rule` ≠ "" khớp id trong `unlock_rules.tres`.
6. **HUD entry:** `_build_ui()` sinh nút "CHỖ LÀM", signal connected, click instantiate scene.
7. **Data cũ không regression:** toàn bộ suite hiện tại vẫn xanh (`TOTAL_FAILURES=0`, không `SCRIPT ERROR`).

Gate: `bash repair-shop-game/tests/run_suite.sh` → `TOTAL_FAILURES=0` + `GATE PASS`.

## 6. Ngoài scope (defer)

- Hiệu ứng/animation khi unlock (chỉ đổi trạng thái).
- Âm thanh.
- Tiếng Anh (game thuần Việt).
- Nút nâng cấp trên HUD trực tiếp (mọi thứ qua scene này).
- Persist tier/unlock qua session (thuộc cycle save — Spec 4a đã ghi nhận).
- Đổi `game_state.gd` (session kia đang hoạt động trên file này).
