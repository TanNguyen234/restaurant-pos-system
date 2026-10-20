# ĐẶC TẢ CHI TIẾT LUỒNG HOẠT ĐỘNG TỪNG CHỨC NĂNG
## (FRONTEND FLUTTER - BACKEND .NET 10 - DATABASE SQL SERVER & SQLITE)

Tài liệu này quy định chi tiết mã nguồn, tương tác mạng, logic xử lý dữ liệu và cấu trúc file cho toàn bộ các chức năng thuộc đồ án **Restaurant & Coffee POS**.

---

## 1. NHÓM XÁC THỰC NGƯỜI DÙNG & PHÂN QUYỀN (AUTH & RBAC)

### 1.1. Đăng ký tài khoản (Register)
- **Mục tiêu:** Cho phép khách hàng hoặc nhân viên tạo tài khoản mới.
- **Frontend (Flutter):**
  - Giao diện: `lib/views/auth/register_page.dart`. Form gồm: Họ tên, Tên đăng nhập (Username), Email, Số điện thoại, Mật khẩu, Xác nhận mật khẩu.
  - Xử lý: Validate dữ liệu đầu vào $\rightarrow$ Gọi `AuthRepository.register(RegisterDto dto)`.
  - HTTP Request: `POST http://localhost:5138/api/auth/register`
  - **Mẫu JSON Request:**
    ```json
    {
      "username": "nam.waiter",
      "password": "Password123@",
      "fullName": "Phạm Hoàng Nam",
      "email": "nam.waiter@restaurantpos.vn",
      "phoneNumber": "0904567890"
    }
    ```
  - **Mẫu JSON Response Thành công (200 OK):**
    ```json
    {
      "statusCode": 200,
      "message": "Đăng ký tài khoản thành công",
      "accountId": 4,
      "username": "nam.waiter"
    }
    ```
  - **Mẫu JSON Lỗi Trùng Username/Email (400 Bad Request):**
    ```json
    {
      "statusCode": 400,
      "error": "Tên đăng nhập hoặc email đã được sử dụng trong hệ thống"
    }
    ```
- **Backend (.NET 10 API):**
  - Controller: `AuthController.cs` kế thừa `BaseController`.
  - Service/Repo: `Provider.Account.Register(RegisterDto model)`.
  - Logic: Kiểm tra trùng lặp trong SQL Server $\rightarrow$ Băm mật khẩu (SHA-256 kèm Salt) $\rightarrow$ Gán mặc định `RoleId = 4` (Waiter) hoặc `8` (Member) $\rightarrow$ Lưu vào bảng `Accounts`.

---

### 1.2. Đăng nhập (Login) & Quản lý Phiên làm việc (Session)
- **Frontend (Flutter):**
  - Giao diện: `lib/views/auth/login_page.dart`.
  - Xử lý: Nhập Username & Password $\rightarrow$ Gọi `AuthRepository.login(username, password)`.
  - HTTP Request: `POST http://localhost:5138/api/auth/login`
  - **Mẫu JSON Request:**
    ```json
    {
      "username": "admin",
      "password": "Password123@"
    }
    ```
  - **Mẫu JSON Response Thành công (200 OK):**
    ```json
    {
      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
      "accountId": 1,
      "username": "admin",
      "fullName": "Nguyễn Văn Quản Trị",
      "role": "ADMIN",
      "roleName": "Quản trị viên hệ thống"
    }
    ```
  - Lưu trữ trên máy điện thoại:
    - Lưu vào `SharedPreferences` và bảng SQLite `user_session`:
      ```sql
      INSERT OR REPLACE INTO user_session (id, user_id, username, full_name, role, token, logged_in_at)
      VALUES (1, 1, 'admin', 'Nguyễn Văn Quản Trị', 'ADMIN', 'eyJhbGci...', datetime('now'));
      ```
  - Phân quyền điều hướng:
    - Nếu `role == 'ADMIN'` $\rightarrow$ Chuyển sang màn hình `AdminDashboardPage`.
    - Nếu `role == 'WAITER'` hoặc `'MEMBER'` $\rightarrow$ Chuyển sang màn hình `CategoryPage` / `HomePage`.

---

### 1.3. Đổi mật khẩu, Quản lý Thành viên & Phân quyền Role
- **Đổi mật khẩu:** `POST /api/auth/change-password` với `{ oldPassword, newPassword }`.
- **Quản lý Member & Role (Admin):**
  - `GET /api/account/members`: Trả về danh sách tài khoản kèm vai trò.
  - `PUT /api/account/{id}/role`: Cho phép Admin nâng quyền hoặc đổi RoleId cho nhân viên.

---

## 2. QUẢN LÝ DANH MỤC DÀNH CHO ADMIN (CATEGORY MANAGEMENT)

### 2.1. Hiển thị danh mục
- **Endpoint:** `GET /api/category`
- **Mẫu JSON Response (200 OK):**
  ```json
  [
    {
      "id": 1,
      "name": "Cà phê truyền thống",
      "title": "Cà phê phin Robusta Đắk Lắk",
      "description": "Đậm đà hương vị nguyên bản cà phê rang mộc Tây Nguyên",
      "icon": "traditional_coffee.png",
      "sortOrder": 1,
      "isActive": true
    },
    {
      "id": 2,
      "name": "Trà trái cây tươi",
      "title": "Trà đào, trà vải, trà dâu nhiệt đới",
      "description": "Trà tươi ủ mộc thanh mát bổ dưỡng",
      "icon": "fruit_tea.png",
      "sortOrder": 2,
      "isActive": true
    }
  ]
  ```

### 2.2. Thêm & Sửa danh mục (Xử lý vòng đời file ảnh)
- **Thêm:** `POST /api/category` (FormData: `Name`, `Title`, `Description`, `file`). Server lưu ảnh vào `wwwroot/images/categories/{guid}.png`.
- **Sửa:** `PUT /api/category/{id}` (FormData: thông tin cập nhật + file ảnh mới nếu có).
  - Backend đọc `existing.Icon` từ database.
  - Xóa file cũ bằng `Helper.DeleteImage(existing.Icon, "images/categories")`.
  - Lưu file mới vào thư mục và cập nhật database.

### 2.3. Xóa danh mục (Kiểm tra ràng buộc sản phẩm)
- **Endpoint:** `DELETE /api/category/{id}`
- **Logic kiểm tra bắt buộc:**
  ```csharp
  if (Provider.Category.HasProducts(id)) {
      return BadRequest(new { error = "Không thể xóa danh mục vì vẫn còn sản phẩm thuộc danh mục này!" });
  }
  ```
- Nếu không có sản phẩm: Xóa file ảnh trong `wwwroot` $\rightarrow$ Xóa bản ghi trong SQL Server $\rightarrow$ Trả về `200 OK`.

---

## 3. QUẢN LÝ SẢN PHẨM THEO DANH MỤC (PRODUCTS WITH PAGINATION)

### 3.1. Hiển thị sản phẩm có Phân trang (Pagination)
- **Endpoint:** `GET /api/product?categoryId=1&page=1&pageSize=10&search=Cà phê`
- **Mẫu JSON Response (200 OK):**
  ```json
  {
    "totalItems": 45,
    "page": 1,
    "pageSize": 10,
    "totalPages": 5,
    "data": [
      {
        "productId": 1,
        "categoryId": 1,
        "productName": "Cà phê đen đá Đắk Lắk",
        "price": 25000,
        "unit": "Ly",
        "description": "Hạt Robusta nguyên chất pha phin truyền thống",
        "imageUrl": "cafe_den_da.jpg",
        "isAvailable": true,
        "isFeatured": true
      }
    ]
  }
  ```

### 3.2. Xóa sản phẩm (Kiểm tra ràng buộc đơn hàng)
- **Endpoint:** `DELETE /api/product/{id}`
- **Kiểm tra nghiệp vụ bảo toàn kế toán:**
  - Nếu sản phẩm đã từng nằm trong bảng `OrderDetails`: Trả về `400 Bad Request` thông báo: *"Sản phẩm đã có trong hóa đơn, không được xóa để bảo toàn số liệu kế toán! Hãy chọn ẩn sản phẩm."*
  - Nếu chưa từng có đơn hàng: Xóa file ảnh trong `wwwroot` $\rightarrow$ Xóa bản ghi trong SQL Server.

---

## 4. QUẢN LÝ GIỎ HÀNG OFFLINE VỚI SQLITE & ĐẶT HÀNG (CART & CHECKOUT)

### 4.1. Thao tác trên SQLite Cục bộ
- **Thêm vào giỏ:** `DatabaseHelper.insertOrUpdateCart(item)`. Nếu món đã có thì tăng số lượng `quantity = quantity + 1`.
- **Badge giỏ hàng:** `SELECT SUM(quantity) FROM cart_items` cập nhật realtime trên AppBar.
- **Tăng / Giảm / Xóa:** Nút `+` và `-` gọi `DatabaseHelper.updateCartQuantity(id, newQty)`. Nếu số lượng về 0 thì xóa khỏi SQLite.

### 4.2. Đặt hàng (Checkout)
- **Endpoint:** `POST /api/order`
- **Mẫu JSON Request:**
  ```json
  {
    "tableId": 1,
    "customerName": "Anh Tuấn",
    "phoneNumber": "0912345678",
    "orderType": 1,
    "note": "Ít ngọt, mang đá riêng",
    "items": [
      {
        "productId": 1,
        "quantity": 2,
        "unitPrice": 25000,
        "itemNote": "Đen đá không đường"
      },
      {
        "productId": 4,
        "quantity": 1,
        "unitPrice": 39000,
        "itemNote": "Nhiều kem muối"
      }
    ]
  }
  ```
- **Mẫu JSON Response (200 OK):**
  ```json
  {
    "statusCode": 200,
    "orderId": 1,
    "orderCode": "ORD-20261004-001",
    "totalAmount": 89000,
    "tableId": 1,
    "message": "Đặt hàng thành công, đơn đã được chuyển xuống bếp"
  }
  ```
- Khi nhận 200 OK: Flutter gọi `DatabaseHelper.clearCart()` dọn sạch giỏ hàng cục bộ.

---

## 5. THANH TOÁN TRỰC TUYẾN: VIETQR & VNPAY

### 5.1. Thanh toán qua mã VietQR NAPAS 247 động
- Client tạo URL ảnh QR trực tiếp:
  `https://img.vietqr.io/image/MB-0901234567-compact2.png?amount=89000&addInfo=THANH TOAN ORD-20261004-001`
- Hiển thị Dialog mã QR cho khách quét trên ứng dụng Mobile Banking của bất kỳ ngân hàng nào.
- Sau khi tiền về: Thu ngân bấm "Xác nhận nhận tiền" $\rightarrow$ Gọi `POST /api/payment/confirm`.

### 5.2. Thanh toán qua VNPayment Gateway
- Client gọi `POST /api/payment/create-vnpay-url` với `{ orderId: 1, amount: 89000 }`.
- Server ký thuật toán HMAC-SHA512 với `vnp_HashSecret`, trả về URL cổng thanh toán Sandbox.
- App mở Webview cho khách nhập thẻ ATM hoặc quét VNPay-QR.
- Webhook IPN từ VNPay cập nhật trạng thái đơn hàng sang `Status = 3` (Đã thanh toán) và bàn chuyển về trạng thái `0` (Trống).

---

## 6. QUẢN LÝ ĐƠN HÀNG DÀNH CHO ADMIN & BẾP (KDS)

### 6.1. Danh sách đơn hàng & Lọc theo ngày
- **Endpoint:** `GET /api/order/admin?fromDate=2026-10-01&toDate=2026-10-04&search=ORD`
- **Mẫu JSON Response:**
  ```json
  {
    "totalOrders": 10,
    "totalRevenue": 1450000,
    "orders": [
      {
        "orderId": 1,
        "orderCode": "ORD-20261004-001",
        "tableName": "Bàn T1-01",
        "customerName": "Anh Tuấn",
        "totalAmount": 89000,
        "status": 1,
        "statusText": "Đang chế biến",
        "createdAt": "2026-10-04T16:00:00"
      }
    ]
  }
  ```

### 6.2. Cập nhật trạng thái chế biến KDS
- **Endpoint:** `PUT /api/order/{id}/status` với `{ "status": 2 }` (Chuyển sang "Đã phục vụ").
- Server cập nhật `Orders.Status = 2` và `DiningTables.Status = 0` khi đơn kết thúc thanh toán.
