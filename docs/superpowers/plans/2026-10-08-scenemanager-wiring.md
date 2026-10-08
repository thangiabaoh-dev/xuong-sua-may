# SceneManager Wiring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chuyen giua 7 map trong game chay that duoc bang phim so debug, GameState theo doi current_location.

**Architecture:** Autoload SceneManager + static change_map (DI GameState de test headless duoc) + handler phim KEY_1..7; khong sua main.tscn/cau truc, khong sua input map.

**Tech Stack:** Godot 4.7.2, GDScript, harness test_case.gd/run_tests.gd/run_suite.sh.

**Spec:** `docs/superpowers/specs/2026-10-08-scenemanager-wiring-design.md`

## Global Constraints

- Khong sua `main.tscn` cau truc (3 children, Workshop instance) — test_main_scene phai van xanh.
- Khong sua input map section trong project.godot (tranh conflict session khac); handler doc event.keycode truc tiep.
- 7 location keys chinh xac: workshop, schoolyard, gate, classroom, library, cafe, street → `res://scenes/<key>.tscn`.
- SPAWN = Vector3(0, 0.1, 0); player kieu CharacterBody3D, reset velocity khong dieu kien.
- Gate chung: `bash repair-shop-game/tests/run_suite.sh` → TOTAL_FAILURES=0, khong SCRIPT ERROR.

## Review Focus

- `String.capitalize()` khong khop ten node chua? (vd "schoolyard" → "Schoolyard") — test assert node cu bien mat + node moi xuat hien sau swap, ten dung.
- Harness khong co autoload GameState (Engine.get_main_loop() null trong _init) — change_map nhan gs qua tham so (DI); test truyen instance `load(game_state.gd).new()`, khong reference global GameState trong test.
- Handler global `GameState` chi chay trong game that — test chi pin location_for_key (pure) + source-contains check (khuon mau test_main_scene._camera_script_reads_player_group).
- Phim nhan duplicate/echo lam doi map — handler bo qua `event.echo` + location_for_key tra "" cho keycode sai; test location_for_key_tra_duoc.
- project.godot dang dirty (Godot editor rewrite mat [rendering]) — Task 3 doc diff truoc/sau khi them autoload, commit ca 2 doi tuong, ruling ghi ro; boot smoke check chay duoc main scene.

---

### Task 1: Data + change_map thu vien (LOCATIONS, SPAWN, location_for_key, change_map)

**Files:**
- Modify: `repair-shop-game/scripts/autoload/game_state.gd` (them 1 field)
- Create: `repair-shop-game/scripts/autoload/scene_manager.gd`
- Test: `repair-shop-game/tests/test_scene_manager.gd` (tao moi, chua dang ky suite o task nay)
- Reference: `repair-shop-game/tests/test_main_scene.gd` (khuon mau instantiate main + get_script_method_list + _world_origin), `repair-shop-game/tests/test_schoolyard.gd` (khuon mau scene assert)

**Interfaces:**
- Consumes: `res://scenes/{workshop,schoolyard,gate,classroom,library,cafe,street}.tscn` (Spec 1 — da co, test noi tro chung), `game_state.gd` autoload script.
- Note spec §3: `change_map` nhan them tham so `gs: Node` (spec ghi 3 tham so) — refinement vi harness khong chay autoload (`Engine.get_main_loop() == null` trong `_init`, theo comment test_main_scene) va spec §4 yeu cau test assert `current_location`; test truyen instance tu tao.
- Produces (Task 2/3 dua vao):
  - `GameState.current_location: String` mac dinh `"workshop"`.
  - `SceneM.LOCATIONS: Dictionary` (7 key → res path), `SceneM.SPAWN: Vector3 = Vector3(0, 0.1, 0)`, `SceneM.KEY_ORDER: Array` (thu tu digit 1..7).
  - `static func location_for_key(keycode: int) -> String` — tra key phu hop, `""` neu khong.
  - `static func change_map(parent: Node3D, player: CharacterBody3D, loc: String, gs: Node) -> void` — xoa node cu, instance map moi, `gs.set("current_location", loc)`, reset player.

- [ ] **Step 1: Write the failing test `tests/test_scene_manager.gd`**

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	# data: 7 path load duoc
	var sm = load("res://scripts/autoload/scene_manager.gd")
	check(sm != null, "scene_manager.gd must load")
	if sm == null:
		return
	var locs: Dictionary = sm.LOCATIONS
	check_eq(locs.size(), 7, "7 locations")
	for k in locs:
		check(load(locs[k]) != null, "path loads: " + str(locs[k]))
	# default location
	var gs = load("res://scripts/autoload/game_state.gd").new()
	check_eq(gs.current_location, "workshop", "current_location default")
	# location_for_key
	check_eq(sm.location_for_key(49), "workshop", "KEY_1=49 -> workshop")  # KEY_1 = 49
	check_eq(sm.location_for_key(55), "street", "KEY_7=55 -> street")
	check_eq(sm.location_for_key(65), "", "KEY_A -> empty")
	# change_map: main instance, swap Workshop -> Gate
	var main = load("res://scenes/main.tscn").instantiate()
	var player = CharacterBody3D.new()
	player.name = "Player"
	player.add_to_group("player")
	main.add_child(player)
	check(main.has_node("Workshop"), "start has Workshop")
	sm.change_map(main, player, "gate", gs)
	check(not main.has_node("Workshop"), "old Workshop removed")
	check(main.has_node("Gate"), "Gate added")
	check_eq(gs.current_location, "gate", "location updated")
	check_near(player.position.x, 0.0, 0.001, "spawn X")
	check_near(player.position.y, 0.1, 0.001, "spawn Y")
	check_near(player.position.z, 0.0, 0.001, "spawn Z")
	check_eq(player.velocity, Vector3.ZERO, "velocity reset")
	main.free()
```

(KEY_1=49, KEY_7=55 theo keycodes Godot; thu tu KEY_ORDER = workshop, schoolyard, gate, classroom, library, cafe, street — xem spec §3.)

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path repair-shop-game --import >/dev/null 2>&1; python3 -c "..."` — dung tam runner 1-file nhu lan truoc (tao `tests/_tmp_t1.gd` goi run(), xoa sau) hoac chay `godot --headless --path repair-shop-game -s res://tests/run_tests.gd` sau khi dang ky tam.
Expected: FAIL `scene_manager.gd must load` (file chua co).

- [ ] **Step 3: Implement**

`game_state.gd`: them `var current_location: String = "workshop"`.
`scene_manager.gd`: `extends Node` (Autoload — nhung toan bo logic static, khong can instance); `const LOCATIONS/SPAWN/KEY_ORDER`; `location_for_key(keycode)`: tim vi tri trong key order theo keycode KEY_1+i (49+i), tra `""` neu ngoai; `change_map(parent, player, loc, gs)`: tim node cu `parent.get_node_or_null(NodePath(loc.capitalize()))`; neu co → `parent.remove_child(old); old.free()` (**khong queue_free**: node van ton tai den cuoi frame → test assert ngay sau do se thay node cu con song). Sau do `var scene := load(LOCATIONS[loc]).instantiate(); scene.name = loc.capitalize(); parent.add_child(scene); gs.set("current_location", loc); player.position = SPAWN; player.velocity = Vector3.ZERO`.

- [ ] **Step 4: Run test to verify it passes**

Run: runner tam `tests/_tmp_t1.gd` (hoac dang ky suite tam) → Expected: `FAILURES=0`.

- [ ] **Step 5: Commit**

```bash
git add repair-shop-game/scripts/autoload/game_state.gd repair-shop-game/scripts/autoload/scene_manager.gd repair-shop-game/tests/test_scene_manager.gd
git commit -m "feat: scene_manager change_map + location data"
```

### Task 2: Dang ky test vao suite + handler phim so

**Files:**
- Modify: `repair-shop-game/scripts/autoload/scene_manager.gd` (them `_unhandled_input`)
- Modify: `repair-shop-game/tests/run_tests.gd` (them `"res://tests/test_scene_manager.gd"` TRUOC test_main_scene)
- Test: `repair-shop-game/tests/test_scene_manager.gd` (them 2 check)

**Interfaces:**
- Consumes: Task 1 (location_for_key, change_map).
- Produces: `func _unhandled_input(event: InputEvent) -> void` — InputEventKey, not echo, `location_for_key(keycode) != ""` → `change_map(get_tree().current_scene, player_tu_group, loc, GameState)`; player lay tu `get_tree().get_first_node_in_group("player")` (giong camera_follow), null thi bo qua.

- [ ] **Step 1: Write the failing checks (them vao run() test hien tai)**

```gdscript
	# handler source pin (khuon mau _camera_script_reads_player_group)
	var f = FileAccess.open("res://scripts/autoload/scene_manager.gd", FileAccess.READ)
	check(f != null and f.get_as_text().contains("_unhandled_input"), "handler defined")
	check(f != null and f.get_as_text().contains("get_first_node_in_group(\"player\")"), "resolves player group")
```

- [ ] **Step 2: Run to verify they fail**

Run: runner tam (Step 2 Task 1) → Expected: FAIL `"handler defined"` (chua co `_unhandled_input`).

- [ ] **Step 3: Implement `_unhandled_input`** — xem Interfaces; trong ham dung `GameState` global (compile OK vi project.godot da co autoload GameState; khong chay trong harness).

- [ ] **Step 4: Run test + dang ky suite + full suite**

```bash
# them vao TEST_SCRIPTS truoc "res://tests/test_main_scene.gd"
bash repair-shop-game/tests/run_suite.sh 2>&1 | grep -E "test_scene_manager|test_main_scene|TOTAL|GATE"
```
Expected: ca 2 PASS, TOTAL_FAILURES=0, GATE PASS.

- [ ] **Step 5: Commit**

```bash
git add repair-shop-game/scripts/autoload/scene_manager.gd repair-shop-game/tests/test_scene_manager.gd repair-shop-game/tests/run_tests.gd
git commit -m "feat: debug number-key map switching"
```

### Task 3: Autoload SceneManager + project.godot + boot smoke

**Files:**
- Modify: `repair-shop-game/project.godot` (them 1 dong autoload; commit ca dirty rewrite hien tai)
- Test: full suite + boot smoke

**Interfaces:**
- Consumes: Task 2 (scene_manager.gd san sang lam autoload).
- Produces: autoload `SceneManager="*res://scripts/autoload/scene_manager.gd"`; game chay duoc main scene khong SCRIPT ERROR.

- [ ] **Step 1: Write the failing check**

```bash
python3 -c "import io; t=open('repair-shop-game/project.godot').read(); assert 'SceneManager' in t, 'autoload missing'"
```
Expected: FAIL AssertionError.

- [ ] **Step 2: Implement — them vao cuoi section [autoload] (dang co GameState):**

```
SceneManager="*res://scripts/autoload/scene_manager.gd"
```

Doc lai `git diff repair-shop-game/project.godot` — chi co: editor rewrite truoc do (comment header, section thu tu, [rendering] mat) + 1 dong SceneManager moi. Neu co gi khac → dung, bao user.

- [ ] **Step 3: Verify — full suite + boot smoke**

```bash
bash repair-shop-game/tests/run_suite.sh 2>&1 | grep -E "TOTAL|GATE"
timeout 8 godot --headless --path repair-shop-game res://scenes/main.tscn 2>&1 | grep -E "SCRIPT ERROR" || echo "no script errors"
```
Expected: TOTAL_FAILURES=0, GATE PASS; smoke: `no script errors`.

- [ ] **Step 4: Commit**

```bash
git add repair-shop-game/project.godot
git commit -m "feat: register SceneManager autoload"
```

Ruling ghi ledger: commit ca dirty editor-rewrite cua project.godot (forward_plus = default Godot 4 nen [rendering] mat khong doi hanh vi) — cost if wrong: renderer doi, bat gap trong boot smoke.
