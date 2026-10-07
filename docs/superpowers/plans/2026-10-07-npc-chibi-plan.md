# 3 NPC Chibi Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tạo 3 NPC chibi (ban_hoc, giao_vien, hoai_niem) procedural OBJ+MTL tĩnh drop-in được vào repair-shop-game.

**Architecture:** Copy pattern generate_chibi.py (super_shape/box/obj_normals/write_obj) vào generate_npcs.py với 1 base body + 3 variant materials/accessories, render preview bằng render_preview.load2, verify bằng verify_npcs.py.

**Tech Stack:** Python3 stdlib only, OBJ+MTL, Godot 4.7 Forward+ (import ArrayMesh), orthographic software renderer hiện có.

**Spec:** docs/superpowers/specs/2026-10-07-npc-chibi-design.md

## Global Constraints

- Z-up, mặt về -Y (mắt/mũi ở Y âm), giữ nguyên hệ trục file xuất.
- Cao tổng Z trong [1.85, 2.05], XY trong [-0.8, 0.8].
- OBJ+MTL tĩnh, materials flat Kd + Ka*0.25, Ks 0.1 Ns 24 illum 2, không texture, không rig/GLB/blend.
- Mỗi variant <10000 verts và <10000 faces.
- Godot dùng MeshInstance rotation_degrees (-90,180,0) như repair-shop-game/scenes/player.tscn, không sửa chibi.obj/mtl cũ và không sửa player.tscn/workshop.tscn.
- Output sống ở chibi-model/ rồi copy sang repair-shop-game/assets/models/ để Godot gen .import.

## Review Focus

- Balô/kính/cặp/laptop bị lật mặt (back-face culled thành lỗ thủng khi render front/back) — mong đợi đặc kín mọi góc nhìn.
- MTL thiếu tên hoặc mtllib sai tên file khiến Godot render xám — mong đợi màu đúng sample.
- Variant cao quá/thấp quá so với Capsule r=0.35 h=2.0 khiến chân chìm sàn hoặc lơ lửng — mong đợi chân chạm Z=0.
- Mắt/miệng đặt nhầm Y dương khiến mặt quay lưng về camera front — mong đợi mặt -Y.
- Cache .godot/imported cũ khiến model mới không lên — mong đợi reimport sạch không lỗi.

---

### Task 1: generate_npcs.py base + ban_hoc variant end-to-end

**Files:**
- Create: `chibi-model/generate_npcs.py`
- Test: `chibi-model/verify_npcs.py` (tạm stub test ban_hoc trong task này, mở rộng ở Task 4)
- Reference: `chibi-model/generate_chibi.py:1-120` (helpers), `chibi-model/generate_chibi.py:MATERIALS`, `chibi-model/generate_chibi.py:write_obj/write_mtl/stats`

**Interfaces:**
- Consumes: `super_shape(c,A,B,C,m1,m2,nu,nv)`, `box(c,hx,hy,hz)`, `tcyl/cone/shell_cap` copy từ generate_chibi.py, `obj_normals(verts,faces,smooth)`, `write_obj(path,mtl_name)`, `write_mtl(path)`.
- Produces: `build_variant(name: str) -> tuple[list[dict], dict]` với name in {"ban_hoc"}, `MATERIALS_NPCS: dict[str,tuple[float,float,float]]`, `OBJECTS` list dict {name,mat,verts,faces,smooth}.

- [ ] **Step 1: Write the failing test cho ban_hoc bounds + màu áo**

```python
def test_ban_hoc_bounds_and_colors():
    objs, mats = build_variant("ban_hoc")
    assert 1.85 <= max(v[2] for o in objs for v in o["verts"]) <= 2.05
    assert mats["shirt_white"] == (0.957, 0.961, 0.969)
    assert mats["pants_blue"] == (0.227, 0.373, 0.659)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m py_compile chibi-model/verify_npcs.py` hoặc `python3 chibi-model/verify_npcs.py --variant ban_hoc`
Expected: FAIL với "build_variant not defined / No such file generate_npcs.py"

- [ ] **Step 3: Implement `build_variant(name: str)` + `MATERIALS_NPCS` trong `chibi-model/generate_npcs.py`**

Copy helpers nguyên văn từ generate_chibi.py, thêm base head/body (reuse HEAD_POS 1.50, HEAD_A/B/C 0.46/0.43/0.44, M 0.6) + ban_hoc parts: shirt_white box/super_shape, pants_blue, hair_black (0.102,0.114,0.149), backpack_green (0.255,0.588,0.353) box smooth=False sau lưng + 2 quai trước ngực.

- [ ] **Step 4: Run generation + test to verify it passes**

Run: `python3 chibi-model/generate_npcs.py --variant ban_hoc`
Expected: in `objects=~25 vertices<10000 faces<10000`, ghi `chibi-model/ban_hoc.obj` + `chibi-model/ban_hoc.mtl`, test Step 1 PASS.

- [ ] **Step 5: Commit**

```bash
git add chibi-model/generate_npcs.py chibi-model/ban_hoc.obj chibi-model/ban_hoc.mtl chibi-model/verify_npcs.py
git commit -m "feat: generate ban_hoc chibi procedural OBJ"
```

### Task 2: Thêm giao_vien + hoai_niem variants

**Files:**
- Modify: `chibi-model/generate_npcs.py`
- Test: `chibi-model/verify_npcs.py`

**Interfaces:**
- Consumes: `build_variant("ban_hoc")` từ Task 1, `MATERIALS_NPCS`.
- Produces: `build_variant(name: str)` mở rộng cho "giao_vien", "hoai_niem".

- [ ] **Step 1: Write the failing tests cho 2 variant còn lại**

```python
def test_giao_vien_glasses_and_case():
    objs, mats = build_variant("giao_vien")
    assert mats["glasses_black"] == (0.055, 0.055, 0.062)
    assert any(o["name"] == "glasses" for o in objs)
    assert any(o["name"] == "briefcase" for o in objs)

def test_hoai_niem_laptop():
    objs, mats = build_variant("hoai_niem")
    assert any(o["name"] == "old_laptop" for o in objs)
    assert mats["jacket_brown"] == (0.588, 0.431, 0.314)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python3 chibi-model/verify_npcs.py --variant giao_vien,hoai_niem`
Expected: FAIL với "unknown variant"

- [ ] **Step 3: Implement `build_variant("giao_vien")` và `build_variant("hoai_niem")` trong `chibi-model/generate_npcs.py`**

giao_vien: shirt_cream (0.922,0.882,0.784), pants_brown (0.431,0.333,0.235), hair_neat (0.118,0.118,0.137), glasses box 0.02 dày smooth=False trước mắt Y âm, briefcase (0.353,0.255,0.157) hông phải. hoai_niem: jacket_brown (0.588,0.431,0.314), pants_gray (0.51,0.51,0.529), hair_long (0.314,0.235,0.176) đuôi sau, old_laptop (0.549,0.549,0.569) box dày trước ngực.

- [ ] **Step 4: Run generation + tests to verify they pass**

Run: `python3 chibi-model/generate_npcs.py --all && python3 chibi-model/verify_npcs.py`
Expected: 6 files ghi xong, cả 3 tests PASS, verts/faces <10000 mỗi variant.

- [ ] **Step 5: Commit**

```bash
git add chibi-model/generate_npcs.py chibi-model/giao_vien.obj chibi-model/giao_vien.mtl chibi-model/hoai_niem.obj chibi-model/hoai_niem.mtl chibi-model/verify_npcs.py
git commit -m "feat: add giao_vien + hoai_niem variants"
```

### Task 3: Preview PNG + copy vào assets/models

**Files:**
- Create: `chibi-model/render_preview_npcs.py` (wrapper reuse `render_preview.py:load2,render`)
- Modify: `repair-shop-game/assets/models/` (thêm 6 file copy)
- Test: mắt thường + `ls`

**Interfaces:**
- Consumes: `load2(path: str) -> (verts, _, faces)` từ render_preview.py, 6 file OBJ/MTL từ Task 1-2.
- Produces: `preview_ban_hoc.png`, `preview_giao_vien.png`, `preview_hoai_niem.png` (640x880 front/back ghép, SCALE=min(W,H)/2.15).

- [ ] **Step 1: Write the failing check (file chưa tồn tại)**

```python
def test_previews_exist():
    import os
    assert os.path.exists("chibi-model/preview_ban_hoc.png")
```

- [ ] **Step 2: Run check to verify it fails**

Run: `python3 -c "import os; assert os.path.exists('chibi-model/preview_ban_hoc.png')"`
Expected: FAIL AssertionError.

- [ ] **Step 3: Implement `chibi-model/render_preview_npcs.py` với `render_variant(name: str) -> None`**

Reuse load2/render/write PNG stdlib (copy hàm save_png từ render_preview.py), loop 3 variants front+back ghép dọc.

- [ ] **Step 4: Run render + copy + verify files**

Run: `python3 chibi-model/render_preview_npcs.py && cp chibi-model/ban_hoc.obj chibi-model/ban_hoc.mtl chibi-model/giao_vien.obj chibi-model/giao_vien.mtl chibi-model/hoai_niem.obj chibi-model/hoai_niem.mtl repair-shop-game/assets/models/ && ls repair-shop-game/assets/models/`
Expected: 3 PNG tồn tại, 6 file trong assets/models/, mở PNG thấy mặt -Y đúng (mắt/miệng front, balo/cặp/laptop back rõ).

- [ ] **Step 5: Commit**

```bash
git add chibi-model/render_preview_npcs.py chibi-model/preview_ban_hoc.png chibi-model/preview_giao_vien.png chibi-model/preview_hoai_niem.png repair-shop-game/assets/models/
git commit -m "feat: preview PNG + copy 3 NPC vào assets/models"
```

### Task 4: verify_npcs.py đầy đủ + kiểm tra Godot import

**Files:**
- Modify: `chibi-model/verify_npcs.py`
- Test: `chibi-model/verify_npcs.py`

**Interfaces:**
- Consumes: `build_variant(name)` từ Task 1-2, `load2(path)` từ render_preview.py.
- Produces: `main() -> int` exit 0 khi pass, in `PASS <variant>` từng variant.

- [ ] **Step 1: Write the failing full checks (chromaticity + orientation)**

```python
def test_face_orientation_minus_y():
    verts, _, faces = load2("chibi-model/ban_hoc.obj")
    assert min(v[1] for v in verts if v[2] > 1.4) < 0  # mắt/mũi ở Y âm
```

- [ ] **Step 2: Run to verify it fails (nếu chưa có check)**

Run: `python3 chibi-model/verify_npcs.py`
Expected: FAIL hoặc thiếu check orientation.

- [ ] **Step 3: Implement full `verify_npcs.py` (bounds + face -Y + chromaticity 3-4 điểm/variant)**

Reuse chroma/match/px_at từ verify_render.py (W,H 640,880, SCALE, CZ 1.006): ban_hoc áo trắng/quần xanh/balo xanh, giao_vien kính đen/cặp nâu/sơ mi kem, hoai_niem laptop xám/áo nâu/tóc dài. Thêm Review Focus tests: back-face kín (không lỗ), MTL đủ tên, chân chạm Z~0.

- [ ] **Step 4: Run full verification + Godot import check**

Run: `python3 chibi-model/verify_npcs.py && python3 chibi-model/generate_npcs.py --all`
Expected: `PASS ban_hoc`, `PASS giao_vien`, `PASS hoai_niem`. Thủ công: mở Godot 4.7 → workshop.tscn thay tạm Mesh → 0 lỗi import, screenshot.

- [ ] **Step 5: Commit**

```bash
git add chibi-model/verify_npcs.py
git commit -m "test: full verify 3 NPC + Godot import check"
```
