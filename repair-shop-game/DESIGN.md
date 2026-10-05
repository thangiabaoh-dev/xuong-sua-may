# DESIGN — Xưởng Sửa Máy Của Học Sinh Lớp 9

Game mô phỏng đời sống + sửa chữa, desktop, Godot 4, đồ hoạ 3D chibi.

**Trạng thái:** Design đã duyệt (7 phần). Chưa triển khai code.

---

## 1. Pitch & khái niệm

Người chơi là một học sinh lớp 9 tự mở tiệm sửa máy. Sáng học, chiều sửa máy cho bạn bè và thầy cô, tối làm project riêng. Vừa kiếm tiền, vừa rèn kỹ năng, vừa giữ lại những chiếc máy cũ đầy kỷ niệm.

Hai vòng lặp chồng lên nhau:

- **Vòng lặp phút** — thao tác của một đơn sửa máy.
- **Vòng lặp ngày** — lịch tuần quyết định bạn *có bao nhiêu* khung giờ; vòng lặp phút quyết định bạn *làm được bao nhiêu*.

### 1.1 Bốn chỉ số người chơi

| Chỉ số | Vai trò | Tăng / Giảm |
|---|---|---|
| **Tiền** | Mua linh kiện & dụng cụ. **Bắt đầu 50.000đ** (đủ mua 1–2 linh kiện cơ bản cho tuần đầu) | + tiền công, tip · − linh kiện, dụng cụ, sách |
| **Uy tín** | Mở khoá **khách lớn** (giáo viên, phòng tin học) | + đơn làm tốt, tư vấn đúng · − chẩn đoán sai, tư vấn sai, tone khô, đánh nhau |
| **Tri thức** | Mở khoá **máy cổ & lỗi phức tạp** | + đọc sách |
| **Điểm kỷ luật** | 0–100. **Bị trừ** khi đánh nhau / vi phạm nội quy. Khi xuống dưới ngưỡng → **bị cấm xuống nhà làm việc** tối đó (**mất cả ca sửa máy lẫn project**). Hồi dần theo từng ngày không vi phạm | − đánh nhau, vi phạm · + ngày không vi phạm |

---

## 2. Vòng lặp phút (1 đơn)

1. **Nhận đơn** — đọc triệu chứng, xem thời hạn. Chọn nhận / từ chối (từ chối không phạt, nhưng hết việc).
2. **Chẩn đoán** — pha lõi của game.
3. **Lấy linh kiện** — có kho thì lấy; thiếu thì ra tiệm mua (tốn tiền + tốn giờ).
4. **Tháo – lắp** — mini-game.
5. **Chạy thử** — máy phải lên nguồn mới tính xong.
6. **Trả khách** — nhận tiền, chấm điểm thời gian.

### 2.1 Chẩn đoán (3 pha)

| Pha | Việc |
|---|---|
| Triệu chứng | Khách mô tả: "máy không lên nguồn", "nóng bất thường", "màn hình nháy" |
| Kiểm tra | Chọn trong 3–4 phép thử (đo nguồn, nghe quạt, kiểm tra RAM, nhìn bo) → mỗi lần ra **manh mối** hoặc **loại trừ** được nhóm lỗi |
| Kết luận | Chọn 1 chẩn đoán cuối từ danh sách còn lại |

Chẩn đoán sai → máy hỏng nặng hơn, tốn thêm tiền + giờ. Sai liên tiếp → khách bực, mất uy tín.

### 2.2 Mini-game theo thao tác

| Thao tác | Mini-game | Gặp khi |
|---|---|---|
| Vặn ốc | Xoay đúng nhịp / nhả đúng lúc | Gần như mọi đơn |
| Hàn mạch | Giữ tay ổn định trong vùng an toàn | Bo mạch, máy cổ |
| Cắm cáp | Kéo đúng cổng, đúng chiều | Thay ổ, bàn phím |
| Lau / bụi, quét nhiệt | Quét đều tay | Vệ sinh máy cũ |

### 2.3 Sự cố trong lúc sửa & tone nói chuyện

| Sự kiện | Phản ứng | Hệ quả |
|---|---|---|
| Bạn học tới trêu ghẹo | **Kiềm chế** / Cãi lại / Đánh nhau | Kiềm chế: mất vài phút. Đánh nhau: thầy can → **trừ điểm kỷ luật** (xem 1.1) + **trừ uy tín**, về nhà bị mắng, đơn chậm → nguy cơ quá giờ |
| Nói chuyện với khách | **Thân mật** / Trung tính / **Khô & khó tính** | Khô → khách bực, mất đơn + mất uy tín. Thân nhiệt → tip & giới thiệu khách sau |
| Mâu thuẫn với gia đình | Về nhà bị mắng vì cúi đầu làm việc | **Mất khung giờ project** của ngày hôm đó |

### 2.4 Trạng thái thất bại

- Hết giờ ca → khách bỏ đi, mất đơn.
- Chẩn đoán sai nhiều → mất uy tín.
- Hết tiền → không mua được linh kiện.

---

## 3. Thế giới & địa điểm

Tham chiếu bối cảnh: **Trường THCS Ngô Sĩ Liên** — 12 Phạm Văn Hai, P. Tân Sơn Hòa, Q. Tân Bình, TP.HCM. Thành lập 1954 (trước là Trung Tiểu học Tân Sơn Hòa – Gia Định), mang tên Ngô Sĩ Liên từ 1989, diện tích ~3.900 m², thuộc UBND P. Tân Sơn Hòa.

> *Ghi chú pháp lý: nếu phát hành rộng, cân nhắc đổi tên trường thành tên hư cấu gần nghĩa (VD "THCS Nguyễn Du"). Quyết định này chưa chốt.*

| # | Địa điểm | Chức năng |
|---|---|---|
| 1 | **Cổng trường** | Tan học 11:30 & tan chiều — ra về, gặp thầy cô/bạn hỏi sửa máy, nhận máy ngay ở cổng |
| 2 | **Sân trường** | Cảnh đời thường: chơi, trò chuyện, giữa giờ |
| 3 | **Lớp học / hành lang** | Cảnh học, giáo viên tới nhờ sửa máy cho phòng tin học |
| 4 | **Thư viện trường** | Đọc sách → tích tri thức |
| 5 | **Quán cà phê** | 11:30–13:45: mang máy tới, làm project + ăn trưa |
| 6 | **Nhà – bàn học (xưởng)** | Xưởng sửa máy chính; tối làm project |
| 7 | **Đường phố Tân Bình** | Cảnh chuyển cảnh theo nhịp giờ |

**Asset 3D:** làm **low-poly stylised** (khối đơn giản, đúng tỉ lệ chibi) — hợp nhân vật chibi, dựng nhanh. Không model chi tiết.

Nhân vật chính: `chibi-model/chibi.obj` (đã có), Z-up, quay mặt về −Y.

---

## 4. Lịch tuần & khung giờ

### 4.1 Ngày thường — T2, T4, T5, T6, T7

| Khung giờ | Việc | Vị trí |
|---|---|---|
| 07:00–11:30 | Đi học | Trường |
| **11:30–13:45** | **Tự chọn 1 trong 2:** đọc sách ở thư viện **HOẶC** project + ăn trưa ở quán cà phê | Thư viện / Quán cà phê |
| 13:45–17:00 | Đi học chiều | Trường |
| **17:00–19:00** | **Ca sửa máy** — nhận & sửa đơn của khách | Nhà – bàn học |
| 19:00–22:00 | Làm project | Nhà |

### 4.2 Thứ 3

Học cả ngày → **bỏ hẳn ca 17:00–19:00, không nhận đơn**. Khung 11:30–13:45 vẫn tự chọn, tối vẫn project.

**17:00–19:00 ngày thường (không có ca sửa):** khung **tự do ở nhà** — được chọn 1 việc: *làm project sớm · đọc sách ở nhà (sách đã mua) · dọn kho linh kiện · nghỉ ngơi*.

### 4.3 Chủ nhật

| Loại | Việc |
|---|---|
| **CN thường** | Nghỉ học → **ca sửa máy 09:00–19:00, chia 2 ca**: 09:00–12:00 và 13:30–19:00. 12:00–13:30 nghỉ trưa. Tối vẫn project |
| **Ngày lễ** (30/4, 2/9, Tết…) | **Không nhận đơn** — sự kiện đời thường: đi chơi, về quê, sum họp gia đình |

Ngày lễ đánh dấu sẵn trên lịch tuần → người chơi biết trước, sắp xếp đơn cho ngày thường.

### 4.4 Cơ chế

- Lịch tuần **khoá/khởi tạo sẵn** — người chơi không chọn được lịch.
- **Khung "ca sửa máy" là khung mở**: tới giờ thì nhận được đơn. Nếu **không nhận đơn nào**, khung đó được dùng cho việc khác (đọc sách ở nhà, làm project, nghỉ).
- Còn lại (đọc sách / project / tự do) người chơi tự chọn trong khung được phép.
- Hết 22:00 → tổng kết ngày → sang ngày kế.

---

## 5. Danh mục máy, lỗi & khách

### 5.1 Khách archetypes

| Khách | Áp lực | Tone gây hại | Phần thưởng |
|---|---|---|---|
| **Bạn học cần máy học bài** | Deadline gấp — nhanh mới được | Khô → mất ngay | Tip nếu giao sớm |
| **Giáo viên / phòng tin học** | Stakes cao, ảnh hưởng cả lớp | Khó tính → họ chấp được nhưng chấm điểm khắt | Uy tín lớn |
| **Người hoài niệm** | Thấp, nhưng giữ kỷ niệm | Dễ giận — máy của họ là kỷ niệm | Kể chuyện, khách trung thành, dễ giới thiệu |

### 5.2 Danh mục máy

| Thời đại | Máy | Linh kiện riêng biệt |
|---|---|---|
| **Hiện đại** | Laptop học sinh, PC phòng tin học | SSD, RAM DDR3/4, pin Li-ion, cáp eDP |
| **Cổ — giữ kỷ niệm** | MacBook polycarbonate 200x, PowerBook G4, iBook, ThinkPad T/X, Dell Inspiron, HP Pavilion | Đèn nền **inverter/CCFL**, ổ **PATA**, bàn phím cơ riêng, pin phồng, nguồn MagSafe 1, cáp ribbon |

### 5.3 Danh mục lỗi

Không lên nguồn · màn hình mờ/tối (inverter) · quá nhiệt do bụi · chậm do ổ cứng · liệt bàn phím · pin phồng · mất WiFi · lỏng cổng/cáp · bo mạch chập. Mỗi máy → 1 lỗi xác định.

### 5.4 Hai loại đơn

| Loại | Việc làm |
|---|---|
| **A. Sửa chữa** | Máy hỏng → chẩn đoán → thay linh kiện → chạy thử |
| **B. Nâng cấp / tư vấn** | Máy còn chạy, khách muốn nâng → **tư vấn linh kiện** → lắp |

### 5.5 Hệ thống tư vấn linh kiện

Bảng linh kiện có thông số thật: *dung lượng · thế hệ · hàng mới / hàng cũ · giá · tương thích*. Khách hỏi, người chơi khuyên:

| Cách khuyên | Hệ quả |
|---|---|
| Đúng túi tiền + đúng nhu cầu + tương thích | Khách chốt → tiền + uy tín |
| Nói quá tay (upsell) | Khách mua rồi nhưng thấy hối → mất uy tín (nhất là người hoài niệm) |
| Tư vấn sai / không tương thích | Máy không nhận, khách quay lại khiếu nại → mất uy tín + làm lại |
| Hàng cũ rẻ (VD SSD 256GB Intel hàng cũ) | Tiền ít, **rủi ro bảo hành** — tỉ lệ khách quay lại; làm tốt → họ tin mình hẳn |

Một số khách **đã tự chọn sẵn linh kiện** → chỉ việc lắp, không cần tư vấn. Người hoài niệm thường là kiểu này.

### 5.6 Data-driven

Mỗi máy = 1 `Resource` (.tres): `{thời đại, model, linh kiện, lỗi, độ khó, giá, loại khách}` → thêm máy mới không cần sửa code.

---

## 6. Đọc sách, project & kinh tế

### 6.1 Đọc sách → tri thức

- Sách theo chủ đề: *điện tử cơ bản · sửa chữa phần cứng · lập trình · kinh doanh nhỏ*.
- Đọc xong tích **tri thức** → mở khoá: hiểu **triệu chứng phức tạp** (máy cổ), mini-game khó hơn, **đối thoại chuyên sâu** với khách rành.

### 6.2 Project — hệ thống riêng

- Chọn **đề tài** (làm game nhỏ, app, robot, web…) → chia **mốc** → mỗi buổi tối/cà phê làm 1 mốc.
- Hoàn thành → **uy tín + giới thiệu khách mới** (khách tới vì nghe nói mình làm được project).

### 6.3 Kinh tế

| | |
|---|---|
| **Thu** | Tiền công theo độ khó & thời đại máy + **tip** (giao sớm, tư vấn đúng) |
| **Chi** | Linh kiện, nâng cấp dụng cụ (máy hàn, đèn soi, ổ cắm), mua sách |
| **Giai đoạn đầu** | Tiền rất hẹp — mua linh kiện là quyết định thật sự |

Không có vay nợ. Giữ đơn giản.

---

## 7. Tiến trình & mục tiêu dài

| Hệ thống | Mở khoá bằng |
|---|---|
| Máy cổ, lỗi phức tạp | **Tri thức** (đọc sách) |
| Khách lớn (giáo viên, phòng tin học) | **Uy tín** |
| Dụng cụ tốt hơn | **Tiền** |
| Quy mô chỗ làm (bàn học → phòng → tiệm) | **Tiền + Uy tín** |
| Khách mới do giới thiệu | **Hoàn thành project** |

**Cung truyện:**

- **Mở đầu:** chỉ có bàn học, tua vít + đèn bàn, **50.000đ** (xem 1.1) — mua được 1–2 linh kiện cơ bản, mới có bạn học tới nhờ.
- **Giữa:** đủ tiền mua máy hàn → mở khoá máy cổ (cần tri thức) → thầy cô, phòng tin học để ý → người hoài niệm tìm tới.
- **Cuối:** chỗ làm lớn hơn, tiệm riêng, đơn dày đặc.

Người chơi **không bị ép tiến** — chậm mà chắc vẫn chơi được; nhưng tiền hẹp nên bỏ lỡ cơ hội là mất thật.

---

## 8. Ghi chú kỹ thuật

| Hạng mục | Quyết định |
|---|---|
| Engine | **Godot 4** (chưa cài trên máy — cần cài trước khi code) |
| Ngôn ngữ | GDScript |
| Nhân vật | Import `chibi-model/chibi.obj` + `chibi.mtl`, Z-up, mặt về −Y |
| Asset môi trường | Low-poly stylised, dựng bằng primitive trong Godot hoặc Blender |
| Dữ liệu game | Godot `Resource` (.tres) cho máy / linh kiện / khách / sách / đề tài |
| State | Autoload `GameState`: state machine `SCHEDULE → REPAIR → MINIGAME → SUMMARIZE` |
| Thời gian | `SCHEDULE` tuần được định nghĩa sẵn trong Resource, sinh ngày hiện tại từ đó |

**Phân phase triển khai** sẽ do bước lập kế hoạch (writing-plans) quyết định — không chốt trong design doc này.

---

## 9. Câu hỏi còn mở

| # | Câu hỏi | Ảnh hưởng |
|---|---|---|
| 1 | Dùng tên trường thật **THCS Ngô Sĩ Liên** hay đổi thành tên hư cấu khi phát hành? | Nội dung, pháp lý khi phát hành |
