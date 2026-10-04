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
  - HTTP Request: `POST http://localhost:5138/api/auth/register` (JSON body).
- **Backend (.NET 10 API):**
  - Controller: `AuthController.cs` kế thừa `BaseController`.
  - Service/Repo: `Provider.Account.Register(RegisterDto model)`.
  - Logic nghiệp vụ:
    1. Kiểm tra `Username` hoặc `Email` đã tồn tại trong bảng `Accounts` chưa. Nếu có $\rightarrow$ Trả về `BadRequest("Tài khoản hoặc email đã tồn tại")`.
    2. Băm mật khẩu (BCrypt hoặc SHA-256 kèm Salt).
    3. Gán mặc định `RoleId = 2` (Member / Staff).
    4. Thêm bản ghi vào bảng `Accounts`, sinh mã token kích hoạt nếu có bật xác thực email. Trả về `Ok(new { message = "Đăng ký thành công" })`.
- **Database (SQL Server):**
  - Thao tác: `INSERT INTO Accounts (Username, PasswordHash, FullName, Email, PhoneNumber, RoleId, CreatedAt) VALUES (...)`.

---

### 1.2. Đăng nhập (Login) & Lưu trữ phiên (Session Management)
- **Frontend (Flutter):**
  - Giao diện: `lib/views/auth/login_page.dart`.
  - Xử lý: Nhập Username/Password $\rightarrow$ Gọi `AuthRepository.login(username, password)`.
  - Khi nhận phản hồi thành công:
    - Lưu `token`, `userId`, `username`, `role` vào `SharedPreferences` và bảng SQLite `UserSession`.
    - Phân quyền điều hướng: Nếu `role == "Admin"` $\rightarrow$ chuyển đến `AdminDashboardPage`, nếu `role == "Member"` hoặc `"Staff"` $\rightarrow$ chuyển đến `PosHomePage`.
- **Backend (.NET 10 API):**
  - API: `POST /api/auth/login`.
  - Logic: Tìm tài khoản theo `Username` $\rightarrow$ Xác thực hash mật khẩu $\rightarrow$ Sinh chuỗi Token/Session $\rightarrow$ Trả về JSON chứa `{ token, userId, username, fullName, role: "Admin"|"Member" }`.
- **Database:**
  - Query: `SELECT TOP 1 a.*, r.RoleName FROM Accounts a JOIN Roles r ON a.RoleId = r.RoleId WHERE a.Username = @Username AND a.IsActive = 1`.

---

### 1.3. Đổi mật khẩu & Quản lý Member / Role
- **Đổi mật khẩu:**
  - Client gửi `POST /api/auth/change-password` kèm mật khẩu cũ và mới.
  - Server kiểm tra hash mật khẩu cũ $\rightarrow$ Cập nhật hash mới vào SQL Server.
- **Quản lý Member (Dành cho Admin):**
  - Client: `MemberListPage.dart` $\rightarrow$ Gọi `GET /api/member`.
  - Server: Trả về danh sách người dùng, cho phép Admin cập nhật `RoleId` hoặc khóa tài khoản (`IsActive = 0`).

---

## 2. QUẢN LÝ DANH MỤC DÀNH CHO ADMIN (CATEGORY MANAGEMENT)

### 2.1. Hiển thị danh mục
- **Frontend:** `CategoryPage` gọi `CategoryRepository.getCategories()` $\rightarrow$ Render danh sách với ảnh đại diện, tên danh mục, mô tả.
- **Backend:** `CategoryController.cs` $\rightarrow$ `Provider.Category.GetCategories()` $\rightarrow$ `_context.Categories.AsNoTracking().ToList()`.

### 2.2. Thêm danh mục (Có Upload hình ảnh)
- **Frontend:** `AddCategoryDialog` hoặc `AddCategoryPage`. Người dùng chọn file ảnh từ máy hoặc camera $\rightarrow$ Gửi `MultipartRequest` hoặc chuỗi Base64 / URL ảnh.
- **Backend:** 
  - `Helper.SaveImageAsync(IFormFile file, "categories")` $\rightarrow$ Lưu vật lý vào thư mục `wwwroot/images/categories/{unique_name}.png`.
  - Ghi đường dẫn ảnh vào trường `Icon` của bản ghi `Category`.
  - Trả về đối tượng Category vừa tạo thành công.
- **Database:** `INSERT INTO Category (CategoryName, Title, Description, Icon) VALUES (...)`.

### 2.3. Sửa danh mục (Upload ảnh mới - Tự động xóa ảnh cũ)
- **Frontend:** Gửi `PUT /api/category/{id}` kèm thông tin mới và file ảnh (nếu có thay đổi).
- **Backend:**
  - Đọc bản ghi Category hiện tại từ SQL Server.
  - Nếu người dùng upload ảnh mới:
    - Xóa file ảnh cũ trong `wwwroot/images/categories/` bằng `System.IO.File.Delete(...)`.
    - Lưu file ảnh mới và cập nhật thuộc tính `Icon`.
  - Cập nhật các trường `CategoryName`, `Title`, `Description`.
  - Gọi `_context.SaveChanges()`.

### 2.4. Xóa danh mục (Kiểm tra ràng buộc có sản phẩm trước khi xóa)
- **Frontend:** Nút Xóa có hộp thoại xác nhận (Confirm Dialog).
- **Backend:**
  - API: `DELETE /api/category/{id}`.
  - **Kiểm tra nghiệp vụ bắt buộc:**
    ```csharp
    bool hasProducts = _context.Products.Any(p => p.CategoryId == id);
    if (hasProducts) {
        return BadRequest("Không thể xóa danh mục này vì vẫn còn sản phẩm thuộc danh mục!");
    }
    ```
  - Nếu không còn sản phẩm: Xóa file ảnh vật lý của Category trong `wwwroot` $\rightarrow$ Xóa bản ghi trong SQL Server $\rightarrow$ Trả về `Ok()`.

---

## 3. QUẢN LÝ SẢN PHẨM THEO DANH MỤC (PRODUCT MANAGEMENT & PAGINATION)

### 3.1. Hiển thị sản phẩm có Phân trang (Pagination)
- **Frontend:**
  - Sử dụng `ScrollController` gắn vào `ListView` hoặc `GridView`.
  - Khi cuộn đến đáy trang (`scrollController.position.pixels == maxScrollExtent`):
    - Tăng `pageIndex++`.
    - Gọi `ProductRepository.getProducts(categoryId: selectedCategory, page: pageIndex, pageSize: 10)`.
    - Nối tiếp dữ liệu vào danh sách hiện tại và gọi `setState(() {})`.
- **Backend:**
  - API: `GET /api/product?categoryId={id}&page={page}&pageSize={pageSize}&search={keyword}`.
  - Linq Query trên SQL Server:
    ```csharp
    var query = _context.Products.AsQueryable();
    if (categoryId.HasValue) query = query.Where(p => p.CategoryId == categoryId.Value);
    if (!string.IsNullOrEmpty(search)) query = query.Where(p => p.ProductName.Contains(search));
    
    int totalItems = await query.CountAsync();
    var items = await query.OrderByDescending(p => p.ProductId)
                           .Skip((page - 1) * pageSize)
                           .Take(pageSize)
                           .ToListAsync();
    ```
  - Trả về payload chuẩn: `{ totalItems, page, pageSize, totalPages, data: [...] }`.

### 3.2. Thêm sản phẩm (Bắt buộc Upload hình ảnh)
- **Frontend:** Chọn ảnh từ thiết bị, nhập Tên sản phẩm, Đơn giá, Đơn vị tính, Chọn danh mục $\rightarrow$ Gửi lên API.
- **Backend:**
  - Lưu file ảnh vào `wwwroot/images/products/{guid}.jpg`.
  - Ghi bản ghi mới vào bảng `Products`.

### 3.3. Sửa sản phẩm (Upload ảnh mới $\rightarrow$ Xóa ảnh cũ)
- **Backend:** So sánh tên ảnh mới và ảnh cũ. Nếu ảnh mới khác ảnh cũ thì xóa file vật lý cũ, cập nhật đường dẫn ảnh mới vào database.

### 3.4. Xóa sản phẩm (Kiểm tra sản phẩm có trong đơn hàng trước khi xóa)
- **Backend:**
  ```csharp
  bool hasOrder = _context.OrderDetails.Any(od => od.ProductId == productId);
  if (hasOrder) {
      // Cách 1: Chặn xóa để bảo toàn lịch sử hóa đơn
      return BadRequest("Sản phẩm đã có trong lịch sử đơn hàng, không thể xóa! Hãy chọn ẩn sản phẩm.");
  }
  // Nếu chưa có trong đơn: Xóa file ảnh vật lý -> Xóa bản ghi
  ```

---

## 4. HIỂN THỊ SẢN PHẨM TRÊN TRANG CHỦ (HOME SHOWCASE)

1. **Hiển thị danh mục sản phẩm:** Horizontal ListView ở đầu trang chủ, bấm vào danh mục nào thì filter sản phẩm danh mục đó.
2. **Hiển thị sản phẩm mới nhất (có phân trang):** Tab hoặc section "Món mới quán cà phê" sắp xếp theo ngày tạo mới nhất.
3. **Tìm kiếm sản phẩm (có phân trang):** Search bar với debounce (300ms) gọi API tìm kiếm, trả về danh sách có phân trang.
4. **Hiển thị chi tiết sản phẩm:** Xem hình ảnh kích thước lớn, giá niêm yết, thành phần, và danh sách các **Sản phẩm liên quan** (cùng CategoryId, có phân trang gợi ý bên dưới).

---

## 5. QUẢN LÝ GIỎ HÀNG & ĐẶT HÀNG (CART & CHECKOUT)

### 5.1. Mô hình Giỏ hàng Offline-First kết hợp SQLite
- **Cấu trúc lưu trữ trên điện thoại (SQLite):**
  - Bảng SQLite `CartItems (id INTEGER PRIMARY KEY, product_id INT, product_name TEXT, price REAL, quantity INT, image_url TEXT, note TEXT)`.
- **Quy trình hoạt động:**
  1. Người dùng bấm **"Thêm vào giỏ"** tại màn hình Home hoặc Chi tiết.
  2. `CartController` (hoặc `CartDatabaseHelper`) kiểm tra:
     - Nếu `product_id` đã có trong SQLite: `UPDATE CartItems SET quantity = quantity + 1 WHERE product_id = ?`.
     - Nếu chưa có: `INSERT INTO CartItems (...) VALUES (...)`.
  3. Cập nhật Badge số lượng hiển thị trên icon Giỏ hàng ở AppBar (`SELECT SUM(quantity) FROM CartItems`).
  4. Mở trang Giỏ hàng:
     - Hiển thị danh sách món đã chọn.
     - Nút `+` và `-` tăng giảm số lượng trực tiếp trong SQLite, tự tính lại tổng tiền.
     - Vuốt hoặc bấm nút thùng rác để xóa món (`DELETE FROM CartItems WHERE id = ?`).

### 5.2. Đặt hàng (Checkout) & Thanh toán Online (VNPay / VietQR)
- **Quy trình Đặt hàng:**
  1. Khách hàng/Nhân viên chọn Bàn phục vụ (hoặc mang về), nhập ghi chú đơn.
  2. Bấm **"Xác nhận đặt hàng"**:
     - Client gửi toàn bộ giỏ hàng lên `POST /api/order`.
     - Request body: `{ tableId, customerName, note, paymentMethod: "Cash"|"VNPay"|"VietQR", items: [{ productId, quantity, price, note }] }`.
  3. Server tạo giao dịch Transaction:
     - Tạo bản ghi `Orders` (sinh mã Code: `ORD-20261004-XXXX`).
     - Tạo danh sách `OrderDetails`.
     - Cập nhật trạng thái Bàn (`DiningTables.Status = 1` - Đang có khách).
     - Commit Transaction.
  4. Nếu chọn **Thanh toán VietQR:**
     - Server hoặc Client sinh mã VietQR chuẩn NAPAS 247 theo cú pháp:
       `https://img.vietqr.io/image/{BANK_ID}-{ACCOUNT_NO}-compact2.png?amount={TOTAL}&addInfo=THANH TOAN {ORDER_CODE}`.
     - App hiển thị Dialog mã QR để khách quét ứng dụng ngân hàng thanh toán tức thì.
  5. Nếu chọn **Thanh toán VNPay:**
     - Server sinh URL thanh toán VNPay Sandbox có chữ ký bảo mật SHA512.
     - App mở Webview hoặc trình duyệt để khách thanh toán.
  6. Sau khi đặt hàng thành công: Xóa sạch bảng `CartItems` trong SQLite cục bộ, chuyển sang màn hình **Chi tiết đơn hàng**.

---

## 6. QUẢN LÝ ĐƠN HÀNG DÀNH CHO ADMIN (ADMIN ORDER MANAGEMENT)

1. **Hiển thị danh sách đơn hàng:**
   - Danh sách thời gian thực các đơn trong ngày, hiển thị: Mã đơn, Giờ đặt, Số bàn, Tổng tiền, Trạng thái đơn (Badge màu: Chờ xử lý = Vàng, Đang phục vụ = Xanh lá, Đã thanh toán = Xanh dương, Hủy = Đỏ).
2. **Cập nhật trạng thái đơn hàng:**
   - Admin/Nhân viên thu ngân bấm chuyển đổi: `Chờ xác nhận` $\rightarrow$ `Đang pha chế` $\rightarrow$ `Đã phục vụ` $\rightarrow$ `Hoàn thành & Thu tiền`.
   - API: `PUT /api/order/{id}/status` với `{ status: 2 }`.
3. **Bộ lọc đơn hàng nâng cao:**
   - Lọc theo khoảng ngày (Từ ngày - Đến ngày) qua `DateRangePicker`.
   - Tìm kiếm nhanh theo Mã đơn hàng hoặc Số bàn.
   - Thống kê tổng doanh thu theo bộ lọc đã chọn.
