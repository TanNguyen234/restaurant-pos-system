# BÁO CÁO NGHIỆM THU ĐỒ ÁN - THÀNH VIÊN 3
## VAI TRÒ: BACKEND & SECURITY SPECIALIST (COLLABORATOR B)

---

## 1. THÔNG TIN THÀNH VIÊN & TRÁCH NHIỆM BAREM
- **Họ và tên:** Thành viên 3 (Collaborator B)
- **MSSV / Vai trò:** Backend & Security Specialist
- **Trọng tâm phụ trách:**
  - Nhóm 1 Barem: Xác thực người dùng (Đăng ký, Đăng nhập băm mật khẩu, Đổi mật khẩu, Quản lý member, Quản lý role, Phân quyền RBAC).
  - Nhóm 5 Barem (Phần Đặt hàng & Thanh toán): API Đặt hàng Transaction, Chi tiết đơn hàng, Thanh toán online VNPay Sandbox và VietQR.
  - Nhóm 6 Barem: Quản lý đơn hàng Admin (Danh sách đơn thời gian thực, Lọc khoảng ngày, Chuyển trạng thái đơn).
  - Tính năng tương đương nâng cao: Màn hình Bếp KDS (Kitchen Display System) cập nhật trạng thái chế biến món ăn thời gian thực.
- **Cam kết điểm barem:** 6.50 điểm (Bao gồm điểm cộng RBAC 6 Role, Cổng thanh toán VNPay Sandbox & VietQR).

---

## 2. MINH CHỨNG THỰC THI THỰC TẾ (REAL EXECUTION EVIDENCE)

### 2.1. Xác thực Tài khoản & Phân quyền Vai trò (RBAC)
- **Mã nguồn Backend:**
  - `backend/Services/PasswordHasher.cs`: Băm mật khẩu sử dụng thuật toán chuẩn SHA-256 kèm chuỗi Salt ngẫu nhiên 32 byte (`{salt}:{hash}`). Hỗ trợ tương thích ngược với mật khẩu hạt giống của đồ án.
  - `backend/Services/JwtTokenService.cs`: Ký và cấp phát JWT Bearer Token chứa Claims vai trò (`RoleCode`, `RoleName`, `AccountId`).
  - `backend/Models/AccountRepository.cs` & `backend/Api/Controllers/AuthController.cs`:
    - Đăng ký tài khoản: Kiểm tra trùng tên đăng nhập (không phân biệt hoa thường) và email.
    - Đăng nhập: Cấp token hợp lệ cho tất cả 6 vai trò: `ADMIN`, `MANAGER`, `CASHIER`, `WAITER`, `KITCHEN`, `MEMBER`.
    - Đổi mật khẩu: Xác minh mật khẩu cũ trước khi đổi, vô hiệu hóa mật khẩu cũ ngay lập tức.
  - `backend/Api/Controllers/AccountController.cs`: Bảo vệ bằng thuộc tính `[Authorize(Roles = "ADMIN,MANAGER")]`.
- **Phát hiện & Khắc phục Lỗ hổng Bảo mật P0 (Mass Assignment Privilege Escalation):**
  - Trong quá trình kiểm thử đối kháng (`scripts/challenge_r3_rbac.py`), đội ngũ an ninh phát hiện API Đăng ký công khai cho phép client truyền `roleCode: "ADMIN"` để tự nâng quyền.
  - **Khắc phục triệt để:** Cố định 100% tài khoản đăng ký công khai chỉ được gán vai trò `MEMBER`. Thử nghiệm lại: Kẻ tấn công truyền `roleCode='ADMIN'` nhưng chỉ nhận vai trò `MEMBER` và bị chặn truy cập quản trị (HTTP 403 Forbidden) $\rightarrow$ **PASS 100%**.
- **Kết quả Kiểm định HTTP RBAC:** **25 / 25 ca kiểm thử PASS 100%** (`scripts/verify_r3_http_rbac.ps1`).

### 2.2. Quy trình Đặt hàng Giao dịch (Order Placement & Transaction)
- **Mã nguồn Backend:**
  - `backend/Models/OrderRepository.cs` & `backend/Api/Controllers/OrderController.cs`.
  - Sử dụng giao dịch cơ sở dữ liệu `BeginTransactionAsync()` bảo đảm tính toàn vẹn tuyệt đối:
    1. Kiểm tra bàn ăn: Nếu bàn đã có khách và đơn chưa hoàn thành $\rightarrow$ Chặn đặt trùng lặp (HTTP 400).
    2. Tính toán tài chính an toàn: Truy vấn đơn giá trực tiếp từ bảng `Products` trong SQL Server, không tin cậy đơn giá do client gửi lên.
    3. Thêm bản ghi `Orders` và các bản ghi chi tiết `OrderDetails`.
    4. Cập nhật trạng thái bàn ăn sang `1` (Occupied) và gán `CurrentOrderId`.
    5. Commit giao dịch an toàn.
- **Kiểm định thực tế:**
  - `ORDER-01`: Bàn 2 trống $\rightarrow$ **PASS**.
  - `ORDER-02`: Đặt món thành công qua `POST /api/order` $\rightarrow$ **PASS**.
  - `ORDER-03`: Bàn 2 tự động chuyển sang trạng thái Occupied (1) $\rightarrow$ **PASS**.
  - `ORDER-04`: Đặt đơn tiếp theo lên Bàn 2 bị từ chối do bàn đang bận $\rightarrow$ **PASS**.

### 2.3. Màn hình Bếp KDS (Kitchen Display System)
- **Mã nguồn Backend:**
  - `backend/Api/Controllers/KdsController.cs`.
  - Cung cấp hàng đợi chế biến món ăn thời gian thực:
    - `GET /api/kds`: Lấy toàn bộ món đang chờ nấu hoặc đang nấu, sắp xếp theo thứ tự ưu tiên.
    - `PUT /api/kds/{orderDetailId}/status`: Chuyển đổi trạng thái (`0: Chờ nấu` $\rightarrow$ `1: Đang nấu` $\rightarrow$ `2: Đã xong`).
    - Tự động ghi nhận thời gian bắt đầu (`StartedCookingAt`) và kết thúc (`FinishedCookingAt`).
    - **Tự động chuyển trạng thái đơn hàng:** Khi toàn bộ món ăn trong đơn hoàn tất chế biến, đơn hàng tự động cập nhật sang trạng thái `2` (Đã phục vụ - Served).
- **Kiểm định thực tế:**
  - `KDS-01`: Món ăn xuất hiện ngay lập tức trong KDS $\rightarrow$ **PASS**.
  - `KDS-02`: Chuyển món sang Đang nấu (1) $\rightarrow$ **PASS**.
  - `KDS-03`: Hoàn tất toàn bộ món $\rightarrow$ Đơn hàng tự động chuyển sang `Served` $\rightarrow$ **PASS**.

### 2.4. Thanh toán Đa kênh: Tiền mặt, VietQR & VNPay Sandbox
- **Thanh toán Tiền mặt tại quầy:**
  - `POST /api/payment/cash`: Ghi nhận thanh toán vào bảng `Payments`, cập nhật `PaymentStatus = 1 (Paid)` và `Status = 3 (Completed)`.
  - Tự động giải phóng bàn ăn về trạng thái trống (`Status = 0`, `CurrentOrderId = NULL`).
  - Chặn thanh toán trùng lặp trên đơn đã thanh toán.
- **Thanh toán VietQR động:**
  - `GET /api/payment/vietqr/{orderId}`: Sinh đường dẫn mã QR động chuẩn Napas 247 chứa mã đơn hàng và số tiền chính xác để khách hàng quét app ngân hàng.
  - Phân định rõ: Tạo mã QR không tự động coi là đã thanh toán mà cần thu ngân xác nhận tiền vào tài khoản.
- **Cổng thanh toán VNPay Sandbox:**
  - `POST /api/payment/vnpay/create-url`: Tạo URL thanh toán VNPay Sandbox có chữ ký HMAC-SHA512.
  - `GET /api/payment/vnpay/callback`: Tiếp nhận kết quả thanh toán từ VNPay, kiểm tra tính toàn vẹn của chữ ký HMAC-SHA512.
  - Chặn đứng 100% các cuộc gọi callback bị giả mạo hoặc sai chữ ký (HTTP 400).
- **Kiểm định thực tế:**
  - `PAY-01` đến `PAY-04`: Xác nhận tiền mặt, hoàn thành đơn, giải phóng bàn và chặn trả trùng $\rightarrow$ **PASS 100%**.
  - `GATEWAY-01` đến `GATEWAY-03`: Tạo VietQR, tạo VNPay Sandbox URL, từ chối chữ ký giả mạo $\rightarrow$ **PASS 100%**.

---

## 3. KẾT QUẢ KIỂM THỬ TỔNG HỢP LIÊN QUAN ĐẾN THÀNH VIÊN 3

| Nhóm chức năng kiểm tra | Bộ kiểm thử thực thi | Số ca kiểm thử | Kết quả |
| :--- | :--- | :---: | :---: |
| Xác thực tài khoản & RBAC 6 Role | `verify_r3_http_rbac.ps1` | 25 / 25 | **PASS 100%** |
| Thử nghiệm đối kháng An ninh & JWT | `challenge_r3_rbac.py` | 64 / 64 | **PASS 100%** |
| Quy trình Đặt hàng & Điều phối Bàn | `verify_e2e_business_flow.ps1` | 4 / 4 | **PASS 100%** |
| Màn hình Bếp KDS thời gian thực | `verify_e2e_business_flow.ps1` | 3 / 3 | **PASS 100%** |
| Thanh toán Tiền mặt, VietQR, VNPay | `verify_e2e_business_flow.ps1` | 7 / 7 | **PASS 100%** |

---

## 4. KẾT LUẬN & ĐỀ NGHỊ ĐÁNH GIÁ
- **Trạng thái nghiệm thu:** **ACCEPTED (ĐẠT XUẤT SẮC)**
- Thành viên 3 đã hoàn thành toàn bộ trách nhiệm phân công, bảo đảm an toàn dữ liệu, chống nâng quyền bất hợp pháp và tích hợp thành công các cổng thanh toán.
