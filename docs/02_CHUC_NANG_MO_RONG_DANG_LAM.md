# DANH SÁCH CHỨC NĂNG MỞ RỘNG ĐÁNG LÀM (EXTENDED FEATURES)
**Đề tài:** Ứng dụng hỗ trợ nhà hàng, quán cà phê quản lý việc order, tính tiền và phục vụ.
**Mục đích:** Vượt trên các yêu cầu cơ bản, đạt điểm tối đa (10/10) và điểm cộng tuyệt đối bằng các nghiệp vụ thực tế của mô hình F&B (Food & Beverage).

---

## I. TỔNG QUAN CÁC CHỨC NĂNG MỞ RỘNG THEO NGHIỆP VỤ F&B

Dưới đây là các tính năng mở rộng có giá trị thực tiễn cao nhất trong hệ thống quản lý nhà hàng/quán cafe, được thiết kế để giải trình quy đổi điểm tương đương hoặc tối ưu trải nghiệm:

| STT | Tên tính năng mở rộng | Mô tả nghiệp vụ | Giá trị quy đổi / Điểm cộng | Mức độ ưu tiên |
| :---: | :--- | :--- | :--- | :---: |
| **1** | **Quản lý Sơ đồ Bàn & Khu vực (Floor & Table Management)** | Cho phép tạo khu vực (Tầng 1, Tầng 2, Sân vườn, VIP). Mỗi bàn hiển thị trạng thái thời gian thực: *Bàn trống (Xanh)*, *Có khách (Đỏ)*, *Đang chờ món (Cam)*. | Quy đổi điểm tương đương Nhóm Quản trị nâng cao (+1.0 đ) | **Rất cao (Must have)** |
| **2** | **Chuyển bàn, Gộp bàn, Tách bàn (Table Splitting & Merging)** | Khách đổi chỗ hoặc nhóm bạn đi đông muốn ghép 2 bàn lại thành 1 hóa đơn, hoặc thanh toán riêng từng phần. Hệ thống tự động chuyển các món trong order sang bàn mới. | Tính năng nghiệp vụ thực tế F&B (+0.5 đ) | **Cao** |
| **3** | **Màn hình Bếp / Pha chế (Kitchen Display System - KDS)** | Giao diện riêng cho Bếp/Bar. Khi nhân viên bấm Order trên app, màn hình KDS tự động cập nhật món cần làm. Đầu bếp bấm *"Bắt đầu làm"* -> *"Đã nấu xong/Chờ phục vụ"*. | Điểm cộng Trạng thái đơn hàng thời gian thực (+0.75 đ) | **Rất cao (Must have)** |
| **4** | **In Hóa đơn & Xuất phiếu (Thermal Printer / ESC-POS / PDF)** | Xuất hóa đơn tạm tính cho khách kiểm tra trước khi thanh toán, và xuất hóa đơn VAT / hóa đơn thanh toán cuối cùng. Hỗ trợ in qua máy in nhiệt Bluetooth 58mm/80mm hoặc xuất file PDF đẹp mắt. | Điểm cộng Chức năng in ấn / Hóa đơn (+0.5 đ) | **Cao** |
| **5** | **Đồng bộ Ngoại tuyến (Offline-First SQLite Cache & Sync)** | Khi nhà hàng bị đứt cáp quang hoặc wifi chập chờn, app vẫn lưu order vào SQLite cục bộ. Khi có kết nối trở lại, app tự động đồng bộ lên SQL Server thông qua Background Queue. | Hiện thực hóa yêu cầu SQLite trên điện thoại (+1.0 đ) | **Rất cao (Must have)** |
| **6** | **Tùy chọn Món ăn (Topping, Size, Đường/Đá/Ghi chú món)** | Đặc thù quán trà sữa/cà phê: Size M/L, 50% đường, không đá, thêm trân châu, trân châu trắng (+10k). Mỗi chi tiết món đều có phụ thu và ghi chú riêng gửi đến bếp. | Mở rộng Quản lý Giỏ hàng & Chi tiết Order (+0.5 đ) | **Cao** |
| **7** | **Quản lý Ca làm việc & Chốt ca (Shift & Cash Register)** | Mở ca: nhập số tiền lẻ đầu ca (tiền float). Đóng ca: đối soát doanh thu tiền mặt, chuyển khoản VNPay/VietQR, kiểm tra lệch tiền và in báo cáo chốt ca (Z-Report). | Quản lý bán hàng chuyên nghiệp (+0.5 đ) | **Trung bình** |
| **8** | **Khuyến mãi, Voucher & Khách hàng thân thiết (Loyalty & Discounts)** | Áp dụng mã giảm giá (% hoặc số tiền), tích điểm thành viên theo số điện thoại (100.000đ = 10 điểm, quy đổi trừ tiền đơn sau). | Mở rộng Quản lý Member & Checkout (+0.5 đ) | **Trung bình** |

---

## II. CHI TIẾT ĐẶC TẢ KỸ THUẬT CÁC TÍNH NĂNG ĐÁNG LÀM

### 1. Quản lý Sơ đồ Bàn & Khu vực (Floor & Table Map)
- **Frontend (Flutter):**
  - Widget hiển thị danh sách khu vực bằng Tabs / SegmentedControl.
  - Hiển thị danh sách bàn dạng GridView linh hoạt. Thẻ bàn (Table Card) hiển thị: Tên bàn (Bàn 01), Số ghế (4 chỗ), Thời gian ngồi (ví dụ: đã ngồi 45 phút), Tổng tiền hiện tại, Badge trạng thái màu sắc.
  - Khi chạm vào bàn:
    - Nếu bàn trống $\rightarrow$ Mở menu để nhân viên bắt đầu order cho khách.
    - Nếu bàn có khách $\rightarrow$ Mở chi tiết order hiện tại (thêm món, in tạm tính, chuyển bàn, thanh toán).
- **Backend (.NET 10 API):**
  - `AreaController`, `TableController`.
  - API: `GET /api/table/by-area/{areaId}`, `PUT /api/table/{id}/status`, `POST /api/table/transfer`.
- **Database (SQL Server):**
  - Bảng `Areas` (AreaId, AreaName, Description, SortOrder).
  - Bảng `DiningTables` (TableId, AreaId, TableName, Capacity, Status: 0=Empty, 1=Occupied, 2=Reserved).

---

### 2. Màn hình Bếp / Pha chế (Kitchen Display System - KDS)
- **Vấn đề thực tế:** Nhân viên ghi order bằng giấy thường bị thất lạc, bếp nấu sai thứ tự hoặc không biết món nào cần ưu tiên.
- **Giải pháp:** Màn hình KDS chạy trên máy tính bảng trong bếp hoặc giao diện web tablet.
- **Frontend (Flutter):**
  - Màn hình chia làm các cột: **Chờ chế biến (Pending)** $\rightarrow$ **Đang làm (Cooking)** $\rightarrow$ **Đã xong (Ready to serve)**.
  - Mỗi thẻ món (OrderItem Card) có đồng hồ đếm giờ (Timer) chuyển từ màu xanh $\rightarrow$ vàng $\rightarrow$ đỏ nếu chờ quá 15 phút.
  - Nút bấm 1 chạm: Bếp trưởng bấm để chuyển trạng thái món.
- **Backend (.NET 10 API):**
  - `KdsController`: `GET /api/kds/active-orders`, `PUT /api/kds/order-detail/{id}/status`.
  - Trạng thái OrderDetail: `0=New`, `1=Cooking`, `2=Ready`, `3=Served`.

---

### 3. Tùy chọn Món ăn & Topping (Modifiers & Attributes)
- **Vấn đề thực tế:** Quán cafe/trà sữa không thể chỉ bán "Trà đào", mà phải chọn size (Nhỏ, Vừa, Lớn), mức đường (30%, 50%, 100%), đá, topping.
- **Database (SQL Server):**
  - Bảng `ProductAttributes` (Id, ProductId, Name, ExtraPrice, IsRequired).
  - Bảng `OrderDetailModifiers` (Id, OrderDetailId, ModifierName, ExtraPrice).
- **Frontend (Flutter):**
  - Khi bấm vào món ăn, hiện BottomSheet chọn Size, Topping và nhập Ghi chú riêng cho đầu bếp ("ít cay", "không hành").

---

### 4. In Hóa đơn Nhiệt & Xuất PDF (Thermal Bill Printing)
- **Công nghệ:** Sử dụng chuẩn mã lệnh ESC/POS hoặc thư viện tạo file PDF (`pdf` package) để xem trước hóa đơn thanh toán trên điện thoại.
- **Nội dung hóa đơn chuyên nghiệp:**
  - Tên nhà hàng, địa chỉ, số điện thoại, wifi.
  - Số hóa đơn, Tên nhân viên phục vụ, Số bàn, Giờ vào / Giờ in.
  - Bảng danh sách món: Tên món, Đơn giá, Số lượng, Thành tiền.
  - Giảm giá / Khuyến mãi, Thuế VAT (nếu có).
  - Tổng tiền thanh toán (bằng số và bằng chữ).
  - Mã QR thanh toán VietQR động để khách quét mã trả tiền ngay tại bàn.
  - Lời cảm ơn và hẹn gặp lại.

---

### 5. Cơ chế Đồng bộ Ngoại tuyến SQLite First (Offline-First Sync Engine)
- **Tại sao cần:** Đáp ứng chuẩn 100% yêu cầu cứng: *"Sử dụng database SQLite để lưu trữ trên điện thoại"*.
- **Cách hoạt động:**
  1. Khi mở app, danh mục món và sản phẩm từ SQL Server được nạp vào SQLite cục bộ để đọc cực nhanh không cần chờ mạng.
  2. Giỏ hàng tạm thời được lưu trong bảng SQLite `LocalCart` và `LocalCartDetail`. Tắt app mở lại không bao giờ bị mất giỏ hàng.
  3. Nếu mất kết nối mạng khi tạo Order: App lưu đơn vào bảng SQLite `PendingSyncOrders` với cờ `is_synced = 0`.
  4. Một service chạy ngầm (hoặc kiểm tra khi có mạng lại) sẽ đọc các đơn chưa đồng bộ và gửi lần lượt lên `POST /api/order`, cập nhật `is_synced = 1`.
