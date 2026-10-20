# KẾ HOẠCH PHÂN CHIA PHASE THỰC HIỆN & HƯỚNG DẪN COLLABORATOR
**Dự án:** Ứng dụng Quản lý Nhà hàng & Quán Cà phê POS (Flutter + .NET 10 + SQL Server + SQLite)

---

## I. NGUYÊN TẮC PHỐI HỢP NHÓM (COLLABORATOR PROTOCOL)

1. **Chuẩn Kiến trúc Thống nhất:**
   - **Flutter Mobile:** Bắt buộc tuân thủ phong cách của thầy (Repository Pattern, Model có `factory fromMap`, `Map<String, dynamic> toMap`, `StatefulWidget` quản lý trạng thái, `DatabaseHelper` singleton cho SQLite).
   - **.NET 10 Web API:** Tuân thủ mô hình `BaseController` $\rightarrow$ `SiteProvider` $\rightarrow$ `BaseRepository` $\rightarrow$ `DbContext`. Không tự ý cài đặt thêm các thư viện phức tạp gây khó chấm điểm.
2. **Quy ước Mã nguồn & Thư mục:**
   - `mobile/lib/models/`: Chứa các thực thể dữ liệu Dart.
   - `mobile/lib/repositories/`: Chứa các class gọi API (`http.get`, `http.post`) và SQLite Helper.
   - `mobile/lib/views/`: Chứa các màn hình giao diện (chia theo folder `auth`, `category`, `product`, `cart`, `order`, `admin`).
   - `backend/Api/Controllers/`: Chứa các Web API Controllers kế thừa `BaseController`.
   - `backend/Models/`: Chứa DbContext, thực thể EF Core, và các Repository tương ứng.
3. **Quy chuẩn Git:**
   - Branch chính: `main` (chỉ merge khi tính năng đã pass test).
   - Branch tính năng: `feature/auth`, `feature/category`, `feature/product`, `feature/cart-order`, `feature/admin-order`.

---

## II. PHÂN CHIA CHI TIẾT 6 PHASE THỰC HIỆN

```
Phase 1: Khởi tạo & Hạ tầng (Database + SQLite + Base Architecture)
   │
Phase 2: Nhóm Xác thực & Phân quyền (Auth & Roles) [3.25 điểm]
   │
Phase 3: Nhóm Danh mục & Sản phẩm Admin (Upload ảnh + Phân trang) [4.50 điểm]
   │
Phase 4: Trang chủ & Giỏ hàng Offline (SQLite + Checkout) [5.75 điểm]
   │
Phase 5: Quản lý Đơn hàng & Thanh toán (VietQR, VNPay, Admin Order) [2.00 điểm]
   │
Phase 6: Chức năng Mở rộng (Sơ đồ Bàn, KDS Bếp, In Hóa đơn) & Hoàn thiện [Điểm cộng 10+]
```

---

### PHASE 1: KHỞI TẠO CẤU TRÚC & HẠ TẦNG CƠ SỞ (NGÀY 1 - 2)
- **Mục tiêu:** Tạo khung dự án, cấu hình kết nối SQL Server, tạo database và nạp dữ liệu mẫu; cấu hình SQLite trên điện thoại.
- **Công việc Backend:**
  - Chạy script tạo CSDL `RestaurantPosDb` trên SQL Server (`docs/04_THIET_KE_CO_SO_DU_LIEU_MERMAID.md`).
  - Cài đặt EF Core trong `backend/WebApi.csproj`.
  - Viết `RestaurantPosContext.cs`, `BaseRepository.cs`, `BaseProvider.cs`, `SiteProvider.cs`, `BaseController.cs`.
  - Kiểm tra kết nối chuỗi ConnectionString trong `appsettings.json`.
- **Công việc Mobile:**
  - Kiểm tra `pubspec.yaml` (các package: `http`, `sqflite`, `path`, `shared_preferences`, `intl`).
  - Viết `DatabaseHelper.dart` khởi tạo database SQLite `restaurant_pos.db` với các bảng `CartItems`, `LocalUserSession`, `CachedProducts`.
- **Người phụ trách:** Lead Dev / Backend Dev.

---

### PHASE 2: NHÓM XÁC THỰC NGƯỜI DÙNG & PHÂN QUYỀN (NGÀY 3 - 5)
- **Mục tiêu:** Hoàn thành 100% Nhóm 1 (Đăng ký, Đăng nhập, Đổi MK, Quản lý Member, Phân quyền Admin/Member).
- **Backend:**
  - Viết `AccountRepository.cs` với các hàm `Login`, `Register`, `ChangePassword`, `GetMembers`, `UpdateRole`.
  - Tạo `AuthController.cs` với các endpoint: `POST /api/auth/register`, `POST /api/auth/login`, `POST /api/auth/change-password`.
- **Mobile:**
  - Màn hình `LoginPage.dart`: form đăng nhập, lưu token vào `SharedPreferences` và `DatabaseHelper`.
  - Màn hình `RegisterPage.dart`: đăng ký thành viên mới.
  - Màn hình `ChangePasswordPage.dart`.
  - Xử lý điều hướng phân quyền: Nếu `role == 'Admin'` $\rightarrow$ Mở thanh menu Admin; nếu `Member` $\rightarrow$ Mở menu Bán hàng.
- **Tiêu chí nghiệm thu (Done-when):**
  - Đăng ký tài khoản mới thành công, kiểm tra không cho trùng Username.
  - Đăng nhập đúng chuyển trang, đăng nhập sai báo lỗi.
  - Đăng xuất xóa sạch session trên SQLite.

---

### PHASE 3: QUẢN LÝ DANH MỤC & SẢN PHẨM ADMIN (NGÀY 6 - 9)
- **Mục tiêu:** Hoàn thành Nhóm 2 & Nhóm 3 (Upload ảnh xử lý 3 trường hợp, Phân trang, Ràng buộc dữ liệu khi xóa).
- **Backend:**
  - `CategoryRepository.cs` & `CategoryController.cs`:
    - Thêm danh mục có upload ảnh vào `wwwroot/images/categories`.
    - Sửa danh mục: xóa file ảnh cũ khi có ảnh mới.
    - Xóa danh mục: kiểm tra `Products.Any(p => p.CategoryId == id)`. Nếu có $\rightarrow$ chặn xóa!
  - `ProductRepository.cs` & `ProductController.cs`:
    - API phân trang: `GET /api/product?page=1&pageSize=10&categoryId=...`.
    - Thêm sản phẩm có upload ảnh vào `wwwroot/images/products`.
    - Sửa sản phẩm: xóa file ảnh cũ khi cập nhật ảnh mới.
    - Xóa sản phẩm: kiểm tra `OrderDetails.Any(od => od.ProductId == id)`. Nếu có $\rightarrow$ chặn xóa!
- **Mobile:**
  - Màn hình `AdminCategoryPage.dart`: hiển thị danh mục, nút Thêm/Sửa/Xóa.
  - Màn hình `AdminProductPage.dart`: danh sách có phân trang (cuộn tải thêm), form Thêm/Sửa chọn ảnh từ máy.
- **Tiêu chí nghiệm thu:**
  - Thêm, sửa, xóa file ảnh trong `wwwroot` thực tế không bị rác ổ cứng.
  - Phân trang hoạt động mượt mà.
  - Thử xóa danh mục đang có sản phẩm $\rightarrow$ Hệ thống cảnh báo đúng theo yêu cầu.

---

### PHASE 4: TRANG CHỦ & QUẢN LÝ GIỎ HÀNG OFFLINE (NGÀY 10 - 13)
- **Mục tiêu:** Hoàn thành Nhóm 4 & Nhóm 5 (Trang chủ lọc danh mục, tìm kiếm, Chi tiết, Giỏ hàng SQLite, Đặt hàng).
- **Mobile:**
  - `HomePage.dart`: Thanh tìm kiếm phân trang, thanh ngang danh mục món, danh sách món mới nhất có phân trang.
  - `ProductDetailPage.dart`: Xem hình lớn, giá, mô tả, nút "Thêm vào giỏ", danh sách món liên quan bên dưới.
  - Badge giỏ hàng trên AppBar: Hiển thị tổng số lượng món realtime.
  - `CartPage.dart`:
    - Đọc từ SQLite `CartItems`.
    - Nút `+` và `-` tăng giảm số lượng, tính toán lại tổng tiền trực tiếp.
    - Vuốt xóa món khỏi giỏ hàng.
    - Form Checkout: Chọn Bàn (hoặc mang về), nhập ghi chú, bấm Đặt hàng.
- **Backend:**
  - API `POST /api/order`: Tiếp nhận đơn hàng, mở Transaction lưu `Orders` và `OrderDetails`.
  - Cập nhật trạng thái bàn ăn sang "Có khách".
- **Tiêu chí nghiệm thu:**
  - Tắt app bật lại, giỏ hàng trong SQLite vẫn còn nguyên vẹn.
  - Đặt hàng thành công tạo đầy đủ dữ liệu trong SQL Server và xóa giỏ hàng SQLite.

---

### PHASE 5: QUẢN LÝ ĐƠN HÀNG ADMIN & THANH TOÁN (NGÀY 14 - 17)
- **Mục tiêu:** Hoàn thành Nhóm 6 (Quản lý đơn hàng, lọc ngày, đổi trạng thái) + Tích hợp VietQR / VNPay.
- **Backend:**
  - `OrderRepository.cs`: Lọc đơn hàng theo khoảng ngày, tìm kiếm mã đơn, cập nhật trạng thái đơn (`Status`).
  - Tích hợp sinh mã VietQR và API tạo link thanh toán VNPay Sandbox.
- **Mobile:**
  - `AdminOrderListPage.dart`: Danh sách đơn hàng trong ngày, bộ lọc DateRangePicker, nút chuyển đổi trạng thái đơn.
  - `OrderDetailPage.dart`: Xem chi tiết đơn hàng, danh sách món, tổng tiền, mã QR thanh toán VietQR động để khách quét tiền.
- **Tiêu chí nghiệm thu:**
  - Quét mã VietQR chuyển đúng số tiền và nội dung đơn hàng.
  - Admin đổi trạng thái đơn hàng cập nhật tức thì trên database.

---

### PHASE 6: TÍNH NĂNG MỞ RỘNG (SƠ ĐỒ BÀN, BẾP KDS) & TỔNG DUYỆT (NGÀY 18 - 20)
- **Mục tiêu:** Đạt điểm 10 tuyệt đối và điểm cộng vượt trội.
- **Công việc:**
  - Hoàn thiện giao diện Sơ đồ bàn `FloorTablePage.dart` (Bàn trống xanh, Bàn có khách đỏ, Bàn đặt vàng).
  - Hoàn thiện giao diện Bếp `KitchenDisplayPage.dart` (Xem các món cần chế biến, bấm chuyển trạng thái).
  - Xuất phiếu hóa đơn xem trước dạng PDF đẹp mắt.
  - Tổng duyệt toàn bộ barem điểm, kiểm tra các trường hợp biên (validation, xử lý mất mạng).
