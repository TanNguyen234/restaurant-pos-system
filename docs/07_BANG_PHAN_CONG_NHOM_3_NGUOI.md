# BẢNG PHÂN CÔNG NHIỆM VỤ DỰ ÁN CHO NHÓM 3 NGƯỜI
## HỆ THỐNG RESTAURANT & CAFE POS (FLUTTER + .NET 10 + SQL SERVER + SQLITE)

---

## 1. PHÂN BỔ VAI TRÒ TỔNG QUÁT

Để đảm bảo dự án đạt điểm tối đa (10/10 điểm gốc + 3.5 điểm cộng), tiến độ không bị chậm trễ và **không xảy ra xung đột mã nguồn (Git merge conflicts)**, 3 thành viên được phân định trách nhiệm rõ ràng theo chuyên môn và luồng file:

| Thành Viên | Vai Trò Chính | Trọng Tâm Trách Nhiệm | Điểm Barem Phụ Trách |
| :--- | :--- | :--- | :---: |
| **Thành viên 1 (Bạn)** | **Team Leader & Fullstack Architect** | CSDL SQL Server, Kiến trúc Base Backend & Mobile, Quản lý Bàn ăn, Đồng bộ Offline SQLite, Tích hợp & Review code | **Toàn bộ hệ thống + 2.5đ mở rộng** |
| **Thành viên 2 (Collaborator A)** | **Frontend & Catalog Specialist** | UI/UX Trang chủ, Quản lý Danh mục, Sản phẩm phân trang, Upload/Xóa ảnh wwwroot, Giỏ hàng SQLite trên điện thoại | **6.50 điểm (Nhóm 2, 3, 4, 5)** |
| **Thành viên 3 (Collaborator B)** | **Backend & Security Specialist** | Xác thực tài khoản (Auth/RBAC), Quản lý đơn hàng Admin, Tích hợp thanh toán VietQR & VNPay, Màn hình Bếp KDS | **6.50 điểm (Nhóm 1, 6 + Thanh toán & KDS)** |

---

## 2. MA TRẬN PHÂN CÔNG THEO TỪNG FILE MÃ NGUỒN (FILE OWNERSHIP MATRIX)

Mỗi thành viên làm việc độc lập trên các file riêng biệt, cam kết không can thiệp chéo vào file của thành viên khác trừ khi có trao đổi trước:

### 2.1. Phân công phía Backend ASP.NET Core 10 (`backend/`)

| File Mã Nguồn | Chức Năng Cụ Thể | Người Phụ Trách |
| :--- | :--- | :---: |
| `RestaurantPosDb.sql` | Khởi tạo CSDL, 10 bảng quan hệ, nạp 10 dòng/bảng | **Thành viên 1 (Bạn)** |
| `Models/RestaurantPosContext.cs` | DbContext, khai báo 10 DbSet, cấu hình Fluent API | **Thành viên 1 (Bạn)** |
| `Models/BaseProvider.cs`, `BaseRepository.cs`, `SiteProvider.cs` | Kiến trúc Facade / Provider chuẩn của thầy | **Thành viên 1 (Bạn)** |
| `Api/Controllers/BaseController.cs` | Base Controller cung cấp Provider | **Thành viên 1 (Bạn)** |
| `Models/TableRepository.cs` & `Controllers/TableController.cs` | API sơ đồ bàn, đổi trạng thái bàn, chuyển bàn | **Thành viên 1 (Bạn)** |
| `Services/Helper.cs` | Helper lưu ảnh vào wwwroot và xóa file ảnh cũ | **Thành viên 2 (Collab A)** |
| `Models/CategoryRepository.cs` & `Controllers/CategoryController.cs` | API danh mục, kiểm tra HasProducts() chặn xóa | **Thành viên 2 (Collab A)** |
| `Models/ProductRepository.cs` & `Controllers/ProductController.cs` | API sản phẩm phân trang, kiểm tra HasOrders() chặn xóa | **Thành viên 2 (Collab A)** |
| `Models/AccountRepository.cs` & `Controllers/AuthController.cs` | Đăng ký, đăng nhập băm mật khẩu, đổi MK, OAuth | **Thành viên 3 (Collab B)** |
| `Models/OrderRepository.cs` & `Controllers/OrderController.cs` | Tạo đơn Transaction, đổi trạng thái đơn, lọc ngày | **Thành viên 3 (Collab B)** |
| `Models/PaymentRepository.cs` & `Controllers/PaymentController.cs` | Sinh mã VietQR động, tạo URL VNPay Sandbox HMAC | **Thành viên 3 (Collab B)** |
| `Controllers/KdsController.cs` | API màn hình bếp (lấy món cần nấu, cập nhật CookingStatus) | **Thành viên 3 (Collab B)** |

---

### 2.2. Phân công phía Mobile Flutter (`mobile/`)

| File Mã Nguồn | Chức Năng Cụ Thể | Người Phụ Trách |
| :--- | :--- | :---: |
| `lib/utils/database_helper.dart` | Singleton SQLite quản lý cart_items, user_session, offline_orders | **Thành viên 1 (Bạn)** |
| `lib/views/table/floor_table_page.dart` | Sơ đồ bàn theo khu vực (Bàn trống xanh, Có khách đỏ, Chuyển bàn) | **Thành viên 1 (Bạn)** |
| `lib/services/offline_sync_service.dart` | Service đồng bộ đơn hàng ngoại tuyến khi có mạng | **Thành viên 1 (Bạn)** |
| `lib/main.dart` & Cấu hình theme/routes | Điều hướng và khởi chạy ứng dụng | **Thành viên 1 (Bạn)** |
| `lib/models/category.dart` & `product.dart` | Model DTO có factory fromMap() và toMap() | **Thành viên 2 (Collab A)** |
| `lib/repositories/category_repository.dart` & `product_repository.dart` | Gọi HTTP GET/POST/PUT/DELETE danh mục & sản phẩm | **Thành viên 2 (Collab A)** |
| `lib/views/home_page.dart` | Trang chủ: Menu ngang, món mới phân trang, search bar phân trang | **Thành viên 2 (Collab A)** |
| `lib/views/product_detail_page.dart` | Xem hình lớn, chọn Size/Topping, món liên quan phân trang, thêm giỏ | **Thành viên 2 (Collab A)** |
| `lib/views/cart_page.dart` | Giỏ hàng SQLite: Badge realtime, nút (+)/(-) tính tiền tức thì, xóa món | **Thành viên 2 (Collab A)** |
| `lib/views/admin/admin_category_page.dart` | Quản trị danh mục: Thêm/Sửa/Xóa chọn ảnh từ thiết bị | **Thành viên 2 (Collab A)** |
| `lib/views/admin/admin_product_page.dart` | Quản trị món ăn: Cuộn tải thêm phân trang, form thêm/sửa món | **Thành viên 2 (Collab A)** |
| `lib/models/user.dart`, `order.dart`, `payment.dart` | Model DTO cho Auth, Đơn hàng và Thanh toán | **Thành viên 3 (Collab B)** |
| `lib/repositories/auth_repository.dart` & `order_repository.dart` | Gọi API Đăng ký, Đăng nhập, Checkout đơn hàng, Thanh toán | **Thành viên 3 (Collab B)** |
| `lib/views/auth/login_page.dart` & `register_page.dart` | Màn hình đăng nhập/đăng ký, lưu session vào SQLite, phân quyền Role | **Thành viên 3 (Collab B)** |
| `lib/views/auth/change_password_page.dart` | Form đổi mật khẩu tài khoản | **Thành viên 3 (Collab B)** |
| `lib/views/order/order_checkout_page.dart` | Chọn bàn, xác nhận đặt món, chọn phương thức thanh toán | **Thành viên 3 (Collab B)** |
| `lib/views/order/order_detail_page.dart` | Chi tiết đơn, hiển thị mã VietQR động cho khách quét thanh toán | **Thành viên 3 (Collab B)** |
| `lib/views/admin/admin_order_list_page.dart` | Dashboard đơn hàng, bộ lọc DateRangePicker, nút đổi trạng thái | **Thành viên 3 (Collab B)** |
| `lib/views/kitchen/kitchen_display_page.dart` | Màn hình Bếp KDS: Thẻ món đếm giờ, nút 'Đang nấu' / 'Đã xong' | **Thành viên 3 (Collab B)** |

---

## 3. LỘ TRÌNH TRIỂN KHAI THEO TUẦN (3-WEEK SPRINT TIMELINE)

```
TUẦN 1: HẠ TẦNG, XÁC THỰC & DANH MỤC CƠ BẢN
├── Thành viên 1: Setup SQL Server, DbContext, BaseProvider, DatabaseHelper SQLite.
├── Thành viên 2: Xây dựng Model/Repository Category, Màn hình danh mục & Form thêm/sửa có upload ảnh.
└── Thành viên 3: Xây dựng AuthController, Hash mật khẩu, Màn hình Login/Register, Lưu session SQLite.

TUẦN 2: SẢN PHẨM PHÂN TRANG, TRANG CHỦ & GIỎ HÀNG OFFLINE
├── Thành viên 1: Xây dựng Sơ đồ Bàn ăn (FloorTablePage), API Table/Area, cơ chế đổi trạng thái bàn.
├── Thành viên 2: Sản phẩm phân trang, Tìm kiếm phân trang, Màn hình Trang chủ, Màn hình Giỏ hàng SQLite.
└── Thành viên 3: API Đặt hàng Transaction, Quản lý đơn hàng Admin, Lọc đơn hàng theo khoảng ngày.

TUẦN 3: THANH TOÁN (VIETQR / VNPAY), MÀN HÌNH BẾP KDS & TỔNG DUYỆT
├── Thành viên 1: Đồng bộ hóa ngoại tuyến (Offline Queue Sync), In hóa đơn PDF, Review code & Merge branch.
├── Thành viên 2: Kiểm tra ràng buộc xóa (không cho xóa danh mục có món, không xóa món có trong đơn).
└── Thành viên 3: Tích hợp VietQR động, Cổng VNPayment Sandbox, Màn hình Bếp KDS thời gian thực.
└── CẢ 3 THÀNH VIÊN: Tổng duyệt 37 tiêu chí barem điểm, diễn tập kịch bản bảo vệ đồ án trước giảng viên.
```

---

## 4. KỊCH BẢN PHÂN CHIA BẢO VỆ ĐỒ ÁN TRƯỚC GIẢNG VIÊN (DEFENSE STRATEGY)

Khi lên báo cáo trước hội đồng/giảng viên, mỗi thành viên sẽ tự tin trình bày đúng mảng mình trực tiếp lập trình:

1. **Thành viên 1 (Bạn - Báo cáo Tổng quan & Kiến trúc):**
   - Trình bày thiết kế CSDL SQL Server 10 bảng chuẩn hóa và 10 lần tự phản biện.
   - Giải trình kiến trúc Backend: `BaseController` $\rightarrow$ `SiteProvider` $\rightarrow$ `BaseRepository` theo đúng mẫu thầy dạy.
   - Demo tính năng: Sơ đồ bàn ăn trực quan và cơ chế lưu trữ ngoại tuyến SQLite khi mất mạng.

2. **Thành viên 2 (Collaborator A - Báo cáo Menu, Sản phẩm & Giỏ hàng):**
   - Demo tính năng Quản lý danh mục & sản phẩm: Upload ảnh 3 trường hợp (Thêm, Sửa ảnh mới xóa ảnh cũ, Xóa dọn file `wwwroot`).
   - Demo tính năng ràng buộc an toàn: Bấm xóa danh mục đang có sản phẩm $\rightarrow$ Hệ thống cảnh báo từ chối xóa; Bấm xóa sản phẩm đã có trong hóa đơn $\rightarrow$ Hệ thống chặn xóa.
   - Demo Trang chủ phân trang mượt mà và Giỏ hàng SQLite (tắt app bật lại giỏ hàng vẫn còn nguyên).

3. **Thành viên 3 (Collaborator B - Báo cáo Xác thực, Đơn hàng, KDS & Thanh toán):**
   - Demo nhóm Xác thực: Đăng ký, đăng nhập băm mật khẩu, phân quyền Role (Admin vào Dashboard quản trị, Waiter vào màn hình phục vụ).
   - Demo quy trình Đặt hàng (Checkout) $\rightarrow$ Đơn nhảy sang Màn hình Bếp KDS $\rightarrow$ Đầu bếp bấm "Đang làm" $\rightarrow$ "Hoàn thành".
   - Demo thanh toán: Mở ứng dụng ngân hàng quét mã VietQR động nhảy đúng số tiền và mã hóa đơn; Demo cổng VNPayment Sandbox.
