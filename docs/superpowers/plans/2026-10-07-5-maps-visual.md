# 5 Maps Visual Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tao 5 scenes visual BoxMesh mo rieng duoc trong Godot, moi map co test va suite xanh.

**Architecture:** Moi map 1 scene + 1 test theo mau `schoolyard.tscn` / `test_schoolyard.gd`. Khong sua `main.tscn`, `game_state.gd`, khong them Autoload. Thuc hien tuan tu Gate -> Classroom -> Library -> Cafe -> Street de tranh conflict khi them tung dong vao `TEST_SCRIPTS`.

**Tech Stack:** Godot 4.7.2, GDScript, BoxMesh + StandardMaterial3D + BoxShape3D, harness `tests/test_case.gd` + `tests/run_tests.gd` + `tests/run_suite.sh`.

**Spec:** `docs/superpowers/specs/2026-10-07-5-maps-visual-design.md`

## Global Constraints

- BoxMesh + StandardMaterial3D thuan, khong file .obj ngoai, khong texture anh reference.
- 1 floor solid duy nhat moi map, CollisionShape top y=0 (shape vi tri y=-0.005 voi day 0.01).
- Root names: Gate, Classroom, Library, Cafe, Street.
- Khong sua `repair-shop-game/scenes/main.tscn`, `repair-shop-game/scripts/autoload/game_state.gd`.
- Gate: `bash repair-shop-game/tests/run_suite.sh` → `TOTAL_FAILURES=0` + `GATE PASS`, khong `SCRIPT ERROR`.

## Review Focus

- Player spawn tuong lai lot san neu floor khong phang: test `top y=0` pin, mong doi san phang ±0.01.
- Ten node lech giua scene va test (vd GateLintel vs GateTop): test fail ten node, mong doi fail neu ro ten.
- Shape khong phai BoxShape3D (doi sang Convex): test kieu shape fail, mong doi bao loi ro.
- Scene mo trong editor duoc nhung headless load null do duong dan sai: test `packed != null` fail, mong doi bao `must load`.
- Them 5 entries vao TEST_SCRIPTS trung lap hoac sai duong dan: suite bao `cannot load`, mong doi fail ro ten file.

---

### Task 1: Gate (Cong truong)

**Files:**
- Create: `repair-shop-game/scenes/gate.tscn`
- Create: `repair-shop-game/tests/test_gate.gd`
- Modify: `repair-shop-game/tests/run_tests.gd` (them 1 dong `"res://tests/test_gate.gd"` sau dong schoolyard)

**Interfaces:**
- Consumes: mau `scenes/schoolyard.tscn` (Yard StaticBody top y=0), mau `tests/test_schoolyard.gd` (REQUIRED/SOLIDS + _world_origin).
- Produces: scene root `Gate`, REQUIRED = ["Yard","GateL","GateR","GateLintel","FenceL","FenceR"], floor BoxShape3D size Vector3(16, 0.01, 12).

- [ ] **Step 1: Write the failing test `tests/test_gate.gd`**

```gdscript
extends "res://tests/test_case.gd"
const REQUIRED := ["Yard", "GateL", "GateR", "GateLintel", "FenceL", "FenceR"]
const SOLIDS := ["Yard"]
func run() -> void:
	var packed := load("res://scenes/gate.tscn") as PackedScene
	check(packed != null, "gate.tscn must load")
	if packed == null:
		return
	var root := packed.instantiate()
	check_eq(root.name, "Gate", "root name")
	for n in REQUIRED:
		check(root.has_node(NodePath(n)), "has child " + n)
	# + floor shape (16x12) + top y=0 checks giong test_schoolyard.gd
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path repair-shop-game -s res://tests/run_tests.gd 2>&1 | grep -E "gate|TOTAL"`
Expected: FAIL `gate.tscn must load` (hoac `cannot load` neu chua dau vao suite — chap nhan, mien la fail do thieu scene).

- [ ] **Step 3: Implement `scenes/gate.tscn` (root `Gate`)**

San 16x12 (shape Vector3(16,0.01,12) tai y=-0.005, mesh Vector3(16,0.4,12) tai y=-0.2). GateL (-1.5,0,5) / GateR (1.5,0,5) tru BoxMesh (0.6,3,0.6) tam y=1.5. GateLintel (0,3.2,5) BoxMesh (3.6,0.5,0.6). FenceL (-5,0,5) / FenceR (5,0,5) BoxMesh (4,1.2,0.2) tam y=0.6.

- [ ] **Step 4: Dau test vao `tests/run_tests.gd` va verify pass**

Run: `godot --headless --path repair-shop-game --import >/dev/null 2>&1; bash repair-shop-game/tests/run_suite.sh 2>&1 | grep -E "test_gate|TOTAL|GATE"`
Expected: `PASS res://tests/test_gate.gd`, `TOTAL_FAILURES=0`, `GATE PASS`.

- [ ] **Step 5: Commit**

```bash
git add repair-shop-game/scenes/gate.tscn repair-shop-game/tests/test_gate.gd repair-shop-game/tests/run_tests.gd
git commit -m "feat: add gate map with test"
```

### Task 2: Classroom (Lop / hanh lang)

**Files:**
- Create: `repair-shop-game/scenes/classroom.tscn`
- Create: `repair-shop-game/tests/test_classroom.gd`
- Modify: `repair-shop-game/tests/run_tests.gd` (them `"res://tests/test_classroom.gd"`)

**Interfaces:**
- Consumes: Task 1 (pattern scene+test+suite entry).
- Produces: scene root `Classroom`, REQUIRED = ["Floor","Board","Podium","Desk1","Desk2","Desk3","Desk4"], floor BoxShape3D Vector3(12, 0.01, 10).

- [ ] **Step 1: Write the failing test `tests/test_classroom.gd`**

```gdscript
extends "res://tests/test_case.gd"
const REQUIRED := ["Floor", "Board", "Podium", "Desk1", "Desk2", "Desk3", "Desk4"]
func run() -> void:
	var packed := load("res://scenes/classroom.tscn") as PackedScene
	check(packed != null, "classroom.tscn must load")
	if packed == null:
		return
	var root := packed.instantiate()
	check_eq(root.name, "Classroom", "root name")
	for n in REQUIRED:
		check(root.has_node(NodePath(n)), "has child " + n)
	# + floor shape (12x10) + top y=0 checks giong test_schoolyard.gd
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path repair-shop-game -s res://tests/run_tests.gd 2>&1 | grep -E "classroom|TOTAL"`
Expected: FAIL do thieu `classroom.tscn`.

- [ ] **Step 3: Implement `scenes/classroom.tscn` (root `Classroom`)**

San 12x10 top y=0. Board (0,1.6,-4.5) BoxMesh (4,1.2,0.1). Podium (0,0.25,-3.5) BoxMesh (1.6,0.5,0.8). Desk1/2 (-1.5/1.5,0.375,-1) Desk3/4 (-1.5/1.5,0.375,1) BoxMesh (1.2,0.75,0.6) tam y=0.375.

- [ ] **Step 4: Dau test vao suite va verify pass**

Run: `bash repair-shop-game/tests/run_suite.sh 2>&1 | grep -E "test_classroom|TOTAL|GATE"`
Expected: PASS + TOTAL_FAILURES=0 + GATE PASS.

- [ ] **Step 5: Commit**

```bash
git add repair-shop-game/scenes/classroom.tscn repair-shop-game/tests/test_classroom.gd repair-shop-game/tests/run_tests.gd
git commit -m "feat: add classroom map with test"
```

### Task 3: Library (Thu vien)

**Files:**
- Create: `repair-shop-game/scenes/library.tscn`
- Create: `repair-shop-game/tests/test_library.gd`
- Modify: `repair-shop-game/tests/run_tests.gd`

**Interfaces:**
- Consumes: Task 2.
- Produces: scene root `Library`, REQUIRED = ["Floor","Shelf1","Shelf2","Shelf3","Table1","Table2"], floor Vector3(12, 0.01, 10).

- [ ] **Step 1: Write the failing test `tests/test_library.gd`** (same shape, root `Library`, REQUIRED tren, check floor shape 12x10 + top y=0 nhu test_schoolyard).

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path repair-shop-game -s res://tests/run_tests.gd 2>&1 | grep -E "library|TOTAL"`
Expected: FAIL thieu scene.

- [ ] **Step 3: Implement `scenes/library.tscn` (root `Library`)**

San 12x10 top y=0. Shelf1/2/3 (x=-3/0/3, z=-3.5) BoxMesh (2,2,0.6) tam y=1. Table1/2 (-2/2,0,1.5) BoxMesh (2,0.08,1) tam y=0.74.

- [ ] **Step 4: Verify pass**

Run: `bash repair-shop-game/tests/run_suite.sh 2>&1 | grep -E "test_library|TOTAL|GATE"`
Expected: PASS + TOTAL_FAILURES=0 + GATE PASS.

- [ ] **Step 5: Commit**

```bash
git add repair-shop-game/scenes/library.tscn repair-shop-game/tests/test_library.gd repair-shop-game/tests/run_tests.gd
git commit -m "feat: add library map with test"
```

### Task 4: Cafe (Quan ca phe)

**Files:**
- Create: `repair-shop-game/scenes/cafe.tscn`
- Create: `repair-shop-game/tests/test_cafe.gd`
- Modify: `repair-shop-game/tests/run_tests.gd`

**Interfaces:**
- Consumes: Task 3.
- Produces: scene root `Cafe`, REQUIRED = ["Floor","Counter","Table1","Table2","Table3"], floor Vector3(10, 0.01, 10).

- [ ] **Step 1: Write the failing test `tests/test_cafe.gd`** (root `Cafe`, REQUIRED tren, floor 10x10 top y=0).

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path repair-shop-game -s res://tests/run_tests.gd 2>&1 | grep -E "cafe|TOTAL"`
Expected: FAIL thieu scene.

- [ ] **Step 3: Implement `scenes/cafe.tscn` (root `Cafe`)**

San 10x10 top y=0. Counter (0,0.5,-3.5) BoxMesh (3,1,1). Table1/2/3 ((-2.5,0,0),(0.5,0,0.5),(2.5,0,-0.5)) BoxMesh (1,0.08,1) tam y=0.74.

- [ ] **Step 4: Verify pass**

Run: `bash repair-shop-game/tests/run_suite.sh 2>&1 | grep -E "test_cafe|TOTAL|GATE"`
Expected: PASS + TOTAL_FAILURES=0 + GATE PASS.

- [ ] **Step 5: Commit**

```bash
git add repair-shop-game/scenes/cafe.tscn repair-shop-game/tests/test_cafe.gd repair-shop-game/tests/run_tests.gd
git commit -m "feat: add cafe map with test"
```

### Task 5: Street (Duong pho) + final gate

**Files:**
- Create: `repair-shop-game/scenes/street.tscn`
- Create: `repair-shop-game/tests/test_street.gd`
- Modify: `repair-shop-game/tests/run_tests.gd`

**Interfaces:**
- Consumes: Task 4.
- Produces: scene root `Street`, REQUIRED = ["Road","WalkL","WalkR","House1","House2","Lamp1","Lamp2"], road BoxShape3D Vector3(20, 0.01, 6) top y=0. Suite xanh toan bo.

- [ ] **Step 1: Write the failing test `tests/test_street.gd`** (root `Street`, REQUIRED tren, Road shape 20x6 top y=0).

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path repair-shop-game -s res://tests/run_tests.gd 2>&1 | grep -E "street|TOTAL"`
Expected: FAIL thieu scene.

- [ ] **Step 3: Implement `scenes/street.tscn` (root `Street`)**

Road (0,0,0) shape (20,0.01,6) top y=0. WalkL (0,0.05,-4) / WalkR (0,0.05,4) BoxMesh (20,0.1,2). House1 (-5,1.5,-7) / House2 (5,1.5,7) BoxMesh (4,3,4). Lamp1 (-6,1.5,3) / Lamp2 (6,1.5,-3) BoxMesh (0.15,3,0.15) tam y=1.5.

- [ ] **Step 4: Verify full suite passes**

Run: `bash repair-shop-game/tests/run_suite.sh 2>&1 | grep -E "test_gate|test_classroom|test_library|test_cafe|test_street|TOTAL|GATE"`
Expected: 5 PASS + `TOTAL_FAILURES=0` + `GATE PASS`, khong SCRIPT ERROR.

- [ ] **Step 5: Commit**

```bash
git add repair-shop-game/scenes/street.tscn repair-shop-game/tests/test_street.gd repair-shop-game/tests/run_tests.gd
git commit -m "feat: add street map with test"
```
