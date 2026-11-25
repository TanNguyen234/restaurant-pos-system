# 01 — Tổng Quan Kiến Trúc & Cơ Sở Dữ Liệu

## 1. Kiến trúc tổng thể 3 tầng (Multi-Platform Client + ASP.NET Core 10 + SQL Server)

![Kiến trúc hệ thống](diagrams/01_system_architecture.png)

### Điểm nhấn kỹ thuật của từng tầng
1. **Presentation Layer (Flutter 3 / Dart — 1 codebase chạy 3 nền tảng):**
   - **Mobile (Android)**: Giao tiếp backend qua `http://10.0.2.2:5138`, lưu offline bằng `SQLite` (`sqflite`).
   - **Web (Chrome)**: Tự động chuyển endpoint về `http://localhost:5138`, lưu phiên & hàng đợi vào `SharedPreferences` (`localStorage`).
   - **Windows Desktop**: Khởi tạo `sqfliteFfiInit()` + `databaseFactoryFfi` trong [database_helper.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/utils/database_helper.dart) để dùng file SQLite cục bộ thực thụ.
   - **Role-Based Adaptive UI**: Thanh điều hướng dưới cùng (`NavigationBar` trong [main.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/main.dart)) và layout màn hình (ví dụ Thu ngân dùng Split-Screen trên Desktop ≥ 900px, Tabbed 2 cột trên Mobile) tự biến đổi theo vai trò & kích thước màn hình, kèm Route Guard (`onGenerateRoute`) chặn truy cập trái phép ngay ở tầng UI.

2. **Application / API Layer (ASP.NET Core 10 Web API):**
   - Tổ chức theo **Provider / Repository Pattern** ([SiteProvider.cs](file:///d:/Download/restaurant_pos_app/backend/Models/SiteProvider.cs) + 8 Repository chuyên biệt) kết hợp **EF Core 10** ([RestaurantPosContext.cs](file:///d:/Download/restaurant_pos_app/backend/Models/RestaurantPosContext.cs)).
   - **Fail-safe & Global Exception Handler**: Toàn bộ exception nội bộ được chặn qua middleware ở [Program.cs](file:///d:/Download/restaurant_pos_app/backend/Program.cs), tuyệt đối không lộ stack trace hay chuỗi kết nối ra client.
   - **11 Controllers RESTful**: tách rõ nghiệp vụ (`Auth`, `Account`, `Category`, `Product`, `Table`, `Order`, `Kds`, `Payment`, `Shift`, `Discount`, `Loyalty`).

3. **Data & Integration Layer:**
   - **SQL Server Express (`RestaurantPos_Acceptance`)**: 15 bảng chuẩn 3NF (`10 Areas`, `10 DiningTables`, `10 Categories`, `34 Products`, `11 Roles`, `11 Accounts`).
   - **Tích hợp dịch vụ thực**: Gmail SMTP (gửi OTP xác thực email & khôi phục mật khẩu), **VietQR NAPAS 247** (`img.vietqr.io`), **VNPay Sandbox** (ký toàn vẹn dữ liệu bằng HMAC-SHA512).

---

## 2. Cơ sở dữ liệu 15 bảng (3NF) & Ràng buộc toàn vẹn

![ERD 15 bảng](diagrams/02_erd_database.png)

### Các quyết định thiết kế DB ăn điểm khi vấn đáp
- **Tách `OrderDetails` + `OrderDetailModifiers`**: Giá món và topping tại thời điểm đặt được snapshot vào `UnitPrice`, `SubTotal`, `ExtraPrice` nên khi Admin sửa giá món trong tương lai, lịch sử hóa đơn cũ không bị sai lệch.
- **Khóa chống trùng đơn `UX_Orders_IdempotencyKey`**: Filtered Unique Index trên `Orders(IdempotencyKey) WHERE IdempotencyKey IS NOT NULL` ngăn chặn triệt để tình trạng double-order do mạng chập chờn hoặc người dùng bấm đúp.
- **Dòng đời trạng thái đa tầng**:
  - `DiningTables.Status`: `0` (Trống) · `1` (Có khách) · `2` (Chờ phục vụ) · `3` (Đã đặt trước).
  - `OrderDetails.CookingStatus`: `0` (Chờ nấu) · `1` (Đang làm) · `2` (Đã xong) · `3` (Đã giao món) · `4` (Đã hủy/Void).
  - `Orders.Status`: `0` (Đơn mới) · `1` (Đang chế biến) · `2` (Đã phục vụ) · `3` (Hoàn thành) · `4` (Đã hủy).
- **Đối soát ca thu ngân (`Shifts` ↔ `Payments`)**: Mỗi giao dịch thanh toán gắn với `ShiftId` đang mở và `ProcessedByAccountId`, cho phép kết xuất báo cáo **Z-Report** đối chiếu tiền mặt kỳ vọng (`InitialCash + TotalSalesCash`) với tiền thực đếm trong két (`ActualCash`).

---

## 3. Luồng bảo mật & Phân quyền RBAC

![Luồng bảo mật Auth](diagrams/05_auth_security_flow.png)

![Ma trận RBAC](diagrams/03_rbac_role_matrix.png)

- **Chống lộ thông tin nhạy cảm**:
  - Endpoint quên mật khẩu / xác thực email gửi OTP thật qua SMTP và lưu hạn 5 phút trong DB — **không trả `devOtp` trong response**.
  - `backend/.env` chứa secret (JWT Key, DB Connection String, SMTP App Password, VNPay HashSecret) bị `.gitignore` chặn hoàn toàn khỏi Git.
- **Chống Account Hijack qua OAuth**: Khi đăng nhập Google/Facebook/Zalo, nếu email đã thuộc tài khoản `ADMIN` hoặc `STAFF`, hệ thống **từ chối nâng quyền qua OAuth** để bảo vệ tài khoản vận hành nội bộ.

---

## 4. Chu trình nghiệp vụ End-to-End (Gọi món → KDS → Thanh toán)

![Luồng nghiệp vụ POS](diagrams/04_end_to_end_pos_sequence.png)
