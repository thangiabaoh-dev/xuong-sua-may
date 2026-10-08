# Spec 1 — 5 Maps Visual (BoxMesh, no wiring)

Date: 2026-10-07
Status: validated design (user approved §1-§3 in chat)
Parent scope: Visual + wiring + full lich tuan §4, split into 3 specs. This is Spec 1/3.

## 1. Intent (agreed)

- Outcome: 5 maps con lai theo DESIGN §3 co the mo rieng trong Godot, khop ti le chibi, san khong lot player.
- Already done: `workshop.tscn` (xuong), `schoolyard.tscn` (san, 20x20, 8 nodes, test green).
- Non-goals (Spec 2/3): SceneManager, GameState location/time, main chuyen map, lich tuan §4, texture anh reference, UI lich.
- Success: 5 scenes load duoc, moi san top y=0, `run_suite.sh` GATE PASS (`TOTAL_FAILURES=0`, no SCRIPT ERROR).

## 2. Architecture (§1 approved)

- 5 files moi: `repair-shop-game/scenes/gate.tscn`, `classroom.tscn`, `library.tscn`, `cafe.tscn`, `street.tscn`.
- Pattern giong `schoolyard.tscn`: root Node3D, `BoxMesh` + `StandardMaterial3D`, 1 floor `StaticBody3D` + `BoxShape3D`.
- Khong sua: `main.tscn`, `scripts/autoload/game_state.gd`, khong them Autoload.
- Quy uoc: Y-up trong scene, don vi met, cua ~2m, ban ~0.75m nhu workshop.
- Root names (test assert): Gate, Classroom, Library, Cafe, Street.

## 3. Components (§2 approved)

- `gate.tscn` (Cong truong): san 16x12 + 2 tru + lintel bang ten + hang rao 2 doan.
- `classroom.tscn` (Lop/hanh lang): san 12x10 + bang + buc + 4 bo ban ghe box.
- `library.tscn` (Thu vien): san 12x10 + 3 ke sach cao + 2 ban doc.
- `cafe.tscn` (Quan ca phe): san 10x10 + quay + 3 ban + ghe.
- `street.tscn` (Duong pho Tan Binh): duong 20x6 + via he 2 ben + 2 nha hop + 2 den.
- Moi map 6-9 nodes, 1 floor solid duy nhat, con lai visual. Mau tron phan biet cong nang, chua gan texture.

## 4. Testing (§3 approved)

- Moi map 1 test (khong assert mau sac): `test_gate.gd`, `test_classroom.gd`, `test_library.gd`, `test_cafe.gd`, `test_street.gd`, mau `test_schoolyard.gd`:
  load duoc, root name dung, du REQUIRED nodes, floor BoxShape3D dung kich thuoc + top y=0, guard `packed == null` return som.
- Dau ca 5 vao `TEST_SCRIPTS` trong `tests/run_tests.gd`.
- Gate: `bash repair-shop-game/tests/run_suite.sh` → `TOTAL_FAILURES=0` + `GATE PASS`.

## 5. Risks

- Ten root/node lech → test fail ten, sua test hoac scene cho khop, khong crash nho guard.
- Shape lech top y → player lot/treo, test `top y=0` chan.
- Spec 2/3 phu thuoc Spec 1 xong va xanh suite.

## 6. Next

- Spec 2: SceneManager + `current_location` chuyen tay/debug.
- Spec 3: Full lich tuan §4 (T2-CN, le, ca sua, tu do) de len tren.
