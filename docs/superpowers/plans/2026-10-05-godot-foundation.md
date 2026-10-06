# Godot Foundation (Plan 1/6) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dựng được Godot project chạy được, import model chibi đầy đủ màu, dựng phòng bàn học low-poly, và điều khiển nhân vật di chuyển trong phòng.

**Architecture:** Một `CharacterBody3D` mang mesh chibi, điều khiển bằng hàm thuần `move_direction()` (dễ test headless), trong một phòng va chạm tĩnh (`StaticBody3D` + `BoxShape3D`), camera `SpringArm3D` follow. Toàn bộ logic tách khỏi scene node để test được mà không cần frame game.

**Tech Stack:** Godot 4.7.2 (đã cài, binary `godot` trên PATH), GDScript, headless testing qua `godot --headless -s`.

**Spec:** `repair-shop-game/DESIGN.md` — phần 3 (địa điểm, nhân vật chibi), phần 8 (ghi chú kỹ thuật: Godot 4, GDScript, `chibi.obj` Z-up quay mặt −Y, asset low-poly stylised).

**Scope:** Đây là **Plan 1/6**. Các plan sau: vòng lặp sửa máy, lịch tuần, địa điểm + tri thức + project, khách/dialogue/tư vấn, sự cố + uy tín + kỷ luật + tiến trình. Plan này **không** chứa gameplay sửa máy.

## Global Constraints

- Godot **4.7.2**, binary `godot` (không phải `godot4`, không phải path tuyệt đối).
- Ngôn ngữ **GDScript**. Kiểu trả về bắt buộc khai báo (`-> Vector3`, `-> void`).
- Repo root = `/Users/hoangthangiabao/Documents/file nhảy cảm`, nhánh `main` **chưa có commit nào**, mọi thứ untracked. → **Luôn `git add` đúng đường dẫn** dưới `repair-shop-game/` và `docs/`. **Tuyệt đối không `git add -A` / `git add .`** (sẽ kéo cả các dự án khác vào commit).
- Thư mục cache Godot `.godot/` phải nằm trong `.gitignore`. File `*.import` của asset **phải được commit**.
- Godot 4.4+ sinh file sidecar **`<tên>.gd.uid`** cạnh mỗi script `.gd`. **Phải commit** các file `.uid` cùng script của mình (chúng ghim UID như `.import` ghim asset). Bỏ qua chúng → cây làm việc bẩn vĩnh viễn sau mỗi lần `--import`.
- Model: `repair-shop-game` import từ `chibi-model/chibi.obj` + `chibi.mtl` (nguồn ở `../chibi-model/`). Không sửa file nguồn.
- Nhân vật **Z-up** trong file OBJ (AABB size `(1.12, 1.012, 2.012)`), Godot **Y-up** → **bắt buộc xoay** để đứng thẳng; mặt phải hướng **−Z**.
- Mọi lệnh chạy từ **repo root** unless nói khác.
- Asset environment: **low-poly stylised**, khối đơn giản. Không model chi tiết (DESIGN.md §3).

## Review Focus

Năm thứ spec ngầm định nhưng không task nào tự nhiên chạm tới, dễ hỏng nhất:

1. **Model躺 ngửa** — OBJ Z-up, Godot Y-up: nếu quên xoay, chibi nằm ngửa. → `test_player_scene` asserts AABB đã transform có `size.y ≈ 2.012`, `min.y ≈ 0`.
2. **MTL hỏng / mất màu** — 103 surface dùng chung **23** material; nếu importer không đọc `.mtl`, tất cả xám. → `test_chibi_import` asserts đúng **23** material unique và pin màu `skin`, `hair`, `cap`, `red`.
3. **Test chạy trước khi import** — `load()` trả `null` nếu `.godot/` cache chưa có. → Mọi lệnh test bắt đầu bằng `--import` (xem Task 1 Step 4).
4. **Camera pitch làm hướng đi nghiêng xuống đất** — `Basis` của camera có pitch sẽ khiến `forward` chứa trục Y. → `move_direction()` phải zero-Y rồi normalize; `test_player_move` có case basis bị pitch, assert kết quả `y == 0` và `length() ≈ 1`.
5. **Spawn chìm trong sàn** — capsule cao 2.0, tâm tại y=1.0, player root tại y=0 → đáy capsule正好 tại y=0. Sai sàn (floor top ≠ 0) là vấp. → `test_workshop` asserts floor top `≈ 0`, `test_main_scene` asserts player `global_position.y ≈ 0.1`.

---

## File Structure

```
repair-shop-game/
├── project.godot              # config, main_scene trỏ res://scenes/main.tscn
├── .gitignore                 # .godot/
├── assets/models/
│   ├── chibi.obj              # copy từ ../chibi-model/ (không sửa nguồn)
│   └── chibi.mtl
├── scenes/
│   ├── player.tscn            # CharacterBody3D + CollisionShape3D + MeshInstance3D
│   ├── workshop.tscn          # phòng bàn học low-poly (7 node bắt buộc)
│   └── main.tscn              # Main = Workshop + Player + CameraRig
├── scripts/
│   ├── player.gd              # move_direction() thuần + _physics_process
│   └── camera_follow.gd       # CameraRig follow XZ player
└── tests/
    ├── test_case.gd           # base: check / check_eq / check_near
    ├── run_tests.gd           # SceneTree runner, exit 0/1
    ├── test_chibi_import.gd
    ├── test_player_move.gd
    ├── test_player_scene.gd
    ├── test_workshop.gd
    └── test_main_scene.gd
```

**Phân định trách nhiệm:** `player.gd` chứa **toàn bộ** logic di chuyển dưới dạng hàm static → test được mà không cần scene. Scene file chỉ là cấu hình node. Test không bao giờ setFrame() hay chạy physics — chỉ load scene, đọc transform, assert.

---

### Task 1: Project skeleton + test harness + hợp đồng asset chibi

**Files:**
- Create: `repair-shop-game/project.godot`
- Create: `repair-shop-game/.gitignore`
- Create: `repair-shop-game/tests/test_case.gd`
- Create: `repair-shop-game/tests/run_tests.gd`
- Create: `repair-shop-game/tests/test_chibi_import.gd`
- Copy: `repair-shop-game/assets/models/chibi.obj`, `chibi.mtl` (từ `chibi-model/`)

**Interfaces:**
- Consumes: file OBJ/MTL nguồn tại `chibi-model/chibi.obj`, `chibi.mtl`.
- Produces:
  - `tests/test_case.gd` → class `check(cond: bool, msg: String)`, `check_eq(actual, expected, msg: String)`, `check_near(actual: float, expected: float, tol: float, msg: String)`, thuộc tính `failures: PackedStringArray`.
  - `tests/run_tests.gd` → `extends SceneTree`, huyệt `_init()`, in `PASS <tên>` / `FAIL <tên>` cho mỗi test, exit code `0` nếu tất cả qua, `1` nếu có bất kỳ failure.
  - Lệnh chạy test chuẩn (dùng lại ở mọi task sau):
    `godot --headless --path repair-shop-game --import >/dev/null 2>&1; godot --headless --path repair-shop-game -s res://tests/run_tests.gd`

- [ ] **Step 1: Viết `tests/test_case.gd`**

```gdscript
extends RefCounted

var failures: PackedStringArray = PackedStringArray()

func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)

func check_eq(actual, expected, msg: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [msg, expected, actual])

func check_near(actual: float, expected: float, tol: float, msg: String) -> void:
	if absf(actual - expected) > tol:
		failures.append("%s: expected %s ± %s, got %s" % [msg, expected, tol, actual])
```

- [ ] **Step 2: Viết `tests/test_chibi_import.gd` (test fail trước)**

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var mesh := load("res://assets/models/chibi.obj") as ArrayMesh
	check(mesh != null, "chibi.obj must load")
	if mesh == null:
		return
	check_eq(mesh.get_surface_count(), 103, "surface count")

	var colors := {}
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		if m is StandardMaterial3D:
			colors[m.resource_name] = (m as StandardMaterial3D).albedo_color

	check_eq(colors.size(), 23, "unique material count")
	check_near(colors["skin"].r, 0.965, 0.01, "skin.r")
	check_near(colors["skin"].g, 0.843, 0.01, "skin.g")
	check_near(colors["skin"].b, 0.737, 0.01, "skin.b")
	check_near(colors["hair"].r, 0.788, 0.01, "hair.r")
	check_near(colors["cap"].r, 0.102, 0.01, "cap.r")
	check_near(colors["red"].r, 0.878, 0.01, "red.r")

	var aabb := mesh.get_aabb()
	check_near(aabb.size.x, 1.12, 0.01, "aabb.x")
	check_near(aabb.size.y, 1.012, 0.01, "aabb.y")
	check_near(aabb.size.z, 2.012, 0.01, "aabb.z (Z-up height)")
	check_near(aabb.position.y, -0.512, 0.01, "aabb.position.y")
```

- [ ] **Step 3: Viết `tests/run_tests.gd`**

```gdscript
extends SceneTree

const TEST_SCRIPTS: PackedStringArray = [
	"res://tests/test_chibi_import.gd",
]

func _init() -> void:
	var total := 0
	for path in TEST_SCRIPTS:
		var script := load(path)
		if script == null:
			print("FAIL ", path, " (cannot load)")
			total += 1
			continue
		var case = script.new()
		case.run()
		if case.failures.is_empty():
			print("PASS ", path)
		else:
			for f in case.failures:
				print("FAIL ", path, ": ", f)
			total += case.failures.size()
	print("TOTAL_FAILURES=", total)
	quit(0 if total == 0 else 1)
```

- [ ] **Step 4: Tạo `project.godot` + `.gitignore` — CHƯA copy asset**

`repair-shop-game/project.godot`:

```
config_version=5

[application]

config/name="Xuong Sua May"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.7")

[rendering]

renderer/rendering_method="forward_plus"
```

`repair-shop-game/.gitignore`:

```
.godot/
```

(Lý do tách bước này khỏi copy asset: `godot --headless --path <dir>` trên thư mục chưa có `project.godot` chưa từng được kiểm chứng — cần project file để lần chạy FAIL ở Step 5 reproducible.)

- [ ] **Step 5: Chạy test — mong đợi FAIL** (asset chưa tồn tại)

```bash
godot --headless --path repair-shop-game --import >/dev/null 2>&1; godot --headless --path repair-shop-game -s res://tests/run_tests.gd
```

Expected: `FAIL res://tests/test_chibi_import.gd: chibi.obj must load`, `TOTAL_FAILURES=1`, exit `1`. Nếu **PASS** → có artefact thừa từ lần chạy trước, dọn thư mục rồi chạy lại từ đầu.

- [ ] **Step 6: Copy asset + import**

```bash
mkdir -p repair-shop-game/assets/models
cp chibi-model/chibi.obj chibi-model/chibi.mtl repair-shop-game/assets/models/
godot --headless --path repair-shop-game --import
```

Verify sau import (đã kiểm chứng thực tế với 4.7.2): `repair-shop-game/assets/models/chibi.obj.import` **có**, `chibi.mtl.import` **không có** (`.mtl` được OBJ importer đọc trực tiếp, không tạo file import).

- [ ] **Step 7: Chạy lại — mong đợi PASS**

```bash
godot --headless --path repair-shop-game --import >/dev/null 2>&1; godot --headless --path repair-shop-game -s res://tests/run_tests.gd
```

Expected: `PASS res://tests/test_chibi_import.gd`, `TOTAL_FAILURES=0`, exit `0`.

- [ ] **Step 8: Commit**

```bash
git add repair-shop-game/project.godot repair-shop-game/.gitignore \
  repair-shop-game/assets/models/chibi.obj repair-shop-game/assets/models/chibi.mtl \
  repair-shop-game/assets/models/chibi.obj.import \
  repair-shop-game/tests/test_case.gd repair-shop-game/tests/run_tests.gd \
  repair-shop-game/tests/test_chibi_import.gd \
  repair-shop-game/tests/test_case.gd.uid repair-shop-game/tests/run_tests.gd.uid \
  repair-shop-game/tests/test_chibi_import.gd.uid
git commit -m "feat: godot project skeleton with chibi asset contract test"
```

---

### Task 2: Player scene — chibi đứng thẳng, có va chạm

**Files:**
- Create: `repair-shop-game/scenes/player.tscn`

**Interfaces:**
- Consumes: mesh `res://assets/models/chibi.obj` (Task 1).
- Produces: scene `res://scenes/player.tscn`, root `Player` (`CharacterBody3D`) với đúng cấu trúc:
  - `Player` (CharacterBody3D) — **không** có script ở task này
  - `CollisionShape3D` — `CapsuleShape3D`, `radius = 0.35`, `height = 2.0`, `position = (0, 1.0, 0)`
  - `Body` (MeshInstance3D) — `mesh = res://assets/models/chibi.obj`, `rotation_degrees = Vector3(-90, 180, 0)`

- [ ] **Step 1: Viết `tests/test_player_scene.gd` (fail trước)**

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var packed := load("res://scenes/player.tscn") as PackedScene
	check(packed != null, "player.tscn must load")
	if packed == null:
		return
	var p = packed.instantiate()
	check(p is CharacterBody3D, "root is CharacterBody3D")
	check_eq(p.name, "Player", "root name")

	var shape_node := p.get_node_or_null("CollisionShape3D")
	check(shape_node != null, "has CollisionShape3D")
	if shape_node is CollisionShape3D:
		var cap := (shape_node as CollisionShape3D).shape as CapsuleShape3D
		check(cap != null, "collision shape is CapsuleShape3D")
		if cap != null:
			check_near(cap.radius, 0.35, 0.001, "capsule radius")
			check_near(cap.height, 2.0, 0.001, "capsule height")
		check_near(shape_node.position.y, 1.0, 0.001, "capsule y")

	var body := p.get_node_or_null("Body")
	check(body is MeshInstance3D, "has MeshInstance3D Body")
	if body is MeshInstance3D:
		var m := (body as MeshInstance3D).mesh as ArrayMesh
		check(m != null, "Body has mesh")
		if m != null:
			var corners := _transformed_corners(body as MeshInstance3D, m.get_aabb())
			var ext := _extent(corners)
			check_near(ext.y, 2.012, 0.02, "upright height along Y")
			check_near(ext.x, 1.12, 0.02, "width along X")
			check_near(_min_component(corners, 1), 0.0, 0.02, "feet on y=0")
	p.free()

func _transformed_corners(node: Node3D, aabb: AABB) -> Array:
	var out: Array = []
	for i in 8:
		var c := Vector3(
			aabb.position.x + (aabb.size.x if (i & 1) == 1 else 0.0),
			aabb.position.y + (aabb.size.y if (i & 2) == 2 else 0.0),
			aabb.position.z + (aabb.size.z if (i & 4) == 4 else 0.0))
		out.append(node.transform * c)
	return out

func _extent(corners: Array) -> Vector3:
	var mn := Vector3(INF, INF, INF)
	var mx := Vector3(-INF, -INF, -INF)
	for c in corners:
		mn = Vector3(minf(mn.x, c.x), minf(mn.y, c.y), minf(mn.z, c.z))
		mx = Vector3(maxf(mx.x, c.x), maxf(mx.y, c.y), maxf(mx.z, c.z))
	return mx - mn

func _min_component(corners: Array, axis: int) -> float:
	var v := INF
	for c in corners:
		v = minf(v, [c.x, c.y, c.z][axis])
	return v
```

Thêm `"res://tests/test_player_scene.gd"` vào mảng `TEST_SCRIPTS` trong `run_tests.gd`.

- [ ] **Step 2: Chạy test — mong đợi FAIL**

```bash
godot --headless --path repair-shop-game --import >/dev/null 2>&1; godot --headless --path repair-shop-game -s res://tests/run_tests.gd
```

Expected: `FAIL ... player.tscn must load` → exit `1`.

- [ ] **Step 3: Tạo `scenes/player.tscn`**

Node tree đúng như Interfaces. Ghi tay file `.tscn` là được (format text của Godot 4). Giá trị xoay đã tính trước nhưng **test mới là quyết định**: nếu `Vector3(-90, 180, 0)` không cho `size.y = 2.012`, xoay cho tới khi test pass (thứ tự xoay Godot mặc định là YXZ).

- [ ] **Step 4: Chạy test — mong đợi PASS**

```bash
godot --headless --path repair-shop-game --import >/dev/null 2>&1; godot --headless --path repair-shop-game -s res://tests/run_tests.gd
```

Expected: `TOTAL_FAILURES=0`, exit `0`.

- [ ] **Step 5: Commit**

```bash
git add repair-shop-game/scenes/player.tscn repair-shop-game/tests/test_player_scene.gd \
  repair-shop-game/tests/run_tests.gd
git commit -m "feat: player scene with upright chibi and capsule collision"
```

---

### Task 3: Logic di chuyển (thuần) + điều khiển

**Files:**
- Create: `repair-shop-game/scripts/player.gd`
- Modify: `repair-shop-game/scenes/player.tscn` (gắn script vào root)
- Modify: `repair-shop-game/project.godot` (thêm `[input]` map — Ruling R9)

**Interfaces:**
- Consumes: scene `player.tscn` (Task 2), node `Body`.
- Produces — `scripts/player.gd`:
  - `extends CharacterBody3D`
  - `const WALK_SPEED: float = 3.0`
  - `static func move_direction(input: Vector2, cam_basis: Basis) -> Vector3` — chuẩn hoá hướng đi trên mặt phẳng XZ theo basis camera; trả `Vector3.ZERO` khi `input == Vector2.ZERO`; luôn có `result.y == 0.0` và `result.length() ≈ 1.0` khi khác không.
  - `func _physics_process(delta: float) -> void` — đọc `Input.get_vector("move_left","move_right","move_forward","move_back")`, gọi `move_direction(...)` với `camera` basis (bằng `get_viewport().get_camera_3d().global_transform.basis` nếu có camera, ngược lại `Basis.IDENTITY`), nhân `WALK_SPEED`, cộng gravity, `move_and_slide()`.
  - Produces — `project.godot` phải có section `[input]` khai báo **đúng 4 action** `"move_left"`, `"move_right"`, `"move_forward"`, `"move_back"` (keys: A/Left, D/Right, W/Up, S/Down). Không có section này thì `Input.get_vector` runtime-error ở Task 5.

- [ ] **Step 1: Viết `tests/test_player_move.gd` (fail trước)**

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var id := Basis.IDENTITY

	var fwd := PlayerMove.move_direction(Vector2(0, 1), id)
	check_near(fwd.x, 0.0, 0.0001, "W.x")
	check_near(fwd.y, 0.0, 0.0001, "W.y")
	check_near(fwd.z, -1.0, 0.0001, "W faces -Z")

	var strafe := PlayerMove.move_direction(Vector2(1, 0), id)
	check_near(strafe.x, 1.0, 0.0001, "D.x")
	check_near(strafe.y, 0.0, 0.0001, "D.y")
	check_near(strafe.z, 0.0, 0.0001, "D.z")

	var back := PlayerMove.move_direction(Vector2(0, -1), id)
	check_near(back.z, 1.0, 0.0001, "S faces +Z")
	check_near(back.y, 0.0, 0.0001, "S.y")

	check_eq(PlayerMove.move_direction(Vector2.ZERO, id), Vector3.ZERO, "idle is ZERO")

	var diag := PlayerMove.move_direction(Vector2(1, 1), id)
	check_near(diag.x, 0.7071, 0.001, "diagonal normalized x")
	check_near(diag.y, 0.0, 0.0001, "diagonal has zero Y")
	check_near(diag.z, -0.7071, 0.001, "diagonal normalized z")

	# camera pitch 30 độ xuống: hướng đi vẫn phải nằm trên mặt phẳng XZ
	var pitched := Basis.IDENTITY.rotated(Vector3.RIGHT, deg_to_rad(30.0))
	var moved := PlayerMove.move_direction(Vector2(0, 1), pitched)
	check_near(moved.y, 0.0, 0.0001, "pitched basis keeps Y at 0")
	check_near(moved.length(), 1.0, 0.001, "pitched basis result is unit length")
	check(moved.x * moved.x + moved.z * moved.z > 0.9, "pitched basis still moves")

	var script := load("res://scripts/player.gd")
	check(script != null, "player.gd loads")
	if script != null:
		check_near(script.WALK_SPEED, 3.0, 0.001, "WALK_SPEED is 3.0")
```

> `PlayerMove` là `class_name` của `scripts/player.gd`. Đăng ký bằng `class_name PlayerMove` ở dòng đầu file. Thêm `"res://tests/test_player_move.gd"` vào `TEST_SCRIPTS`.

- [ ] **Step 2: Chạy test — mong đợi FAIL**

```bash
godot --headless --path repair-shop-game --import >/dev/null 2>&1; godot --headless --path repair-shop-game -s res://tests/run_tests.gd
```

Expected: `FAIL` với `Identifier "PlayerMove" not declared` → exit `1`.

- [ ] **Step 3: Implement `scripts/player.gd`**

```gdscript
class_name PlayerMove
extends CharacterBody3D

const WALK_SPEED: float = 3.0
const GRAVITY: float = 20.0

static func move_direction(input: Vector2, cam_basis: Basis) -> Vector3:
	if input == Vector2.ZERO:
		return Vector3.ZERO
	var world := cam_basis * Vector3(input.x, 0.0, -input.y)
	world.y = 0.0
	if world.length_squared() == 0.0:
		return Vector3.ZERO
	return world.normalized()

func _physics_process(delta: float) -> void:
	# body: đọc input, gọi move_direction với basis camera, nhân WALK_SPEED,
	# cộng gravity, move_and_slide(). Nếu không có camera → Basis.IDENTITY.
```

Body của `_physics_process` để trống phần cốt lõi — test **không** cover nó (cần frame physics). Viết body sao cho game chạy được: input → hướng → vận tốc ngang + gravity dọc → `move_and_slide()`.

Gắn script vào root của `scenes/player.tscn`.

- [ ] **Step 4: Chạy test — mong đợi PASS**

```bash
godot --headless --path repair-shop-game --import >/dev/null 2>&1; godot --headless --path repair-shop-game -s res://tests/run_tests.gd
```

Expected: `TOTAL_FAILURES=0`, exit `0`.

- [ ] **Step 5: Commit**

```bash
git add repair-shop-game/scripts/player.gd repair-shop-game/scenes/player.tscn \
  repair-shop-game/project.godot \
  repair-shop-game/tests/test_player_move.gd repair-shop-game/tests/run_tests.gd \
  repair-shop-game/scripts/player.gd.uid repair-shop-game/tests/test_player_move.gd.uid
git commit -m "feat: pure camera-relative movement logic with player controller"
```

---

### Task 4: Workshop — phòng bàn học low-poly

**Files:**
- Create: `repair-shop-game/scenes/workshop.tscn`

**Interfaces:**
- Consumes: chưa gì.
- Produces: scene `res://scenes/workshop.tscn`, root `Workshop` (`Node3D`) chứa **đúng 7 con trực tiếp**, tên chính xác:
  `Floor`, `WallN`, `WallS`, `WallE`, `WallW`, `Desk`, `Chair`
  - `Floor`, `WallN`, `WallS`, `WallE`, `WallW` — mỗi cái **có con `StaticBody3D`** bên trong (kèm `CollisionShape3D`).
  - `Floor` có `BoxShape3D` với `size.x ≈ 8.0` và `size.z ≈ 8.0`; mặt sàn (top) tại **`y = 0.0`**.
  - Tường cao **3.0**, phòng thông nhau (cửa ở `WallS` là lỗ hở, không phải rào).
  - `Desk`, `Chair` — chỉ khối trang trí, low-poly (không cần va chạm).

- [ ] **Step 1: Viết `tests/test_workshop.gd` (fail trước)**

```gdscript
extends "res://tests/test_case.gd"

const REQUIRED := ["Floor", "WallN", "WallS", "WallE", "WallW", "Desk", "Chair"]
const SOLIDS := ["Floor", "WallN", "WallS", "WallE", "WallW"]

func run() -> void:
	var packed := load("res://scenes/workshop.tscn") as PackedScene
	check(packed != null, "workshop.tscn must load")
	if packed == null:
		return
	var root := packed.instantiate()
	check_eq(root.name, "Workshop", "root name")
	check_eq(root.get_child_count(), 7, "exactly 7 direct children")

	for n in REQUIRED:
		check(root.has_node(NodePath(n)), "has child " + n)

	for n in SOLIDS:
		var node: Node = root.get_node_or_null(NodePath(n))
		var solid: Node = node.find_child("StaticBody3D", true, false) if node != null else null
		check(solid is StaticBody3D, n + " has StaticBody3D")
		if solid is StaticBody3D:
			var cs: Node = solid.find_child("CollisionShape3D", true, false)
			check(cs is CollisionShape3D, n + " has CollisionShape3D")

	var floor_node: Node = root.get_node_or_null(NodePath("Floor"))
	if floor_node != null:
		var solid: Node = floor_node.find_child("StaticBody3D", true, false)
		var cs: Node = solid.find_child("CollisionShape3D") if solid != null else null
		var box: BoxShape3D = cs.shape as BoxShape3D if cs != null else null
		if box != null:
			check_near(box.size.x, 8.0, 0.01, "floor width X")
			check_near(box.size.z, 8.0, 0.01, "floor depth Z")
			check_near(cs.global_position.y, -box.size.y / 2.0, 0.01, "floor top at y=0")
```

Thêm vào `TEST_SCRIPTS`.

- [ ] **Step 2: Chạy test — mong đợi FAIL**

```bash
godot --headless --path repair-shop-game --import >/dev/null 2>&1; godot --headless --path repair-shop-game -s res://tests/run_tests.gd
```

Expected: `FAIL ... workshop.tscn must load` → exit `1`.

- [ ] **Step 3: Tạo `scenes/workshop.tscn`**

Dựng 7 node con đúng tên. Chỉ **3 thông số test pin**: 7 con trực tiếp, `Floor` box `8 × ? × 8`, top sàn tại `y = 0`. Còn lại (cao tường 3.0, độ dày, vị trí bàn/chair, màu low-poly) tự chọn, nhưng tường phải bao quanh phòng 8×8 và có cửa mở ở `WallS`.

- [ ] **Step 4: Chạy test — mong đợi PASS**

```bash
godot --headless --path repair-shop-game --import >/dev/null 2>&1; godot --headless --path repair-shop-game -s res://tests/run_tests.gd
```

Expected: `TOTAL_FAILURES=0`, exit `0`.

- [ ] **Step 5: Commit**

```bash
git add repair-shop-game/scenes/workshop.tscn repair-shop-game/tests/test_workshop.gd \
  repair-shop-game/tests/run_tests.gd
git commit -m "feat: low-poly workshop room with collision bounds"
```

---

### Task 5: Main scene + camera follow + smoke run

**Files:**
- Create: `repair-shop-game/scenes/main.tscn`
- Create: `repair-shop-game/scripts/camera_follow.gd`
- Modify: `repair-shop-game/scenes/player.tscn` (thêm nhóm `player` vào root — Ruling R1)

**Interfaces:**
- Consumes: `workshop.tscn` (Task 4), `player.tscn` (Tasks 2–3), `WALK_SPEED`/`move_direction` (Task 3).
- Produces:
  - `res://scenes/main.tscn` — root `Main` (`Node3D`) với **đúng 3 con trực tiếp**: `Workshop` (instance workshop.tscn), `Player` (instance player.tscn, `position = (0, 0.1, 0)`), `CameraRig` (`Node3D` gắn `scripts/camera_follow.gd`).
  - `CameraRig` chứa `SpringArm3D` (`length = 5.0`, `rotation_degrees.x = -35.0`) và `Camera3D` là con của `SpringArm3D`.
  - `scripts/camera_follow.gd` → `extends Node3D`, `const FOLLOW_HEIGHT_OFFSET := 0.0`, huyệt `_process(delta: float)` lerp `global_position.x/z` về `target` (node `Player` tìm qua `get_tree().get_first_node_in_group("player")` hoặc path `"/root/Main/Player"`), không đổi Y.
  - `project.godot` `run/main_scene` đã trỏ `res://scenes/main.tscn` (Task 1 đã set).
  - Player gốc vào nhóm `"player"` (thêm `groups=["player"]` trong `.tscn`).

- [ ] **Step 1: Viết `tests/test_main_scene.gd` (fail trước)**

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	check(packed != null, "main.tscn must load")
	if packed == null:
		return
	var root := packed.instantiate()
	check_eq(root.get_child_count(), 3, "Main has 3 direct children")
	check(root.has_node("Workshop"), "has Workshop")
	check(root.has_node("Player"), "has Player")
	check(root.has_node("CameraRig"), "has CameraRig")

	var player := root.get_node_or_null("Player")
	if player != null:
		check_near(player.global_position.x, 0.0, 0.01, "player spawn X")
		check_near(player.global_position.z, 0.0, 0.01, "player spawn Z")
		check_near(player.global_position.y, 0.1, 0.01, "player spawn Y above floor")
		check(player.is_in_group("player"), "player in group 'player'")
		# spawn nằm trong phòng 8x8
		check(absf(player.global_position.x) < 4.0, "spawn inside room X")
		check(absf(player.global_position.z) < 4.0, "spawn inside room Z")

	var rig := root.get_node_or_null("CameraRig")
	if rig != null:
		var arm := rig.get_node_or_null("SpringArm3D")
		check(arm is SpringArm3D, "CameraRig has SpringArm3D")
		if arm is SpringArm3D:
			check_near((arm as SpringArm3D).length, 5.0, 0.001, "spring arm length")
			check(arm.get_node_or_null("Camera3D") is Camera3D, "SpringArm3D has Camera3D")
```

Thêm vào `TEST_SCRIPTS`.

- [ ] **Step 2: Chạy test — mong đợi FAIL**

```bash
godot --headless --path repair-shop-game --import >/dev/null 2>&1; godot --headless --path repair-shop-game -s res://tests/run_tests.gd
```

Expected: `FAIL ... main.tscn must load` → exit `1`.

- [ ] **Step 3: Tạo `scripts/camera_follow.gd` và `scenes/main.tscn`**

`camera_follow.gd`:

```gdscript
extends Node3D

@export var target_path: NodePath = NodePath("../Player")
@export var follow_speed: float = 8.0

func _process(delta: float) -> void:
	var target := get_node_or_null(target_path) as Node3D
	if target == null:
		return
	global_position.x = lerpf(global_position.x, target.global_position.x, follow_speed * delta)
	global_position.z = lerpf(global_position.z, target.global_position.z, follow_speed * delta)
```

Main scene: assemble 3 con đúng Interfaces; đặt `CameraRig` tại `(0, 0, 0)`.

- [ ] **Step 4: Chạy test — mong đợi PASS**

```bash
godot --headless --path repair-shop-game --import >/dev/null 2>&1; godot --headless --path repair-shop-game -s res://tests/run_tests.gd
```

Expected: `TOTAL_FAILURES=0`, exit `0`.

- [ ] **Step 5: Smoke run toàn project**

```bash
godot --headless --path repair-shop-game --quit-after 60 2>&1 | tail -20; echo "EXIT=${PIPESTATUS[0]}"
```

Expected: `EXIT=0`, không có dòng `SCRIPT ERROR` / `ERROR: Failed loading resource`. (Đã kiểm chứng thực tế với Godot 4.7.2: lệnh này exit 0 và chạy `_ready()`.)

- [ ] **Step 6: Commit**

```bash
git add repair-shop-game/scenes/main.tscn repair-shop-game/scripts/camera_follow.gd \
  repair-shop-game/scenes/player.tscn \
  repair-shop-game/tests/test_main_scene.gd repair-shop-game/tests/run_tests.gd \
  repair-shop-game/project.godot
git commit -m "feat: main scene with workshop, player spawn and follow camera"
```
