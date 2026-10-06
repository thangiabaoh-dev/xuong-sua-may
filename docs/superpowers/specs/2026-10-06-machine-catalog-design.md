# Design — Danh mục máy & bộ sinh ngẫu nhiên (Machine Catalog)

**Ngày:** 2026-10-06 · **Trạng thái:** Design đã duyệt (4 phần, chat) — chờ review bản viết
**Phạm vi:** `repair-shop-game` — subsystem dữ liệu máy + sinh máy ngẫu nhiên cho đơn khách

---

## 1. Mục tiêu & phạm vi

**Mục tiêu:** Danh mục ~32 mẫu laptop (10 hiện đại + 22 cổ) dạng data-driven, kèm bộ sinh ngẫu nhiên chọn máy + lỗi cho khách mang máy tới sửa/thay linh kiện.

**Trong phạm vi:**
- `MachineDef` Resource — 1 file `.tres` mỗi máy, thêm máy mới không sửa code (DESIGN §5.6)
- `MachineGenerator` — lọc theo tri thức (DESIGN §7), chọn ngẫu nhiên máy + 1 lỗi của máy đó
- Catalog đầy đủ 32 mẫu đã duyệt trong chat
- Test headless TDD theo harness `run_tests.gd` hiện có

**Ngoài phạm vi (plan sau):**
- Khách, triệu chứng mô tả, thời hạn, đơn hoàn chỉnh — Plan 2 ghép vào `GeneratedMachine`
- UI hiển thị, 3D model laptop, text lỗi tiếng Việt hiển thị cho khách

---

## 2. Cấu trúc file & Data model

```
repair-shop-game/
├── scripts/
│   ├── machine_def.gd        # class_name MachineDef extends Resource
│   ├── generated_machine.gd  # class_name GeneratedMachine extends RefCounted
│   └── machine_generator.gd  # class_name MachineGenerator (hàm static)
├── data/
│   └── machines/             # ~30 file .tres, 1 file/máy — không có file index
│       ├── thinkpad_t60.tres
│       ├── powerbook_g4.tres
│       └── ...
```

### 2.1 `MachineDef` (Resource)

| Field | Kiểu | Ghi chú |
|---|---|---|
| `era` | enum `HIEN_DAI = 0`, `CO = 1` | Thời đại |
| `brand` | String | VD "Lenovo" |
| `model` | String | VD "ThinkPad T60" |
| `year` | int | Năm sản xuất |
| `parts` | PackedStringArray | Linh kiện riêng biệt (VD "đèn nền CCFL", "ổ PATA") |
| `faults` | PackedStringArray | Mã lỗi khả dụng — rút từ tập 9 lỗi DESIGN §5.3 |
| `difficulty` | int | 1–5 |
| `base_price` | int | Tiền công cơ bản (VND) |
| `customer_types` | PackedStringArray | Loại khách thường mang máy này |
| `min_knowledge` | int | Tri thức tối thiểu để máy xuất hiện (≥ 0) |

### 2.2 Mã lỗi ổn định (key `StringName`)

9 key lấy từ DESIGN §5.3 — tên tiếng Việt hiển thị cho khách do Plan 2/4 lo, dữ liệu chỉ chứa key:

| Key | Ý nghĩa |
|---|---|
| `no_power` | Không lên nguồn |
| `dim_screen` | Màn hình mờ/tối (đèn nền inverter/CCFL) |
| `overheat` | Quá nhiệt do bụi |
| `slow_hdd` | Chậm do ổ cứng |
| `keyboard_dead` | Liệt bàn phím |
| `battery_swollen` | Pin phồng |
| `no_wifi` | Mất WiFi |
| `loose_port` | Lỏng cổng/cáp |
| `board_short` | Bo mạch chập |

### 2.3 Mã khách (key `StringName`)

`ban_hoc` · `giao_vien` · `hoai_niem` — khớp 3 archetype DESIGN §5.1.

---

## 3. Bộ sinh ngẫu nhiên

### 3.1 API

```gdscript
# scripts/machine_generator.gd
class_name MachineGenerator

# Quét res://data/machines/ một lần (static var cache), load mọi .tres hợp lệ
static func load_catalog() -> Array[MachineDef]

# Lọc máy có min_knowledge <= knowledge
static func candidates(knowledge: int, catalog: Array[MachineDef]) -> Array[MachineDef]

# Sinh 1 máy: chọn ngẫu nhiên máy → chọn 1 lỗi trong def.faults
# Trả null + push_warning nếu không có ứng viên
static func generate(rng: RandomNumberGenerator, knowledge: int) -> GeneratedMachine
```

```gdscript
# scripts/generated_machine.gd
class_name GeneratedMachine
extends RefCounted

var def: MachineDef
var fault: StringName   # luôn thuộc def.faults
var price: int          # = def.base_price (Plan 2 cộng tip/điều chỉnh sau)
```

### 3.2 Logic `generate()`

1. `candidates = candidates(knowledge, load_catalog())`
2. Rỗng → trả `null` + `push_warning`
3. Chọn máy ngẫu nhiên qua `rng` → chọn ngẫu nhiên 1 phần tử `def.faults` → package `GeneratedMachine`

### 3.3 Tính quyết định

`rng` do bên ngoài truyền vào (`RandomNumberGenerator` seed được). Cùng seed + cùng tri thức = cùng kết quả → test headless tái lập, không phụ thuộc frame hay thời gian thực.

### 3.4 Xử lý lỗi

- File `.tres` load thất bại → `load_catalog()` bỏ qua entry + `push_error` (không crash)
- Không có ứng viên → `generate()` trả `null` + `push_warning` — Plan 2 tự xử lý

---

## 4. Catalog 32 máy (đã duyệt)

Cột Lỗi dùng key mục 2.2. Máy cổ `min_knowledge` 1–2; máy hiện đại 0–1.

### 4.1 HIỆN ĐẠI — 10 máy

| Máy (năm) | Linh kiện riêng | Lỗi | ĐK | Giá | TT | Khách |
|---|---|---|---|---|---|---|
| Dell Inspiron 15 3000 (2019) | SSD, RAM DDR4, pin Li-ion | no_power, slow_hdd, no_wifi, loose_port | 1 | 70.000 | 0 | ban_hoc |
| HP 15 (2018) | SSD, RAM DDR4 | no_power, slow_hdd, keyboard_dead, loose_port | 1 | 70.000 | 0 | ban_hoc |
| Lenovo IdeaPad 3 (2020) | SSD NVMe, RAM DDR4 | no_wifi, battery_swollen, loose_port | 1 | 75.000 | 0 | ban_hoc |
| ASUS VivoBook 15 (2019) | SSD, RAM DDR4 | slow_hdd, no_wifi, keyboard_dead | 1 | 70.000 | 0 | ban_hoc |
| Acer Aspire 5 (2018) | SSD, quạt tản nhiệt | overheat, no_power, loose_port | 2 | 80.000 | 0 | ban_hoc |
| Acer Nitro 5 (2019) | GPU rời, quạt kép | overheat, no_power, no_wifi | 2 | 95.000 | 0 | ban_hoc |
| Dell Latitude 5490 (2018) | RAM DDR4, pin Li-ion | no_power, keyboard_dead, battery_swollen | 2 | 95.000 | 0 | giao_vien |
| MacBook Air 2017 | SSD Apple, pin Li-ion | no_power, battery_swollen, no_wifi | 2 | 100.000 | 0 | ban_hoc |
| MacBook Pro 2015 Retina | SSD Apple, cáp eDP | battery_swollen, no_power, no_wifi | 2 | 110.000 | 1 | hoai_niem |
| PC ThinkCentre M710q (2016) | SSD, RAM DDR4 | no_power, slow_hdd, overheat | 1 | 90.000 | 0 | giao_vien |

### 4.2 CỔ — 22 máy

| Máy (năm) | Linh kiện riêng | Lỗi | ĐK | Giá | TT | Khách |
|---|---|---|---|---|---|---|
| ThinkPad T40 (2003) | CCFL, PATA, bàn phím 7-row | dim_screen, no_power, keyboard_dead, slow_hdd, battery_swollen | 3 | 200.000 | 2 | hoài niệm |
| ThinkPad T60 (2006) | CCFL, PATA, bàn phím 7-row | dim_screen, no_power, keyboard_dead, battery_swollen, board_short | 3 | 190.000 | 1 | hoài niệm |
| ThinkPad T400 (2008) | SATA, bàn phím 7-row | no_power, keyboard_dead, slow_hdd, battery_swollen, no_wifi | 3 | 180.000 | 1 | hoài niệm |
| ThinkPad X200 (2008) | bàn phím 7-row, pin 9-cell | no_power, keyboard_dead, battery_swollen, loose_port | 3 | 210.000 | 1 | hoài niệm |
| iBook G3 Clamshell (1999) | CCFL, PATA, cáp ribbon, AirPort | dim_screen, no_power, board_short, slow_hdd, loose_port | 4 | 300.000 | 2 | hoài niệm |
| iBook G4 (2004) | CCFL, PATA, cáp ribbon | dim_screen, no_power, board_short, keyboard_dead, loose_port | 4 | 280.000 | 2 | hoài niệm |
| PowerBook G4 15" (2005) | CCFL, PATA, khung nhôm | dim_screen, no_power, board_short, overheat, loose_port | 4 | 320.000 | 2 | hoài niệm |
| MacBook polycarbonate 2006 | CCFL, SATA, nguồn MagSafe 1 | dim_screen, no_power, battery_swollen, board_short, no_wifi | 3 | 170.000 | 1 | hoài niệm |
| MacBook trắng Unibody 2009 | SATA, MagSafe 1, pin dính | no_power, battery_swollen, keyboard_dead, no_wifi | 3 | 160.000 | 1 | hoài niệm |
| MacBook Air 2010 | SSD Apple, MagSafe 1 | no_power, battery_swollen, no_wifi, loose_port | 3 | 150.000 | 1 | hoài niệm |
| Dell Inspiron 6000 (2005) | CCFL, PATA | dim_screen, no_power, slow_hdd, loose_port | 2 | 140.000 | 1 | hoài niệm |
| Dell Inspiron 1525 (2008) | CCFL, SATA | dim_screen, overheat, keyboard_dead, loose_port | 2 | 130.000 | 1 | ban_hoc |
| Dell Latitude D620 (2006) | CCFL, PATA | dim_screen, no_power, keyboard_dead, board_short | 3 | 160.000 | 1 | giao_vien |
| Dell XPS M1330 (2007) | CCFL, SATA | dim_screen, overheat, board_short, no_wifi | 3 | 170.000 | 1 | hoài niệm |
| HP Pavilion dv1000 (2005) | CCFL, PATA | dim_screen, overheat, no_power, loose_port | 2 | 130.000 | 1 | hoài niệm |
| HP Pavilion dv6000 (2007) | CCFL, SATA | overheat, dim_screen, board_short, no_wifi | 3 | 150.000 | 1 | ban_hoc |
| Compaq Presario V3000 (2007) | CCFL, SATA | overheat, dim_screen, keyboard_dead, loose_port | 3 | 140.000 | 1 | ban_hoc |
| HP EliteBook 6930p (2008) | CCFL, SATA | dim_screen, no_power, keyboard_dead, battery_swollen | 3 | 165.000 | 1 | giao_vien |
| Toshiba Satellite A100 (2006) | CCFL, PATA | dim_screen, slow_hdd, overheat, loose_port | 2 | 130.000 | 1 | ban_hoc |
| Toshiba Satellite L300 (2008) | CCFL, SATA | dim_screen, no_power, keyboard_dead, loose_port | 2 | 120.000 | 1 | ban_hoc |
| Sony Vaio FE (2006) | CCFL, PATA | dim_screen, no_power, board_short, battery_swollen | 3 | 170.000 | 1 | hoài niệm |
| Acer Aspire 5620 (2007) | CCFL, PATA | dim_screen, overheat, slow_hdd, loose_port | 2 | 125.000 | 1 | ban_hoc |

**Thống kê:** 32 máy · 10 hiện đại + 22 cổ · tri thức 0 → chỉ gặp máy hiện đại, đọc sách mở khoá máy cổ (DESIGN §7) · `board_short` chỉ gán cho máy difficulty ≥ 3 · `dim_screen` chỉ gán cho máy era `CO`.

---

## 5. Test (TDD)

Harness hiện có: thêm test vào `TEST_SCRIPTS` trong `tests/run_tests.gd`.

### 5.1 `tests/test_machine_catalog.gd`

- `load_catalog()`: tổng ≥ 32, hiện đại ≥ 10, cổ ≥ 22
- Mọi `MachineDef`: `faults` không rỗng và mọi key ∈ tập 9; `difficulty` 1–5; `base_price > 0`; `min_knowledge ≥ 0`; `era` hợp lệ; `brand`/`model` không rỗng; `year` ∈ 1990–2026; `customer_types` không rỗng và mọi key ∈ {ban_hoc, giao_vien, hoai_niem}
- Invariant: `dim_screen` ∈ faults → `era == CO`

### 5.2 `tests/test_machine_generator.gd`

- **Tính quyết định:** 2 lần `generate()` cùng seed + cùng knowledge → cùng `def.model` + cùng `fault`
- **Cổng tri thức:** knowledge = 0 → 50 lần liên tiếp toàn `HIEN_DAI`; knowledge = 2 → `candidates()` chứa máy cổ
- Mọi lần sinh: `fault ∈ def.faults`, `price == def.base_price`
- knowledge = -1 → `generate()` trả `null`

---

## 6. Tích hợp & thứ tự triển khai

- Plan 2 (vòng lặp sửa máy) gọi `MachineGenerator.generate(rng, knowledge)` rồi ghép khách/triệu chứng/thời hạn vào `GeneratedMachine`
- Không autoload, không UI trong phần này
- **Thứ tự:** Plan 1 (Task 5 main scene) còn thay đổi chưa commit → plan triển khai phần này đặt sau khi Plan 1 xong, tránh commit trồng chéo
- Test lệnh chuẩn: `godot --headless --path repair-shop-game --import >/dev/null 2>&1; godot --headless --path repair-shop-game -s res://tests/run_tests.gd`
- Commit đúng đường dẫn dưới `repair-shop-game/` và `docs/`, không `git add -A` (ràng buộc Plan 1)
