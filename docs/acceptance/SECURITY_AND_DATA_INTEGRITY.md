# BÁO CÁO BẢO MẬT & TOÀN VẸN DỮ LIỆU (SECURITY & DATA INTEGRITY)
## HỆ THỐNG RESTAURANT POS SYSTEM (ASP.NET CORE 10 + SQL SERVER)

---

## 1. RÀNG BUỘC TOÀN VẸN DỮ LIỆU CSDL (DATABASE INTEGRITY)

### 1.1. Khóa chính, Khóa ngoại & Chỉ mục
- **Toàn vẹn khóa chính (Primary Keys):** Định nghĩa đầy đủ trên toàn bộ 10 bảng trong `RestaurantPosDb.sql`.
- **Ràng buộc khóa ngoại (Foreign Keys):** 9 mối quan hệ được kiểm tra và kích hoạt nghiêm ngặt:
  - `FK_Accounts_Roles`: Liên kết tài khoản với vai trò quyền hạn.
  - `FK_Orders_Accounts`: Ghi nhận nhân viên phục vụ / khách hàng lập đơn.
  - `FK_Tables_Areas`: Phân chia bàn theo khu vực mặt bằng.
  - `FK_Orders_Tables`: Ràng buộc đơn hàng tại bàn.
  - `FK_Products_Categories`: Phân loại món ăn theo danh mục.
  - `FK_Attributes_Products`: Nhóm tùy chọn bổ sung của món ăn.
  - `FK_OrderDetails_Products`: Chi tiết món trong từng đơn.
  - `FK_OrderDetails_Orders`: Chi tiết hóa đơn thuộc về đơn hàng.
  - `FK_Payments_Orders`: Giao dịch thanh toán thuộc về đơn hàng.

### 1.2. Kiểm thử Hành vi Xóa theo tầng (Cascade vs Restrict Deletes)
- **Hành vi Xóa theo tầng (CASCADE - An toàn):**
  - Xóa `Orders` $\rightarrow$ Tự động dọn dẹp các dòng chi tiết trong `OrderDetails` (Đã kiểm chứng: Trước xóa 2 chi tiết, sau xóa 0 chi tiết).
  - Xóa `Products` $\rightarrow$ Tự động dọn dẹp các tùy chọn `ProductAttributes`.
- **Hành vi Chặn xóa (RESTRICT - Bảo vệ lịch sử tài chính & an toàn dữ liệu):**
  - Chặn xóa `Orders` khi đã có bản ghi `Payments` liên quan (SQL Error 547).
  - Chặn xóa `Categories` khi còn sản phẩm thuộc danh mục (SQL Error 547 / API HTTP 400).
  - Chặn xóa `Roles` khi còn tài khoản người dùng đang gắn vai trò (SQL Error 547).
  - Chặn xóa `Products` khi đã phát sinh trong các đơn hàng lịch sử (API HTTP 400).

### 1.3. Ràng buộc Tính duy nhất (Unique Constraints) & Chống tấn công trùng lặp
- `Accounts.Username`: Chặn đứng các nỗ lực chèn trùng lặp tên đăng nhập (SQL Error 2627/2601).
- `Roles.RoleCode`: Chặn trùng lặp mã quyền hệ thống.
- `Orders.OrderCode`: Bảo đảm mỗi đơn hàng có mã số định danh tài chính duy nhất (`UQ__Orders__OrderCode`).

---

## 2. KIẾN TRÚC BẢO MẬT XÁC THỰC & MẬT KHẨU (AUTHENTICATION SECURITY)

### 2.1. Cấu trúc Băm Mật khẩu Mới (`PasswordHasher.cs`)
- **Thuật toán:** SHA-256 kết hợp chuỗi Muối ngẫu nhiên (Cryptographic Random Salt 16 bytes = 32 hex chars).
- **Định dạng lưu trữ:** `{salt:32}:{hash:64}` (Tổng cộng 97 ký tự).
- **Đặc tính an toàn:**
  - Hai người dùng cùng đặt mật khẩu giống nhau sẽ có chuỗi băm hoàn toàn khác biệt trong CSDL do Salt là ngẫu nhiên và duy nhất.
  - Vô hiệu hóa hoàn toàn hình thức tấn công bằng từ điển (Dictionary Attack) và bảng cầu vồng (Rainbow Table).
- **Tương thích ngược:** Tự động nhận diện chuỗi SHA-256 thô 64 ký tự từ dữ liệu nạp ban đầu của đồ án, cho phép toàn bộ tài khoản mẫu (`admin`, `manager01`, `waiter_nam`, v.v.) đăng nhập trơn tru mà không cần migrate thủ công.

### 2.2. Phát hiện & Khắc phục Lỗ hổng P0 (Mass Assignment Privilege Escalation)
- **Mô tả lỗ hổng phát hiện:**
  - Trong kịch bản kiểm thử đối kháng `scripts/challenge_r3_rbac.py` (Vector E), kiểm thử viên đã giả lập một người dùng công khai gửi request `POST /api/auth/register` với payload chứa `"roleCode": "ADMIN"` hoặc `"roleId": 1`.
  - Ban đầu, hàm `RegisterAsync` chấp nhận tham số này, dẫn đến tài khoản kẻ tấn công được cấp quyền `ADMIN` và có thể truy cập trái phép danh sách thành viên (`/api/account/members`).
- **Biện pháp khắc phục triệt để:**
  - Chỉnh sửa `backend/Models/AccountRepository.cs` dòng 31-36: Cố định 100% các request đăng ký công khai chỉ được gán vai trò `MEMBER`.
  - Tham số `roleCode` hoặc `roleId` do client gửi lên bị bỏ qua hoàn toàn.
- **Tái kiểm thử xác nhận:**
  - Kẻ tấn công gửi `roleCode: "ADMIN"` $\rightarrow$ Tài khoản tạo thành công nhưng gán vai trò `MEMBER`.
  - Đăng nhập lấy token $\rightarrow$ Cố tình gọi API quản trị `/api/account/members` $\rightarrow$ Server từ chối dứt khoát với mã lỗi **HTTP 403 Forbidden**. Lỗ hổng đã được bẻ gãy 100%.

---

## 3. BẢO MẬT JWT TOKEN & PHÂN QUYỀN RBAC (AUTHORIZATION)

Toàn bộ 12 ca kiểm thử tấn công giả mạo token trong `scripts/challenge_r3_rbac.py` (Vector A) đều bị chặn đứng:

1. Request không mang Header Authorization $\rightarrow$ **HTTP 401 Unauthorized**.
2. Header Bearer rỗng hoặc chuỗi ký tự rác $\rightarrow$ **HTTP 401 Unauthorized**.
3. Sử dụng sơ đồ Basic Auth $\rightarrow$ **HTTP 401 Unauthorized**.
4. Token bị cắt ngắn hoặc thiếu phần Payload/Signature $\rightarrow$ **HTTP 401 Unauthorized**.
5. Token được ký bởi khóa bí mật giả mạo của kẻ tấn công $\rightarrow$ **HTTP 401 Unauthorized**.
6. Token sử dụng thuật toán `alg: "none"` $\rightarrow$ **HTTP 401 Unauthorized**.
7. Token đã hết hạn (`exp` trong quá khứ) $\rightarrow$ **HTTP 401 Unauthorized**.
8. Giữ nguyên chữ ký nhưng sửa đổi nội dung Payload $\rightarrow$ **HTTP 401 Unauthorized**.
9. Token có Issuer hoặc Audience không khớp cấu hình $\rightarrow$ **HTTP 401 Unauthorized**.
10. Giả mạo Header HTTP `X-Role: ADMIN` từ tài khoản phục vụ $\rightarrow$ Server dựa trên Claims của JWT chứ không tin cậy Header tùy biến $\rightarrow$ **HTTP 403 Forbidden**.

---

## 4. BẢO MẬT CỔNG THANH TOÁN (PAYMENT GATEWAYS)

### 4.1. Thanh toán VietQR
- Đường dẫn mã QR động được sinh từ dữ liệu chính xác của đơn hàng.
- **Nguyên tắc an toàn:** Hệ thống không bao giờ tự động cập nhật trạng thái đã thanh toán chỉ vì khách hàng đã bấm xem mã QR. Giao dịch bắt buộc phải có sự xác nhận của thu ngân hoặc webhook từ ngân hàng.

### 4.2. Cổng thanh toán VNPay Sandbox
- Mã hóa dữ liệu truyền tải theo tiêu chuẩn của VNPay bằng mã băm HMAC-SHA512.
- **Chặn Callback giả mạo:** Endpoint `/api/payment/vnpay/callback` kiểm tra và tái tính toán chữ ký HMAC-SHA512 trên toàn bộ query parameters. Nếu chữ ký không khớp, request bị hủy ngay lập tức với mã lỗi HTTP 400.
- **Xử lý Idempotent:** Khi nhận nhiều callback trùng lặp cho cùng một giao dịch, hệ thống chỉ cập nhật đơn hàng đúng một lần, tránh nhân đôi doanh thu.

---

## 5. BẢO MẬT TẢI LÊN FILE HÌNH ẢNH (IMAGE UPLOAD DEFENSE)

Được áp dụng tập trung tại `backend/Services/Helper.cs`:
- **Kiểm tra phần mở rộng (Whitelisting):** Chỉ cho phép `.jpg, .jpeg, .png, .webp, .gif`. Mọi file thực thi (`.exe, .bat, .dll, .php, .sh`) đều bị chặn đứng với mã lỗi HTTP 400.
- **Giới hạn dung lượng:** Tối đa 5MB/file, ngăn chặn các cuộc tấn công làm tràn đĩa cứng (Disk Exhaustion DoS).
- **Đặt tên file ngẫu nhiên:** Sử dụng chuỗi ngẫu nhiên 16 ký tự an toàn (`RandomString(16)`), vô hiệu hóa hoàn toàn nguy cơ tấn công Path Traversal hoặc ghi đè file hệ thống.
- **Dọn dẹp file rác:** Khi cập nhật ảnh mới hoặc xóa danh mục/sản phẩm, file ảnh cũ trong `wwwroot` được xóa bỏ hoàn toàn.
