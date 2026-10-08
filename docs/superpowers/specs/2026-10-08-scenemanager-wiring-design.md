# Spec 2 — SceneManager wiring (chuyen map debug)

Date: 2026-10-08
Status: approved in chat (§A-C)
Parent scope: Visual + wiring + full lich tuan §4, split into 3 specs. Spec 1/3 done (7 map visual). This is Spec 2/3. Spec 3 = full lich tuan §4.

## 1. Intent

- Outcome: chuyen giua 7 map da co (workshop, schoolyard, gate, classroom, library, cafe, street) trong game chay that, bang phim so debug; GameState biet hien tai o dau.
- Non-goals Spec 3: lich tuan §4 chan/cho phep theo gio, menu UI chon dia diem, texture.
- Success: phim 1-7 doi map ngay, player spawn dung san (khong lot/khong bay), run_suite.sh GATE PASS.

## 2. Architecture (§A approved)

- Autoload moi: `repair-shop-game/scripts/autoload/scene_manager.gd`, ten `SceneManager` (them 1 dong `[autoload]` trong project.godot — chu y project.godot dang dirty vi Godot editor rewrite, commit ca 2 doi tuong va luu ruling).
- `game_state.gd`: them `var current_location: String = "workshop"`.
- Khong sua input map trong project.godot — handler doc `event.keycode` KEY_1..KEY_7 truc tiep ( tranh conflict voi session khac dang chay NPC plan).
- Khong sua main.tscn cau truc (test_main_scene: 3 children, Workshop instance giu nguyen), khong sua player.gd/camera_follow.gd.

## 3. Components (§B approved)

- `const LOCATIONS: Dictionary` — 7 key `"gate","schoolyard","classroom","library","cafe","street","workshop"` → `res://scenes/<key>.tscn`. Constants `SPAWN := Vector3(0, 0.1, 0)`.
- `static func change_map(parent: Node3D, player: Node3D, loc: String) -> void`:
  1. xoa child cua `parent` ten `capitalize(loc)` (cong thuc: voi "workshop" thi ten node la "Workshop", "schoolyard" → "Schoolyard"... dung `loc.capitalize()` — Godot String.capitalize() bo underscore va upper moi chu, "schoolyard" → "Schoolyard" — dung),
  2. `load(LOCATIONS[loc]).instantiate()`, dat ten, `parent.add_child(...)`,
  3. `GameState.current_location = loc`,
  4. `player.position = SPAWN`; player kieu `CharacterBody3D` (player.gd + test dummy deu la CharacterBody3D) → `velocity = Vector3.ZERO` khong dieu kien.
- `_unhandled_input(event)`: InputEventKey khong echo, keycode KEY_1..KEY_7 → index vao LOCATIONS theo thu tu fixed `["workshop","schoolyard","gate","classroom","library","cafe","street"]` → goi change_map(get_tree().current_scene, player, loc) (player lay tu group "player", giong camera_follow).
- Camera khong reset — camera_follow.gd tu catch-up.

## 4. Testing (§C approved)

`repair-shop-game/tests/test_scene_manager.gd` (headless, khong can frame):
- LOCATIONS du 7 key, moi path load() khac null.
- current_location mac dinh "workshop" — assert trong test_scene_manager nay (khong dua test_game_state).
- change_map thu vien: `var main := load("res://scenes/main.tscn").instantiate()` trong test → goi `SceneManager.change_map(main, player_dummy, "gate")` → assert: khong con node "Workshop", co node "Gate", GameState.current_location=="gate", player.position==SPAWN. Ghi chu: goi truc tiep script method (khuon mau get_script_method_list cua test_main_scene) vi autoload khong chay trong harness. Tuy nhien change_map static → load script .new()? GDScript static goi duoc qua resource: `load("...scene_manager.gd").change_map(...)`? Cach on nhat: static func — test goi `SceneMgr.change_map(...)` bang cach `var sm = load("res://scripts/autoload/scene_manager.gd")` roi `sm.change_map(...)` (GDScript static method goi duoc tu resource). Neu static khong goi duoc tu resource → test instance script (`.new()`) roi goi method.
- Player dummy: `CharacterBody3D.new()` + them vao main, dat group "player".
- Dau vao TEST_SCRIPTS truoc test_main_scene.
- Gate cu: run_suite.sh TOTAL_FAILURES=0, khong SCRIPT ERROR.

## 5. Risks

- String.capitalize() khop ten node? Neu loi → assert trong test fail ro ten.
- change_map khi current_scene null (harness) → handler chi chay trong game that; test dung static thu vien.
- project.godot conflict voi Godot editor/ session khac → edit 1 dong, doc lai diff truoc commit.

## 6. Next

Spec 3: full lich tuan §4 (T2-CN, ngay le, ca sua, tu do) + cho phep/chan map theo khung gio, de len tren Spec 2.
