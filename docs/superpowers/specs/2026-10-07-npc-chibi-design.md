# Design — 3 NPC Chibi cho Xưởng Sửa Máy

- Date: 2026-10-07
- Status: Approved (4/4 sections OK)
- Game: repair-shop-game (Godot 4.7, Forward+, low-poly stylised chibi)
- Base ref: chibi-model/chibi.obj + chibi.mtl, Z-up mặt -Y, generate_chibi.py (598 lines, procedural super_shape/box)
- Player ref: scenes/player.tscn (CharacterBody3D + Capsule r=0.35 h=2.0 + MeshInstance xoay -90,180)

## 1. Intent (đã chốt với user)

- Mục tiêu: thêm 3 nhân vật khách theo DESIGN.md §5.1 để thả vào workshop/school scenes.
- User chọn: Cả 3 nhân vật + Giữ OBJ tĩnh (procedural) + Xong khi file + xem được (OBJ+MTL+PNG, import Godot không lỗi).
- Thành công = drop-in thay Mesh trong player.tscn/workshop, đúng tỉ lệ Capsule, đúng trục, không SCRIPT ERROR.

## 2. Approaches đã xét

- A. Procedural chung từ base chibi (CHỌN): `generate_npcs.py` tái dùng super_shape/box/obj_normals/write_obj/write_mtl, 1 base + 3 variant. Pros: đồng bộ style/scale/materials, regenerate được, reuse verify. Cons: không chi tiết cao.
- B. Clone OBJ sửa tay: nhanh 1 lần nhưng lệch tỉ lệ, khó maintain. LOẠI.
- C. Blender GLB rigged: đẹp + anim nhưng phá pipeline, nặng, trái lựa chọn OBJ tĩnh. LOẠI.

## 3. Architecture & file layout

- Mới: `chibi-model/generate_npcs.py` (không sửa generate_chibi.py cũ).
  - Copy helpers: sgnpow/sub/add/mul/cross/length/unit/lerp3/spoint/phi_for_z/super_shape/box/face_normal/obj_normals/write_mtl/write_obj/stats.
  - Thêm: `base_chibi(mats) -> OBJECTS` + `variant_ban_hoc()/variant_giao_vien()/variant_hoai_niem()`.
- Output trong `chibi-model/`: ban_hoc.obj/.mtl, giao_vien.obj/.mtl, hoai_niem.obj/.mtl + preview_ban_hoc.png, preview_giao_vien.png, preview_hoai_niem.png.
- Copy sang `repair-shop-game/assets/models/` (để Godot gen .import). Không sửa player.tscn/workshop.tscn phase này.
- Reuse `render_preview.py:load2()` để render front/back, mở rộng `verify_render.py` -> `verify_npcs.py`.

## 4. Components — 3 variant

Chung: đầu to ~0.55m, tổng cao 1.85-2.0m, Z-up, mặt -Y, da (246,215,188), <8k verts/<8k faces, materials flat Kd + Ka*0.25, Ks 0.1 Ns 24 illum 2.

- ban_hoc (Bạn học cần máy gấp): áo trắng (244,245,247) + quần xanh dương (58,95,168), tóc ngắn đen (24,27,36), balo vuông xanh lá (65,150,90) sau lưng + 2 quai trước ngực (box smooth=False).
- giao_vien (Giáo viên/phòng tin học): sơ mi kem (235,225,200) + quần nâu (110,85,60), kính hộp đen mỏng trước mắt (box 0.02 dày), cặp nâu (90,65,40) hông phải, tóc gọn đen (30,30,35).
- hoai_niem (Người hoài niệm): áo khoác nâu cũ (150,110,80) + quần xám (130,130,135), tóc dài nâu (80,60,45) buộc đuôi sau, ôm laptop cổ dày xám (140,140,145) trước ngực bằng 2 tay (box).
- Normals: smooth=True cho đầu/da/body tròn, smooth=False cho balo/cặp/laptop/kính để cạnh sắc.

## 5. Data flow

1. `python3 generate_npcs.py` -> ghi 6 file OBJ/MTL + in stats objects/verts/faces.
2. `python3 render_preview_npcs.py` (reuse render_preview) -> 3 PNG front/back (640x880, SCALE=min(W,H)/2.15, CZ=1.006).
3. Copy vào assets/models/ -> mở Godot 4.7 -> kiểm tra import không lỗi.
4. Test thay Mesh tạm trong workshop.tscn với rotation_degrees (-90,180,0) -> đứng đúng trên Floor.

## 6. Error handling / tương thích

- Trục: giữ Z-up xuất file, Godot xoay -90 X +180 Y như player.tscn hiện tại.
- Mặt: thứ tự faces CCW, kiểm tra face_normal không zero.
- Scale: clamp Z [0,2.05], XY trong [-0.8,0.8], nếu vượt -> fail script.
- Materials: tên duy nhất mỗi part, `usemtl` trước mỗi `o`, mtllib đúng tên file.
- Không phá file cũ: chibi.obj/mtl, player.tscn giữ nguyên.

## 7. Testing & nghiệm thu

- `verify_npcs.py`: verts/faces <10k, cao đúng, mặt -Y (mắt/mũi Y<0), sample 3-4 màu/variant bằng chromaticity (giống verify_render.py):
  - ban_hoc: áo trắng, quần xanh, balo xanh.
  - giao_vien: kính đen, cặp nâu, sơ mi kem.
  - hoai_niem: laptop xám, áo nâu, tóc dài.
- Thủ công: import Godot 0 lỗi, thả vào workshop đứng được, screenshot.
- Done khi: 6 file + 3 PNG + pass verify + import sạch.

## 8. Non-goals

- Không rig/skeleton/animation, không GLB, không .blend tay.
- Không NPC .tscn + collision sẵn (đã loại ở câu hỏi success criteria, chọn File+xem được).
- Không sửa gameplay/schedule/repair logic.

## 9. Rủi ro

- Lệch style nếu tự chọn màu sai -> giảm thiểu bằng reuse MATERIALS palette chibi + verify màu.
- Godot .import cache cũ -> xóa .godot/imported và reimport nếu cần.
