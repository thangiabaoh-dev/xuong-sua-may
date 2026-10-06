# Machine Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Danh mục 32 mẫu laptop (10 hiện đại + 22 cổ) dạng `.tres` data-driven kèm bộ sinh ngẫu nhiên chọn máy + lỗi theo mức tri thức.

**Architecture:** `MachineDef extends Resource` — mỗi máy 1 file `.tres` trong `data/machines/`, không có file index. `MachineGenerator` (hàm static) quét thư mục (sort để ổn định thứ tự), lọc theo `min_knowledge`, và generate máy bằng `RandomNumberGenerator` do bên ngoài truyền seed → cùng seed = cùng kết quả.

**Tech Stack:** Godot 4.7.2 (binary `godot` trên PATH), GDScript, test headless qua `godot --headless -s res://tests/run_tests.gd`.

**Spec:** `docs/superpowers/specs/2026-10-06-machine-catalog-design.md` — plan này lập luận từ spec; executor đọc cả hai. **Toàn bộ dữ liệu 32 máy nằm ở spec §4, không lặp lại trong plan** (mapping cột → field xem Task 1 Step 3).

## Global Constraints

- Godot **4.7.2**, binary `godot` (không `godot4`, không path tuyệt đối).
- Ngôn ngữ **GDScript**. Kiểu trả về bắt buộc khai báo (`-> Array[MachineDef]`, `-> void`). **Indent bằng tab** (style repo hiện có).
- Repo root = `/Users/hoangthangiabao/Documents/file nhảy cảm`, commit trên nhánh hiện tại (`feat/godot-foundation`). **Tuyệt đối không `git add -A` / `git add .`** — chỉ add đúng đường dẫn nêu trong từng task. Không đưa thay đổi có sẵn của `docs/superpowers/plans/2026-10-05-godot-foundation.md` và `repair-shop-game/tests/scratch_probe.gd` (không phải của plan này) vào commit.
- `.godot/` đã gitignore. **Phải commit file `.gd.uid`** sinh sau `--import` cùng script của task.
- Lệnh test chuẩn (mọi task bắt đầu bằng `--import`):
  `godot --headless --path repair-shop-game --import >/dev/null 2>&1; godot --headless --path repair-shop-game -s res://tests/run_tests.gd`
- Dữ liệu đối chiếu spec §2 (key lỗi + key khách) và §4 (bảng 32 máy). Test message tiếng Anh (style Plan 1).
- Đã probe thực tế với 4.7.2: template `.tres` ghi tay bên dưới load đúng (PackedStringArray có dấu tiếng Việt OK), file `.tres` hỏng → `load()` trả `null` + in `ERROR` stderr nhưng process exit 0, `--import` sinh `.gd.uid`.

## Review Focus

Năm điểm spec ngầm định nhưng dễ hỏng nhất — mỗi dòng có test pin vào task sở hữu:

1. **`.tres` ghi tay sai format** → `load()` null → catalog mất máy im lặng. → Task 1 test fixture `broken.tres` bị bỏ qua (`scan_dir` trả 1) + Task 1/2 test ngưỡng đếm (≥10, ≥32).
2. **Pool rỗng ở tuần đầu (tri thức 0)** → không có đơn nào cho người chơi mới. → Task 3 test `candidates(0, catalog).size() > 0`.
3. **Máy cổ lọt pool khi tri thức 0** → nội dung bị khoá lộ sớm. → Task 3 test 50 lần `generate(rng, 0)` toàn `era == HIEN_DAI`.
4. **Lỗi không hợp lý với máy** (inverter/CCFL trên máy LED) → chẩn đoán vô lý. → Task 2 test `dim_screen ∈ faults ⇒ era == CO`; Task 3 test `fault ∈ def.faults`.
5. **Không tái lập được theo seed** → test flaky, plan sau không repro. → Task 3 test 2 lần cùng seed 42 → cùng `model` + `fault`; Task 1 code step sort tên file trong `scan_dir` (thứ tự catalog ổn định giữa các lần chạy — sort không test được in-process, đây là ràng buộc implementation).

---

## File Structure

```
repair-shop-game/
├── scripts/
│   ├── machine_def.gd          # class_name MachineDef extends Resource — data 1 máy
│   ├── machine_generator.gd    # class_name MachineGenerator — load/catalog + generate
│   └── generated_machine.gd    # class_name GeneratedMachine extends RefCounted — kết quả 1 lần sinh
├── data/
│   └── machines/               # 32 file .tres (10 hiện đại Task 1 + 22 cổ Task 2), không index
├── tests/
│   ├── fixtures/machines/
│   │   ├── good_toy.tres       # .tres hợp lệ cho test fixture
│   │   └── broken.tres         # .tres cố tình hỏng
│   ├── test_machine_catalog.gd # Task 1 tạo, Task 2 mở rộng
│   └── test_machine_generator.gd # Task 3
```

**Phân định trách nhiệm:** `load_catalog()` chỉ trả cache; mọi quét thư mục qua `scan_dir(dir_path)` (test được với fixture). `generate()` không tự sinh lỗi giá — price luôn `= def.base_price` (Plan 2 tính tip/điều chỉnh). Dữ liệu tĩnh nằm ở `.tres`, không ở code.

---

### Task 1: MachineDef + loader thư mục + 10 máy hiện đại

**Files:**
- Create: `repair-shop-game/scripts/machine_def.gd`
- Create: `repair-shop-game/scripts/machine_generator.gd`
- Create: `repair-shop-game/data/machines/` — 10 file `.tres` (danh sách Step 3)
- Create: `repair-shop-game/tests/fixtures/machines/good_toy.tres`
- Create: `repair-shop-game/tests/fixtures/machines/broken.tres`
- Create: `repair-shop-game/tests/test_machine_catalog.gd`
- Modify: `repair-shop-game/tests/run_tests.gd` (thêm vào `TEST_SCRIPTS`)

**Interfaces:**
- Consumes: harness `tests/test_case.gd` (`check`, `check_eq`, `failures`), `tests/run_tests.gd` (`TEST_SCRIPTS`).
- Produces:
  - `machine_def.gd` → `class_name MachineDef extends Resource`, `enum Era { HIEN_DAI, CO }`, `@export` fields: `era: Era`, `brand: String`, `model: String`, `year: int`, `parts: PackedStringArray`, `faults: PackedStringArray`, `difficulty: int`, `base_price: int`, `customer_types: PackedStringArray`, `min_knowledge: int`.
  - `machine_generator.gd` → `class_name MachineGenerator extends RefCounted`, `const CATALOG_DIR := "res://data/machines"`, `static func load_catalog() -> Array[MachineDef]` (cache 1 lần qua `static var`), `static func scan_dir(dir_path: String) -> Array[MachineDef]` (mọi file `.tres` load được → `Array[MachineDef]`; file hỏng → bỏ qua + `push_error`; **sort tên file tăng dần trước khi load**).
  - Test thresholds: tổng ≥ 10, hiện đại ≥ 10 + invariant toàn bộ máy (Task 2 thêm ngưỡng vintage).

- [ ] **Step 1: Viết `tests/test_machine_catalog.gd` (fail trước) + đăng ký vào `run_tests.gd`**

```gdscript
extends "res://tests/test_case.gd"

const FAULT_KEYS: Array[String] = [
	"no_power", "dim_screen", "overheat", "slow_hdd", "keyboard_dead",
	"battery_swollen", "no_wifi", "loose_port", "board_short"
]
const CUSTOMER_KEYS: Array[String] = ["ban_hoc", "giao_vien", "hoai_niem"]

func run() -> void:
	var catalog := MachineGenerator.load_catalog()
	check(catalog.size() >= 10, "catalog has at least 10 machines")
	if catalog.is_empty():
		return
	var modern := 0
	for m in catalog:
		if m.era == MachineDef.Era.HIEN_DAI:
			modern += 1
		check(m.era == MachineDef.Era.HIEN_DAI or m.era == MachineDef.Era.CO, "era valid: " + m.model)
		check(m.brand != "" and m.model != "", "brand/model non-empty: " + m.model)
		check(m.year >= 1990 and m.year <= 2026, "year in 1990-2026: " + m.model)
		check(m.parts.size() > 0, "parts non-empty: " + m.model)
		check(m.faults.size() > 0, "faults non-empty: " + m.model)
		for fk in m.faults:
			check(FAULT_KEYS.has(fk), "known fault '" + fk + "' on " + m.model)
		check(m.difficulty >= 1 and m.difficulty <= 5, "difficulty 1-5: " + m.model)
		check(m.base_price > 0, "price positive: " + m.model)
		check(m.min_knowledge >= 0, "min_knowledge >= 0: " + m.model)
		check(m.customer_types.size() > 0, "customers non-empty: " + m.model)
		for ck in m.customer_types:
			check(CUSTOMER_KEYS.has(ck), "known customer '" + ck + "' on " + m.model)
	check(modern >= 10, "at least 10 modern machines")

	var fx := MachineGenerator.scan_dir("res://tests/fixtures/machines")
	check_eq(fx.size(), 1, "broken .tres skipped by scan_dir")
```

Thêm `"res://tests/test_machine_catalog.gd"` vào `TEST_SCRIPTS`.

- [ ] **Step 2: Chạy test — mong đợi FAIL**

```bash
godot --headless --path repair-shop-game --import >/dev/null 2>&1; godot --headless --path repair-shop-game -s res://tests/run_tests.gd
```

Expected: `FAIL res://tests/test_machine_catalog.gd (cannot load)` (class `MachineGenerator` chưa tồn tại) → exit `1`.

- [ ] **Step 3: Tạo `machine_def.gd`, `machine_generator.gd`, 10 `.tres` hiện đại, fixture**

`scripts/machine_def.gd`:

```gdscript
class_name MachineDef
extends Resource

enum Era { HIEN_DAI, CO }

@export var era: Era = Era.HIEN_DAI
@export var brand: String = ""
@export var model: String = ""
@export var year: int = 0
@export var parts: PackedStringArray = PackedStringArray()
@export var faults: PackedStringArray = PackedStringArray()
@export var difficulty: int = 1
@export var base_price: int = 0
@export var customer_types: PackedStringArray = PackedStringArray()
@export var min_knowledge: int = 0
```

`scripts/machine_generator.gd` — Task 1 chỉ có 2 hàm (generate ở Task 3):

```gdscript
class_name MachineGenerator
extends RefCounted

const CATALOG_DIR := "res://data/machines"

static var _cache: Array[MachineDef] = []
static var _cache_valid := false

static func load_catalog() -> Array[MachineDef]:
	# trả _cache nếu đã load, ngược lại _cache = scan_dir(CATALOG_DIR)
	...

static func scan_dir(dir_path: String) -> Array[MachineDef]:
	# DirAccess.open fail → push_error + trả rỗng.
	# Lấy files, files.sort() (BẮT BUỘC — ổn định thứ tự catalog giữa các lần chạy),
	# giữ file có extension "tres", load() từng file, null → push_error + bỏ qua.
	...
```

Body để trống phần cốt lõi — test quyết định. **`files.sort()` là ràng buộc bắt buộc** (Review Focus #5).

**Mapping spec §4 → field `.tres`** (bảng HIỆN ĐẠI Task 1, bảng CỔ Task 2):
- Bảng HIỆN ĐẠI → `era = 0`; bảng CỔ → `era = 1`
- Cột `Máy (năm)` → `model` = tên máy (VD "ThinkPad T60"), `year` = số trong ngoặc, `brand` = nhà sản xuất suy ra (ThinkPad→Lenovo, MacBook/PowerBook/iBook→Apple, Compaq→HP, PC ThinkCentre→Lenovo…)
- Cột `Lỗi` → `faults` giữ nguyên key (phân tách `, `)
- Cột `ĐK` → `difficulty`, `Giá` → `base_price` (bỏ dấu chấm), `TT` → `min_knowledge`
- Cột `Khách` → `customer_types`: bạn học→`ban_hoc`, giáo viên→`giao_vien`, hoài niệm→`hoai_niem`
- Cột `Linh kiện riêng` → `parts`

Template `.tres` **đã probe đúng với 4.7.2** — mỗi file `data/machines/<tên_snake_case>.tres`:

```
[gd_resource type="Resource" script_class="MachineDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/machine_def.gd" id="1"]

[resource]
script = ExtResource("1")
era = 1
brand = "Lenovo"
model = "ThinkPad T60"
year = 2006
parts = PackedStringArray("đèn nền CCFL", "ổ PATA", "bàn phím 7-row")
faults = PackedStringArray("dim_screen", "no_power", "keyboard_dead", "battery_swollen", "board_short")
difficulty = 3
base_price = 190000
customer_types = PackedStringArray("hoai_niem")
min_knowledge = 1
```

(Bản mẫu trên là máy cổ ví dụ — Task 2. Task 1 viết 10 file máy hiện đại theo spec §4.1, `era = 0`.)

10 file Task 1 (spec §4.1):
`dell_inspiron_15_3000.tres`, `hp_15.tres`, `lenovo_ideapad_3.tres`, `asus_vivobook_15.tres`, `acer_aspire_5.tres`, `acer_nitro_5.tres`, `dell_latitude_5490.tres`, `macbook_air_2017.tres`, `macbook_pro_2015_retina.tres`, `pc_thinkcentre_m710q.tres`

Fixture — `tests/fixtures/machines/good_toy.tres`: template trên đổi các field thành: `era = 0`, `brand = "Toy"`, `model = "Toy Laptop"`, `year = 2000`, `parts = PackedStringArray("toy")`, `faults = PackedStringArray("no_power")`, `difficulty = 1`, `base_price = 1000`, `customer_types = PackedStringArray("ban_hoc")`, `min_knowledge = 0`.
`tests/fixtures/machines/broken.tres`: nội dung 1 dòng `this is not a resource [[[`.

- [ ] **Step 4: Chạy test — mong đợi PASS**

```bash
godot --headless --path repair-shop-game --import >/dev/null 2>&1; godot --headless --path repair-shop-game -s res://tests/run_tests.gd
```

Expected: `PASS res://tests/test_machine_catalog.gd`, `TOTAL_FAILURES=0`, exit `0`.
(Lưu ý stderr sẽ in `ERROR ... broken.tres` từ lần load fixture — engine in nhưng không làm test fail, đã probe.)

- [ ] **Step 5: Commit**

```bash
git add repair-shop-game/scripts/machine_def.gd repair-shop-game/scripts/machine_def.gd.uid \
  repair-shop-game/scripts/machine_generator.gd repair-shop-game/scripts/machine_generator.gd.uid \
  repair-shop-game/data/machines/dell_inspiron_15_3000.tres repair-shop-game/data/machines/hp_15.tres \
  repair-shop-game/data/machines/lenovo_ideapad_3.tres repair-shop-game/data/machines/asus_vivobook_15.tres \
  repair-shop-game/data/machines/acer_aspire_5.tres repair-shop-game/data/machines/acer_nitro_5.tres \
  repair-shop-game/data/machines/dell_latitude_5490.tres repair-shop-game/data/machines/macbook_air_2017.tres \
  repair-shop-game/data/machines/macbook_pro_2015_retina.tres repair-shop-game/data/machines/pc_thinkcentre_m710q.tres \
  repair-shop-game/tests/fixtures/machines/good_toy.tres repair-shop-game/tests/fixtures/machines/broken.tres \
  repair-shop-game/tests/test_machine_catalog.gd repair-shop-game/tests/test_machine_catalog.gd.uid \
  repair-shop-game/tests/run_tests.gd
git commit -m "feat: machine resource with modern laptop catalog and directory loader"
```

---

### Task 2: 22 máy cổ + mở rộng test catalog

**Files:**
- Create: `repair-shop-game/data/machines/` — 22 file `.tres` (danh sách Step 3)
- Modify: `repair-shop-game/tests/test_machine_catalog.gd`

**Interfaces:**
- Consumes: `MachineDef`, template `.tres`, mapping rule (Task 1); `scan_dir`/`load_catalog`.
- Produces: catalog đạt ngưỡng spec §5.1 — tổng ≥ 32, hiện đại ≥ 10, cổ ≥ 22, invariant `dim_screen ⇒ era == CO`. Test file version đầy đủ.

- [ ] **Step 1: Mở rộng `tests/test_machine_catalog.gd` (fail trước)**

Thêm 2 dòng sau dòng `check(modern >= 10, ...)`:

```gdscript
	check(catalog.size() >= 32, "catalog has at least 32 machines")
	check(vintage >= 22, "at least 22 vintage machines")
```

Trong loop, khai báo `var vintage := 0` cạnh `var modern := 0`, đếm `vintage` khi `era == MachineDef.Era.CO`, và thêm invariant (Review Focus #4):

```gdscript
		if m.era != MachineDef.Era.CO:
			check(not m.faults.has("dim_screen"), "dim_screen only on vintage: " + m.model)
```

- [ ] **Step 2: Chạy test — mong đợi FAIL**

```bash
godot --headless --path repair-shop-game --import >/dev/null 2>&1; godot --headless --path repair-shop-game -s res://tests/run_tests.gd
```

Expected: `FAIL ... at least 22 vintage machines` và `FAIL ... at least 32 machines` → exit `1`.

- [ ] **Step 3: Tạo 22 file `.tres` máy cổ theo spec §4.2**

Dùng template Task 1, `era = 1`, mapping y hệt. Danh sách file:

`thinkpad_t40.tres`, `thinkpad_t60.tres`, `thinkpad_t400.tres`, `thinkpad_x200.tres`, `ibook_g3_clamshell.tres`, `ibook_g4.tres`, `powerbook_g4_15.tres`, `macbook_polycarbonate_2006.tres`, `macbook_white_unibody_2009.tres`, `macbook_air_2010.tres`, `dell_inspiron_6000.tres`, `dell_inspiron_1525.tres`, `dell_latitude_d620.tres`, `dell_xps_m1330.tres`, `hp_pavilion_dv1000.tres`, `hp_pavilion_dv6000.tres`, `compaq_presario_v3000.tres`, `hp_elitebook_6930p.tres`, `toshiba_satellite_a100.tres`, `toshiba_satellite_l300.tres`, `sony_vaio_fe.tres`, `acer_aspire_5620.tres`

- [ ] **Step 4: Chạy test — mong đợi PASS**

```bash
godot --headless --path repair-shop-game --import >/dev/null 2>&1; godot --headless --path repair-shop-game -s res://tests/run_tests.gd
```

Expected: `TOTAL_FAILURES=0`, exit `0`.

- [ ] **Step 5: Commit**

```bash
git add repair-shop-game/data/machines/thinkpad_t40.tres repair-shop-game/data/machines/thinkpad_t60.tres \
  repair-shop-game/data/machines/thinkpad_t400.tres repair-shop-game/data/machines/thinkpad_x200.tres \
  repair-shop-game/data/machines/ibook_g3_clamshell.tres repair-shop-game/data/machines/ibook_g4.tres \
  repair-shop-game/data/machines/powerbook_g4_15.tres repair-shop-game/data/machines/macbook_polycarbonate_2006.tres \
  repair-shop-game/data/machines/macbook_white_unibody_2009.tres repair-shop-game/data/machines/macbook_air_2010.tres \
  repair-shop-game/data/machines/dell_inspiron_6000.tres repair-shop-game/data/machines/dell_inspiron_1525.tres \
  repair-shop-game/data/machines/dell_latitude_d620.tres repair-shop-game/data/machines/dell_xps_m1330.tres \
  repair-shop-game/data/machines/hp_pavilion_dv1000.tres repair-shop-game/data/machines/hp_pavilion_dv6000.tres \
  repair-shop-game/data/machines/compaq_presario_v3000.tres repair-shop-game/data/machines/hp_elitebook_6930p.tres \
  repair-shop-game/data/machines/toshiba_satellite_a100.tres repair-shop-game/data/machines/toshiba_satellite_l300.tres \
  repair-shop-game/data/machines/sony_vaio_fe.tres repair-shop-game/data/machines/acer_aspire_5620.tres \
  repair-shop-game/tests/test_machine_catalog.gd
git commit -m "feat: vintage laptop catalog entries with knowledge gating data"
```

---

### Task 3: GeneratedMachine + candidates + generate

**Files:**
- Create: `repair-shop-game/scripts/generated_machine.gd`
- Modify: `repair-shop-game/scripts/machine_generator.gd` (thêm `candidates`, `generate`)
- Create: `repair-shop-game/tests/test_machine_generator.gd`
- Modify: `repair-shop-game/tests/run_tests.gd` (thêm vào `TEST_SCRIPTS`)

**Interfaces:**
- Consumes: `load_catalog()`, catalog 32 máy (Tasks 1–2), `MachineDef`.
- Produces:
  - `generated_machine.gd` → `class_name GeneratedMachine extends RefCounted`, vars: `def: MachineDef`, `fault: StringName`, `price: int`.
  - `static func candidates(knowledge: int, catalog: Array[MachineDef]) -> Array[MachineDef]` — lọc `min_knowledge <= knowledge`.
  - `static func generate(rng: RandomNumberGenerator, knowledge: int) -> GeneratedMachine` — trả `null` + `push_warning` khi pool rỗng; `fault` luôn thuộc `def.faults`; `price = def.base_price`.

- [ ] **Step 1: Viết `tests/test_machine_generator.gd` (fail trước) + đăng ký vào `run_tests.gd`**

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var catalog := MachineGenerator.load_catalog()
	check(catalog.size() >= 32, "catalog loaded")

	check(MachineGenerator.candidates(0, catalog).size() > 0, "week 1 pool not empty")

	for i in 50:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + i
		var gm := MachineGenerator.generate(rng, 0)
		check(gm != null, "generate non-null at knowledge 0")
		if gm != null:
			check_eq(gm.def.era, MachineDef.Era.HIEN_DAI, "no vintage at knowledge 0")
			check(gm.def.faults.has(String(gm.fault)), "fault belongs to machine")
			check_eq(gm.price, gm.def.base_price, "price equals base_price")

	var has_vintage := false
	for m in MachineGenerator.candidates(2, catalog):
		if m.era == MachineDef.Era.CO:
			has_vintage = true
	check(has_vintage, "knowledge 2 unlocks vintage machines")

	var r1 := RandomNumberGenerator.new()
	r1.seed = 42
	var r2 := RandomNumberGenerator.new()
	r2.seed = 42
	var a := MachineGenerator.generate(r1, 2)
	var b := MachineGenerator.generate(r2, 2)
	check(a != null and b != null, "determinism samples generated")
	if a != null and b != null:
		check_eq(a.def.model, b.def.model, "same seed same model")
		check_eq(a.fault, b.fault, "same seed same fault")

	var none := MachineGenerator.generate(RandomNumberGenerator.new(), -1)
	check(none == null, "empty pool returns null")
```

Thêm `"res://tests/test_machine_generator.gd"` vào `TEST_SCRIPTS`.

- [ ] **Step 2: Chạy test — mong đợi FAIL**

```bash
godot --headless --path repair-shop-game --import >/dev/null 2>&1; godot --headless --path repair-shop-game -s res://tests/run_tests.gd
```

Expected: `FAIL res://tests/test_machine_generator.gd (cannot load)` (`candidates`/`generate` chưa tồn tại) → exit `1`.

- [ ] **Step 3: Implement `GeneratedMachine` + `candidates()` + `generate()`**

`scripts/generated_machine.gd`:

```gdscript
class_name GeneratedMachine
extends RefCounted

var def: MachineDef
var fault: StringName
var price: int
```

Thêm vào `machine_generator.gd`:

```gdscript
static func candidates(knowledge: int, catalog: Array[MachineDef]) -> Array[MachineDef]
static func generate(rng: RandomNumberGenerator, knowledge: int) -> GeneratedMachine
```

Body `candidates`: giữ `m.min_knowledge <= knowledge`.
Body `generate`: `pool = candidates(knowledge, load_catalog())` → rỗng thì `push_warning` + trả `null`; chọn `pool[rng.randi_range(0, pool.size() - 1)]`; chọn lỗi ngẫu nhiên trong `def.faults` (catalog test đã pin `faults` không rỗng) → `StringName`; `price = def.base_price`. **Không** clamp/round giá, không weight — spec §3.2 chỉ định uniform.

- [ ] **Step 4: Chạy test — mong đợi PASS**

```bash
godot --headless --path repair-shop-game --import >/dev/null 2>&1; godot --headless --path repair-shop-game -s res://tests/run_tests.gd
```

Expected: `PASS` cả 3 test, `TOTAL_FAILURES=0`, exit `0`.

- [ ] **Step 5: Smoke run toàn project**

```bash
godot --headless --path repair-shop-game --quit-after 60 2>&1 | tail -20; echo "EXIT=${PIPESTATUS[0]}"
```

Expected: `EXIT=0`, không `SCRIPT ERROR`.

- [ ] **Step 6: Commit**

```bash
git add repair-shop-game/scripts/generated_machine.gd repair-shop-game/scripts/generated_machine.gd.uid \
  repair-shop-game/scripts/machine_generator.gd \
  repair-shop-game/tests/test_machine_generator.gd repair-shop-game/tests/test_machine_generator.gd.uid \
  repair-shop-game/tests/run_tests.gd
git commit -m "feat: seeded random machine generator with knowledge gate"
```
