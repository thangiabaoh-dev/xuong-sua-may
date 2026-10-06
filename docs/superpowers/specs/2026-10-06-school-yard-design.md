# Spec — Khu trường ngoài trời (Sub-project A: School Yard)

> Thuộc decomposition "Cả khu trường". Spec này được duyệt qua brainstorming (design approved in-chat).
> Authority chain: `repair-shop-game/DESIGN.md` (§3 địa điểm, §8 kỹ thuật) > spec này > plan.

## 1. Mục tiêu & phạm vi

**Mục tiêu:** dựng `school_yard.tscn` — môi trường low-poly "sân trường" (sân + hàng rào + cổng + cột cờ + cây + mặt đứng trường), test headless pin cấu trúc, xem được trong Godot editor.

**Trong phạm vi:**
- Scene `scenes/school_yard.tscn` (tự chứa, không instance gì ngoài project).
- Test `tests/test_school_yard.gd` + append vào harness.
- Helper `world_origin()` thêm vào `tests/test_case.gd` (test mới dùng; **không** sửa 2 test file cũ).

**Ngoài phạm vi (không làm ở đây):**
- Không nối vào `main.tscn` / đổi `run/main_scene` (xem §7).
- Không đi lại được trong sân (chưa có player spawn trong scene này) — plan D (scene flow) nối sau.
- Không chữ trên bảng hiệu (để ngỏ §9#1 tên trường thật/hư cấu).
- Không interior (B: khối học đường; C: thư viện — spec riêng).

## 2. Ngữ cảnh & decomposition

- DESIGN §3: địa điểm #2 **Sân trường** — "Cảnh đời thường: chơi, trò chuyện, giữa giờ".
- Người chơi ở trường 07:00–11:30 & 13:45–17:00 (§4.1) — sân là backdrop giai đoạn đi học.
- Decomposition đã chốt: **A (spec này) → B (khối học đường) → C (thư viện) → D (chuyển scene + time-gating)**.
- **Phân công:** campus line (A–D) thuộc phiên hội thoại này; phiên song song (machine catalog) không đụng các file trên.

## 3. Scene contract — `school_yard.tscn`

Root `SchoolYard` (`Node3D`) với **đúng 6 node con trực tiếp**, tên chính xác:

| Tên | Loại | Nội dung |
|---|---|---|
| `Ground` | Node3D | Sân 40 (x) × 30 (z), mặt trên `y = 0`; vạch sân = box mỏng décor (không collision) |
| `Fence` | Node3D | Hàng rào cao 1.2, dày 0.1 — 5 đoạn con: `North`, `East`, `West`, `SouthLeft`, `SouthRight`; khe cổng giữa phía nam rộng ~6m (x ∈ [−3, 3]) |
| `Gate` | Node3D | 2 cột + xà ngang qua khe; **khung bảng trơn** treo trên xà (không chữ) |
| `Flagpole` | Node3D | Trụ cột cờ + lá cờ, đặt giữa sân lệch về nam |
| `Trees` | Node3D | 3 cây: thân hộp + tán hộp/cầu, rải hai bên |
| `SchoolFacade` | Node3D | Mặt đứng 2 tầng cạnh **bắc** (z ≈ −15), quay mặt vào sân (+z): khối hộp + nhịp cửa sổ + cửa vào + **bảng trơn** phía trên cửa |

- Phong cách: **low-poly stylised**, primitive (BoxMesh/CylinderMesh/SphereMesh) + `StandardMaterial3D` màu phẳng — đúng §8, không model chi tiết.
- Toàn scene **không có node chữ** (`Label3D`/`Font`) — guard §9#1.

## 4. Collision contract

- **SOLIDS** (bắt buộc `StaticBody3D` → `CollisionShape3D`): `Ground`, `Fence` (cả 5 đoạn), `Gate`, `SchoolFacade`.
- **Décor** (KHÔNG bắt buộc va chạm): `Flagpole`, `Trees`, vạch sân, bảng trơn, cửa sổ.
- Sàn: shape `BoxShape3D` top **chính xác y = 0** (giống workshop — hợp đồng spawn/đứng của plan D sau).

## 5. Test contract — `tests/test_school_yard.gd`

Mẫu `test_workshop.gd` (RED trước khi scene tồn tại). Assert:

1. Scene load được; root tên `SchoolYard`; **đúng 6 con trực tiếp**.
2. Đủ 6 tên con ở §3.
3. `SOLIDS` mỗi cái chứa `StaticBody3D` → `CollisionShape3D`.
4. `Ground`: box `40 × 30`, top `y = 0` (dùng `world_origin()` từ `test_case.gd`).
5. `Fence`: có đủ 5 đoạn đúng tên `North/East/West/SouthLeft/SouthRight`, mỗi đoạn có va chạm; **khe nam giữa tính theo CẠNH**: mép trong của `SouthLeft` (position.x + chiều dài/2) `< −2.5` và mép trong của `SouthRight` (position.x − chiều dài/2) `> +2.5` → khe giữa ≥ 5m — non-vacuous (dời đoạn về giữa là FAIL ngay, có mutation proof).
6. **Không node chữ nào** trong scene (`Label3D` = fail).
7. `root.free()` cuối `run()` — output pristine (không leak).

**Chạy:** lệnh chuẩn plan cũ —
`godot --headless --path repair-shop-game --import >/dev/null 2>&1; godot --headless --path repair-shop-game -s res://tests/run_tests.gd`

## 6. Quy trình thực thi

TDD nghiêm ngặt (superpowers:executing-plans + test-driven-development):

1. RED: viết test (scene chưa có → `FAIL school_yard.tscn must load`, exit 1).
2. GREEN: dựng scene → suite `TOTAL_FAILURES=0`.
3. Mutation proof (≥2): đẩy sàn khỏi y=0 → FAIL top y=0; thu hẹp khe nam (dời đoạn rào) → FAIL khe; xoá tên đoạn rào → FAIL. Restore byte-identical → xanh.
4. Smoke run `--quit-after 60` exit 0 (main scene không đổi).
5. Commit riêng, message theo style repo: `feat: low-poly school yard with fenced ground and facade`.
   - File: thêm mới `scenes/school_yard.tscn`, `tests/test_school_yard.gd`, `tests/test_school_yard.gd.uid`; sửa `tests/test_case.gd` (append `world_origin()`), `tests/run_tests.gd` (append test script).
   - **Trước khi append/commit `run_tests.gd`:** kiểm tra phiên song song không có thay đổi dở dang trên file này (luôn `git status` + diff).

## 7. Rủi ro & phối hợp

- **Phiên song song:** đang làm machine catalog, có commit trên `repair-shop-game/`. File giao nhau duy nhất: `tests/run_tests.gd` (append) — kiểm tra trạng thái trước khi thao tác; các file khác hoàn toàn riêng.
- **Không phá test hiện tại:** không sửa `main.tscn`, `workshop.tscn`, `test_main_scene.gd`, `test_workshop.gd`.
- **Bảng trơn:** không bake tên trường cho tới khi §9#1 chốt.

## 8. Câu hỏi mở

Không có — design đã duyệt in-chat (Hướng 1: scene duy nhất; xem scene + test; bảng trơn).
