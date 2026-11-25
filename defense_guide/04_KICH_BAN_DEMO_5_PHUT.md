# 04 — Kịch Bản Demo Trực Tiếp 5 Phút (Dành Cho 1 Người Trình Bày)

> **Chuẩn bị trước khi lên bàn chấm (30 giây):**
> Mở 2 cửa sổ terminal PowerShell sẵn:
> - **Terminal 1 (Backend .NET 10):**
>   ```powershell
>   cd d:\Download\restaurant_pos_app\backend
>   dotnet run --urls http://localhost:5138
>   ```
> - **Terminal 2 (App Flutter Web hoặc Windows Desktop):**
>   ```powershell
>   cd d:\Download\restaurant_pos_app\mobile
>   flutter run -d chrome --web-port 8088
>   # Hoặc mở app Windows Desktop: flutter run -d windows
>   ```

---

## Timeline Demo Chuẩn 5 Phút (Chuyển Vai Mượt Không Vấp)

### Phút 0:00 – 0:50 | Vai trò `Guest (QR Self-Order) / Member` — Thực đơn, Giỏ hàng Variant & Bảo mật Route
1. Mở app ở trạng thái **Chưa đăng nhập (Guest)** hoặc thử quét link QR bàn (`http://localhost:8088/?tableId=2`):
   - Cho thầy thấy thanh Navigation chỉ hiện 5 tab khách hàng (`Thực đơn`, `Danh mục`, `Giỏ hàng`, `Hội viên`, `Đăng nhập`) — **không lộ tab Thu ngân / Bếp / Admin**, và khi mở từ `?tableId=2` sẽ có **banner Bàn #2** cho phép khách tự gửi đơn không cần chờ phục vụ.
   - Lọc theo danh mục + tìm kiếm món → vào chi tiết 1 món (ví dụ *Bạc xỉu* hoặc *Trà đào*) chọn **Size/Topping + Ghi chú** → thêm 2 biến thể khác nhau để chứng minh giỏ hàng tách dòng độc lập.
2. **Mẹo ghi điểm bảo mật:** Thử gõ URL `#/admin/users` (trên Web) để thầy thấy màn hình chặn **Không đủ thẩm quyền (403)**.
3. Đăng nhập thử bằng **`member_khang`** / **`admin`**: vào tab **Hội viên** chỉ điểm tích lũy thật `1.250 PTS` và danh sách voucher. Sau đó vào **Tài khoản** → **Đăng xuất**.

### Phút 0:50 – 2:00 | Vai trò `Waiter` (`waiter_nam` / `admin`) — Sơ đồ bàn, QR bàn & SignalR
1. Đăng nhập **`waiter_nam`**: giao diện tự đổi thành `Sơ đồ bàn`, `Thực đơn`, `Giỏ hàng`, `Đồng bộ`, `Tài khoản` (chỉ trạng thái **Live SignalR**).
2. Trên **Sơ đồ bàn ăn** (10 bàn theo 7 khu vực tầng):
   - Nhấn chọn 1 bàn trống (ví dụ **Bàn T1-02**) → **Mở bàn / Đặt món**, chọn 2 món → Xác nhận đặt món (`IdempotencyKey` tự gắn & tự động trừ tồn kho BOM nguyên liệu).
   - Quay lại sơ đồ bàn thấy **Bàn T1-02 chuyển ngay sang màu đỏ `CÓ KHÁCH` kèm mã đơn & tổng tiền**.
   - Bấm vào bàn để minh họa **Gộp bàn / Tách bàn / Chuyển bàn** hoặc mở **Mã QR gọi món tại bàn**.

### Phút 2:00 – 3:00 | Vai trò `Chef / KDS` (`chef_dung` / `admin`) — Bếp Realtime & Hoàn kho
1. Vào tab `Tài khoản` → Đăng xuất → Đăng nhập **`chef_dung`**.
2. Giao diện chuyển ngay sang **Màn hình tối Bếp & Pha chế (KDS)**:
   - Ticket bàn vừa đặt tự đẩy xuống màn hình qua **SignalR `/hubs/pos`** kèm âm báo.
   - Bấm **`Bắt đầu làm`** (`Chờ nấu → Đang làm`) rồi bấm **`Xong món`** (`Đã xong`).
   - Nhấn mạnh nút **Báo hết món 1-chạm**, **Gom món Batch Prep**, và thao tác **Hủy món (`Void`) tự động hoàn tồn kho BOM (`REFUND`)**.

### Phút 3:00 – 4:15 | Vai trò `Cashier` (`cashier_mai` / `admin`) — Ca làm, POS, Tách/Gộp & In LAN
1. Đăng xuất → Đăng nhập **`cashier_mai`**.
2. Vào tab **`Ca làm`**: bấm **Mở ca làm việc**, nhập tiền lẻ đầu ca (ví dụ `500.000đ`).
3. Chuyển qua tab **`Thu ngân`**:
   - Trên Desktop / Chrome ≥ 900px, chỉ rõ **Split-Screen POS 2 nửa**, nút **`Gộp bàn`** / **`Tách món`** theo từng món, **`+ Thêm CK`** áp chiết khấu.
   - Bấm **`THANH TOÁN`** chọn **VietQR** (hiện QR NAPAS động), **Tiền mặt** hoặc **VNPay Sandbox** → xác nhận thu tiền → Xem trước hóa đơn có cả **In PDF** lẫn **In LAN (ESC/POS 80mm TCP 9100)**.
4. Quay lại **`Ca làm`** → bấm **Đóng ca** xem **Báo cáo Z-Report** đối soát tiền mặt khớp két 100%.

### Phút 4:15 – 5:00 | Vai trò `Admin` (`admin` / `admin`) — Biểu đồ, Kho BOM & Nhân sự
1. Đăng nhập **`admin`** → mở tab **`Quản trị`** (`_OperationsHubPage`).
2. Vào **`Đơn hàng`**: chỉ KPI tổng doanh thu, **biểu đồ doanh thu theo ngày & cơ cấu thanh toán**, Top món bán chạy và nút **Xuất CSV kế toán**.
3. Mở nhanh **`Kho & Định lượng (BOM)`** ([AdminInventoryPage](file:///d:/Download/restaurant_pos_app/mobile/lib/views/admin/admin_inventory_page.dart)) xem cảnh báo nguyên liệu dưới ngưỡng & lịch sử Xuất/Nhập/Hoàn kho; mở **`Quản trị Nhân sự (RBAC)`** rồi chốt mượt mà.

---

## Xử lý sự cố nhanh nếu mạng phòng thi trục trặc
- **Nếu Wi-Fi phòng hội đồng chậm khi mở VNPay / VietQR ngoài internet**: Phần Thanh toán tiền mặt, Chiết khấu, Mở/Đóng ca Z-Report và **Hàng đợi Offline (`Đồng bộ`)** vẫn chạy hoàn toàn trên localhost + SQL Server không phụ thuộc Internet! Bạn thậm chí có thể tắt Wi-Fi 15 giây để biến nó thành màn demo **Offline-First Sync** ăn điểm tối đa!
