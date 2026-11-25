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

### Phút 0:00 – 0:50 | Vai trò `Guest / Member` — Thực đơn, Giỏ hàng Variant & Bảo mật Route
1. Mở app ở trạng thái **Chưa đăng nhập (Guest)**:
   - Cho thầy thấy thanh Navigation chỉ hiện 5 tab khách hàng (`Thực đơn`, `Danh mục`, `Giỏ hàng`, `Hội viên`, `Đăng nhập`) — **không lộ tab Thu ngân / Bếp / Admin**.
   - Lọc theo danh mục + tìm kiếm món → vào chi tiết 1 món (ví dụ *Bạc xỉu* hoặc *Trà đào*) chọn **Size/Topping + Ghi chú** → thêm 2 biến thể khác nhau để chứng minh giỏ hàng tách dòng độc lập.
2. **Mẹo ghi điểm bảo mật:** Thử gõ URL `#/admin/users` (trên Web) để thầy thấy màn hình chặn **Không đủ thẩm quyền (403)**.
3. Đăng nhập thử bằng **`member_khang`** / **`admin`**: vào tab **Hội viên** chỉ điểm tích lũy thật `1.250 PTS` và danh sách voucher. Sau đó vào **Tài khoản** → **Đăng xuất**.

### Phút 0:50 – 2:00 | Vai trò `Waiter` (`waiter_nam` / `admin`) — Sơ đồ bàn & Đặt món
1. Đăng nhập **`waiter_nam`**: giao diện tự đổi thành `Sơ đồ bàn`, `Thực đơn`, `Giỏ hàng`, `Đồng bộ`, `Tài khoản`.
2. Trên **Sơ đồ bàn ăn** (10 bàn theo 7 khu vực tầng):
   - Nhấn chọn 1 bàn trống (ví dụ **Bàn T1-02**) → **Mở bàn / Đặt món**, chọn 2 món → Xác nhận đặt món (`IdempotencyKey` tự gắn).
   - Quay lại sơ đồ bàn thấy **Bàn T1-02 chuyển ngay sang màu đỏ `CÓ KHÁCH` kèm mã đơn & tổng tiền**.
   - Nếu muốn, bấm giữ/chọn menu bàn để minh họa tính năng **Gọi thêm món** hoặc **Chuyển bàn**.

### Phút 2:00 – 3:00 | Vai trò `Chef / KDS` (`chef_dung` / `admin`) — Bếp & Báo hết món
1. Vào tab `Tài khoản` → Đăng xuất → Đăng nhập **`chef_dung`**.
2. Giao diện chuyển ngay sang **Màn hình tối Bếp & Pha chế (KDS)**:
   - Chỉ ngay ticket của bàn vừa đặt ở trên.
   - Bấm **`Bắt đầu làm`** (`Chờ nấu → Đang làm`) rồi bấm **`Xong món`** (`Đã xong`).
   - Bấm nút **Báo hết món 1-chạm** trên thanh AppBar (hoặc icon **Gom món Batch Prep**) để thầy thấy khả năng hỗ trợ bếp giờ cao điểm.

### Phút 3:00 – 4:15 | Vai trò `Cashier` (`cashier_mai` / `admin`) — Ca làm, POS & Thanh toán
1. Đăng xuất → Đăng nhập **`cashier_mai`**.
2. Vào tab **`Ca làm`**: bấm **Mở ca làm việc**, nhập tiền lẻ đầu ca (ví dụ `500.000đ`).
3. Chuyển qua tab **`Thu ngân`**:
   - Nếu đang dùng màn hình lớn / Chrome Desktop, nhấn mạnh giao diện **Split-Screen POS 2 nửa** chuyên nghiệp như máy POS ngoài tiệm.
   - Chọn bàn đang có khách → bấm **`+ Thêm CK`** áp chiết khấu 10% → bấm **`THANH TOÁN`** chọn **VietQR** để hiện QR chuyển khoản động NAPAS (hoặc **Tiền mặt** / **VNPay Sandbox**), xác nhận thu tiền → **In/Xem trước hóa đơn**.
4. Quay lại **`Ca làm`** → bấm **Đóng ca** xem **Báo cáo Z-Report** đối soát tiền mặt khớp két 100%.

### Phút 4:15 – 5:00 | Vai trò `Admin` (`admin` / `admin`) — Quản trị tổng thể & Chốt
1. Đăng nhập **`admin`** → mở tab **`Quản trị`** (`_OperationsHubPage`).
2. Vào **`Đơn hàng`**: chỉ KPI tổng doanh thu, bộ lọc ngày/trạng thái và **Top món bán chạy** từ SQL Server.
3. Mở nhanh **`Quản trị Sản phẩm`** (có multi-image upload) và **`Quản trị Nhân sự (RBAC)`** (phân quyền, khóa/mở tài khoản) rồi kết thúc mượt mà.

---

## Xử lý sự cố nhanh nếu mạng phòng thi trục trặc
- **Nếu Wi-Fi phòng hội đồng chậm khi mở VNPay / VietQR ngoài internet**: Phần Thanh toán tiền mặt, Chiết khấu, Mở/Đóng ca Z-Report và **Hàng đợi Offline (`Đồng bộ`)** vẫn chạy hoàn toàn trên localhost + SQL Server không phụ thuộc Internet! Bạn thậm chí có thể tắt Wi-Fi 15 giây để biến nó thành màn demo **Offline-First Sync** ăn điểm tối đa!
