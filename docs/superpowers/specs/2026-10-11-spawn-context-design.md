# Spec — Cycle 4: Spawn context + khách mới trong đơn sửa

- **Ngày:** 2026-10-11
- **Branch:** cắt từ `feat/schedule-engine` @ `349cfc2`
- **Trạng thái:** design đã duyệt (brainstorming), chờ review spec → viết plan
- **Spec trước:** `2026-10-10-project-milestones-design.md` (cycle 3 tạo 2 khách + rule, spawn hoãn "spec tích hợp riêng" = spec này), `2026-10-09-progression-unlock-design.md` (rule `khach_truong_nhom`/`khach_giam_doc` đã regen)

## 1. Mục tiêu

`truong_nhom`/`giam_doc` (cycle 3, hiện chỉ hiện trên tracker) spawn trong đơn sửa trên **mọi máy** khi đạt mốc project. `OrderFactory` chuyển sang chữ ký spawn-context để khách mới và future gating đọc từ 1 dict. Quote placeholder chung cho khách mới (copy riêng viết sau).

## 2. Scope

**Trong scope:**
- `OrderFactory.make(rng, ctx: Dictionary)` thay `make(rng, knowledge, uy_tin)`
- Pool global: `truong_nhom`/`giam_doc` bỏ qua `customer_types` máy, gate theo `project_count`
- `repair_panel.gd` dựng ctx từ `game_state`
- Quote placeholder qua fallback `symptoms.get()`
- Test amend `test_order_factory.gd` (+ test liên quan tới chữ ký `make` nếu có)

**Ngoài scope (YAGNI):**
- Toast unlock / thưởng tiền từ project (đã ghi ở cycle 3 out-of-scope)
- Tune xác suất spawn / tần suất theo ngày
- `unlocked_ids` trong ctx (xem §6 Ruling)
- Gate uy_tin riêng cho khách mới (rule cycle 3 chỉ có `project_count` — spawn gate khớp rule)
- Sửa 32 file máy `.tres` (Q2 = "mọi máy" → gate-driven, không sửa catalog máy)
- 9 file fault `.tres` (placeholder qua code, không thêm quote)

## 3. Spawn context

```gdscript
# order_factory.gd
static func make(rng: RandomNumberGenerator, ctx: Dictionary) -> RepairOrder
```

- `ctx` keys: `"knowledge"` (int), `"uy_tin"` (int), `"project_count"` (int).
- Đọc an toàn: `int(ctx.get("knowledge", 0))` (ctx thiếu key → 0, không crash).
- Lời gọi duy nhất: `repair_panel.gd:59` — thay 3 biến local hiện tại bằng:
  ```gdscript
  var ctx := {"knowledge": int(game_state.knowledge), "uy_tin": int(game_state.uy_tin), "project_count": int(game_state.project_count)}
  var order := OrderFactory.make(rng, ctx)
  ```
  (giữ guard `game_state != null` như hiện tại — nếu null thì ctx = zeros).

### 3.1 Ruling — `unlocked_ids` không nằm trong ctx

Option brainstorm "spawn context" có nêu `unlocked_ids`, nhưng factory hiện gate bằng dict threshold (pattern `CUSTOMER_MIN_UY_TIN`), chưa cần "unlock truth". Đưa `unlocked_ids` vào ctx sẽ đòi `repair_panel` phụ thuộc `UnlockCore` (đang sống ở `workplace_screen`) — dây thêm không có lợi. Vì ctx là Dictionary, thêm key sau không đổi chữ ký. **Cost nếu sai:** refactor nhỏ sau.

## 4. Pool sinh đơn

```gdscript
const CUSTOMER_MIN_PROJECT_COUNT := {"truong_nhom": 1, "giam_doc": 3}
const CUSTOMER_GLOBAL := ["truong_nhom", "giam_doc"]
```

- `eligible_customers(def, ctx)`: pool máy hiện tại (loop `def.customer_types`, gate `CUSTOMER_MIN_UY_TIN` như cũ, uy_tin đọc từ ctx) **+** khách global: append nếu `project_count >= CUSTOMER_MIN_PROJECT_COUNT[key]` và key chưa có trong pool.
- Khách global **bỏ qua** `def.customer_types` — mọi máy phục vụ được khi pass gate.
- Ngưỡng `CUSTOMER_MIN_PROJECT_COUNT` trùng ngưỡng rule `khach_truong_nhom`/`khach_giam_doc` trong `unlock_rules.tres` — chấp nhận duplicate (cùng pattern uy_tin đã accept từ cycle progression).
- Pick: `customers[rng.randi_range(0, customers.size() - 1)]` — giữ nguyên.
- `project_count == 0` → pool chỉ khách máy cũ (behavior hiện tại không đổi khi ctx zeros).
- Pool rỗng → `null` (cơ chế hiện có).

## 5. Quote placeholder

```gdscript
const GENERIC_QUOTE := "Máy tôi có vấn đề, anh xem giúp tôi với."
```

- `order.symptom_quote = String(fault.symptoms.get(customer_key, GENERIC_QUOTE))`.
- Khách cũ (`ban_hoc`/`giao_vien`/`hoai_niem`) không đổi (key có sẵn trong `symptoms`).
- `risk_warning` đọc từ catalog theo flow panel sẵn có (`repair_panel.gd:669`) — 2 khách mới đã có warning từ cycle 3, không đổi.
- User chỉnh copy bất kỳ lúc nào bằng cách sửa 1 constant.

## 6. Error handling

| Tình huống | Hành vi |
|---|---|
| `ctx` thiếu key | `ctx.get(key, 0)` → 0 |
| `ctx == {}` | tương đương zeros — chỉ khách máy gate uy_tin 0 spawn được |
| Pool rỗng (máy không đủ gate) | `null` như hiện tại |
| `customer_key` không trong `fault.symptoms` | `GENERIC_QUOTE` (fallback, không crash) |

## 7. Testing (TDD — RED trước khi implement)

Amend `test_order_factory.gd` (đọc nội dung hiện tại lúc plan — chữ ký cũ `make(rng, k, uy)` phải sửa + giữ assertion cũ). Loop 50 lần cho các case pick ngẫu nhiên; ctx dùng `knowledge: 30` (đủ máy difficulty thấp ra pool, tránh null vì không có candidate):
- **zeros:** ctx `{knowledge: 30, uy_tin: 0, project_count: 0}` → 50 lần không bao giờ ra `truong_nhom`/`giam_doc`.
- **mốc 1:** ctx `{knowledge: 30, uy_tin: 100, project_count: 1}` → trong 50 lần có `truong_nhom`, không có `giam_doc`.
- **mốc 3:** ctx `{knowledge: 30, uy_tin: 100, project_count: 3}` → có cả 2 khách trong 50 lần.
- **mọi máy (Q2):** chọn def chỉ có `ban_hoc` trong `customer_types` (vd `hp_15`) — pool qua `eligible_customers` với ctx pass gate → chứa `truong_nhom` (pin: global customer không bị chặn `customer_types`).
- **quote fallback:** order sinh ra với `customer_key = "giam_doc"` → `symptom_quote == GENERIC_QUOTE`.
- **giữ regression:** uy_tin gating máy cũ vẫn đúng (assertion hiện có sửa theo ctx, nội dung không đổi).

Suite `bash repair-shop-game/tests/run_suite.sh` → gate như các cycle. Smoke main.tscn.

## 8. Files

| | File |
|---|---|
| Sửa | `scripts/orders/order_factory.gd` (signature, ctx, `CUSTOMER_GLOBAL`, `CUSTOMER_MIN_PROJECT_COUNT`, `GENERIC_QUOTE` fallback) |
| Sửa | `scripts/ui/repair_panel.gd:~59` (dựng ctx, gọi `make(rng, ctx)`) |
| Sửa | `tests/test_order_factory.gd` (ctx signature + case mới) + test khác gọi `make` (grep lúc plan) |

Không tạo file mới. Không sửa `.tres` (máy/fault/khách) — dữ liệu cycle 3 + placeholder code là đủ.

## 9. Cam kết plan

- `make` chỉ còn 1 chữ ký `make(rng, ctx)` — mọi caller được sửa (grep toàn repo lúc plan).
- `CUSTOMER_MIN_UY_TIN` giữ nguyên; thêm 2 const mới, không đổi giá trị cũ.
- `GENERIC_QUOTE` = chính xác chuỗi §5 (test assert đúng chuỗi).
- KHÔNG sửa `unlock_rules.tres`/`unlock_core.gd`/`build_progression.gd` (cycle 3 đã xong), KHÔNG sửa `.tres` máy/fault/khách.
- `.uid` commit kèm file mới (không có file mới ở cycle này); stage tên file cụ thể, không stage WIP outfit/animation của user.
