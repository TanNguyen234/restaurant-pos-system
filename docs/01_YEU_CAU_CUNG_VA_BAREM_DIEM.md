# TÀI LIỆU YÊU CẦU CỨNG & BAREM ĐIỂM DỰ ÁN
**Đề tài:** Xây dựng ứng dụng hỗ trợ nhà hàng, quán cà phê quản lý việc order, tính tiền và phục vụ.
**Nền tảng:** Flutter (Dart) + SQLite (On-Device Mobile) + REST API C# .NET Core 10 + Microsoft SQL Server.

---

## I. CÔNG NGHỆ BẮT BUỘC (YÊU CẦU TIÊN QUYẾT)
> [!CAUTION]
> **Lưu ý từ giảng viên:** Sinh viên sử dụng công nghệ khác công nghệ quy định dưới đây sẽ **KHÔNG ĐƯỢC TÍNH ĐIỂM** đồ án.

1. **Mobile Frontend:** 
   - Framework: **Flutter**
   - Ngôn ngữ: **Dart (>= 3.13.1)**
   - Database cục bộ trên máy: **SQLite** (thư viện `sqflite`, quản lý lưu trữ offline, giỏ hàng, thông tin phiên làm việc, offline cache).
   - Mô hình lập trình: **Repository Pattern + StatefulWidget + Http Client** (theo phong cách giảng dạy chuẩn trong `trek_bikes_app` và bài giảng).

2. **Backend Server & Cloud Database:**
   - Framework: **ASP.NET Core 10 Web API (`net10.0`)**
   - Ngôn ngữ: **C#**
   - ORM: **Microsoft.EntityFrameworkCore.SqlServer (10.0.x)**
   - Kiến trúc Server: **BaseController + SiteProvider + BaseRepository** (Mô hình Provider/Repository chuẩn hóa của giảng viên).
   - Cơ sở dữ liệu tập trung: **Microsoft SQL Server**.

---

## II. BẢNG TỔNG HỢP BAREM ĐIỂM CHI TIẾT (10 ĐIỂM GỐC + ĐIỂM CỘNG)

| Nhóm chức năng | Tên chức năng cụ thể | Tính chất | Điểm thành phần | Ghi chú kỹ thuật |
| :--- | :--- | :---: | :---: | :--- |
| **1. Nhóm Xác thực người dùng** | **Tổng 2.25 điểm + 1 điểm dùng API** | | **3.25 đ** | |
| 1.1 | Đăng ký người dùng | Bắt buộc | 0.25 đ | API `POST /api/auth/register`, mã hóa mật khẩu, kiểm tra trùng username/email |
| 1.2 | Đăng nhập | Bắt buộc | 0.25 đ | API `POST /api/auth/login`, cấp token/session lưu SQLite/SharedPreferences |
| 1.3 | Đổi mật khẩu | Bắt buộc | 0.25 đ | API `POST /api/auth/change-password`, kiểm tra mật khẩu cũ |
| 1.4 | Quản lý member | Bắt buộc | 0.25 đ | Xem danh sách thành viên, cập nhật thông tin cá nhân |
| 1.5 | Quản lý role người dùng | Bắt buộc | 0.50 đ | Phân quyền vai trò trong SQL Server |
| 1.6 | Chức năng thoát (Logout) | Bắt buộc | 0.25 đ | Xóa session token trên thiết bị, hủy trạng thái đăng nhập |
| 1.7 | Phân quyền người dùng (Member & Admin) | Bắt buộc | 0.50 đ | Điều hướng giao diện theo Role (Admin vào trang quản trị, Staff/Member vào menu POS) |
| 1.8 | Xác thực người dùng qua Email | Điểm cộng | 0.50 đ | Gửi mã OTP xác thực email khi đăng ký hoặc kích hoạt tài khoản |
| 1.9 | Quên mật khẩu | Điểm cộng | 0.50 đ | Gửi email reset link/OTP để tạo mật khẩu mới |
| 1.10 | Đăng nhập bằng Gmail, Facebook, Zalo | Điểm cộng | 3 * 0.50 đ | OAuth2 / SDK tích hợp đăng nhập mạng xã hội (tối đa +1.5 đ) |
| **2. Quản lý Danh mục (Admin)** | **Tổng 1.25 điểm + 0.5 điểm dùng API** | | **1.75 đ** | |
| 2.1 | Hiển thị danh mục | Bắt buộc | 0.25 đ | API `GET /api/category`, hiển thị dạng List/Grid |
| 2.2 | Thêm danh mục | Bắt buộc | 0.25 đ | API `POST /api/category`, form nhập tên, mô tả, chọn ảnh |
| 2.3 | Xóa danh mục | Bắt buộc | 0.25 đ | API `DELETE /api/category/{id}` |
| 2.4 | Kiểm tra danh mục có sản phẩm trước khi xóa | Bắt buộc | 0.25 đ | Báo lỗi hoặc chặn xóa nếu danh mục đang chứa món ăn/uống |
| 2.5 | Sửa danh mục | Bắt buộc | 0.25 đ | API `PUT /api/category/{id}` cập nhật thông tin |
| 2.6 | Upload hình ảnh xử lý 3 trường hợp (Thêm, Xóa, Sửa) | Điểm cộng | 0.75 đ | Thêm: lưu ảnh mới vào wwwroot; Sửa: xóa ảnh cũ lưu ảnh mới; Xóa: xóa file vật lý |
| **3. Quản lý Sản phẩm theo Danh mục** | **Tổng 2.0 điểm + 0.75 điểm dùng API** | | **2.75 đ** | **Phải có upload file và phân trang** |
| 3.1 | Hiển thị sản phẩm có phân trang | Bắt buộc | 0.50 đ | API `GET /api/product?page=x&pageSize=y`, lazy loading / Pagination |
| 3.2 | Thêm sản phẩm (upload hình ảnh) | Bắt buộc | 0.50 đ | API `POST /api/product` hỗ trợ `multipart/form-data` hoặc lưu link ảnh |
| 3.3 | Xóa sản phẩm (xóa hình ảnh kèm theo) | Bắt buộc | 0.50 đ | API `DELETE /api/product/{id}`, dọn dẹp file ảnh trong server `wwwroot/products` |
| 3.4 | Sửa sản phẩm (nếu upload ảnh mới phải xóa ảnh cũ) | Bắt buộc | 0.50 đ | API `PUT /api/product/{id}`, ghi đè ảnh và dọn dẹp file rác |
| 3.5 | Kiểm tra sản phẩm có trong đơn hàng trước khi xóa | Điểm cộng | 0.50 đ | Ràng buộc khóa ngoại hoặc kiểm tra bảng `OrderDetail` trước khi xóa |
| **4. Hiển thị Sản phẩm trên Trang chủ** | **Tổng 1.75 điểm + 0.5 điểm dùng API** | | **2.25 đ** | |
| 4.1 | Hiển thị danh mục sản phẩm | Bắt buộc | 0.25 đ | Danh mục dạng ngang (horizontal chips / icons) trên trang chủ |
| 4.2 | Hiển thị sản phẩm mới nhất (có phân trang) | Bắt buộc | 0.50 đ | Danh sách món mới cập nhật, order by Id/Date DESC, có phân trang |
| 4.3 | Hiển thị sản phẩm theo danh mục (có phân trang) | Bắt buộc | 0.25 đ (+0.25 đ) | Chọn danh mục lọc danh sách sản phẩm tương ứng có phân trang |
| 4.4 | Tìm kiếm sản phẩm (có phân trang) | Bắt buộc | 0.25 đ (+0.25 đ) | Search bar tìm theo tên món/mô tả kèm phân trang kết quả |
| 4.5 | Hiển thị chi tiết sản phẩm | Bắt buộc | 0.25 đ | Màn hình chi tiết: hình lớn, giá, mô tả, nút thêm giỏ |
| 4.6 | Hiển thị sản phẩm liên quan (có phân trang) | Điểm cộng | 0.25 đ (+0.25 đ) | Gợi ý món cùng danh mục ở đáy màn hình chi tiết, có phân trang |
| **5. Quản lý Giỏ hàng & Đặt hàng** | **Tổng 2.5 điểm + 1 điểm dùng API** | | **3.50 đ** | |
| 5.1 | Đặt button "Thêm vào giỏ hàng" | Bắt buộc | 0.25 đ | Nút trực quan trên thẻ sản phẩm và trang chi tiết |
| 5.2 | Thêm sản phẩm vào giỏ hàng | Bắt buộc | 0.25 đ | Lưu vào SQLite cục bộ (hoặc API session/cart), cộng dồn số lượng |
| 5.3 | Hiển thị số lượng sản phẩm trên icon giỏ hàng | Bắt buộc | 0.25 đ | Badge số lượng realtime trên AppBar icon |
| 5.4 | Hiển thị giỏ hàng | Bắt buộc | 0.25 đ | Danh sách món đã chọn, đơn giá, số lượng, thành tiền, tổng tiền |
| 5.5 | Cập nhật số lượng trên giỏ hàng | Bắt buộc | 0.50 đ | Nút `+` và `-` tăng giảm số lượng, tính toán lại tổng tiền tức thì |
| 5.6 | Xóa sản phẩm trên giỏ hàng | Bắt buộc | 0.25 đ | Nút xóa hoặc vuốt xóa (Dismissible) |
| 5.7 | Chức năng đặt hàng (Checkout) | Bắt buộc | 0.50 đ | Form xác nhận đặt bàn/địa chỉ/ghi chú, gửi lên API `POST /api/order` |
| 5.8 | Chức năng hiển thị chi tiết đơn hàng | Bắt buộc | 0.25 đ | Mã đơn, danh sách món, trạng thái thanh toán, tổng tiền |
| 5.9 | Chức năng tìm kiếm đơn hàng | Điểm cộng | 0.25 đ | Tìm kiếm theo mã đơn hàng hoặc số điện thoại |
| 5.10 | Chức năng thanh toán online VNPay, VietQR | Điểm cộng | 2 * 0.50 đ | Tích hợp cổng VNPayment và tạo mã VietQR động thanh toán (+1.0 đ) |
| **6. Quản lý Đơn hàng (Admin)** | **Tổng 0.75 điểm + 0.25 điểm dùng API** | | **1.00 đ** | |
| 6.1 | Hiển thị danh sách đơn hàng | Bắt buộc | 0.25 đ | Dashboard xem toàn bộ order của quán theo thời gian thực |
| 6.2 | Cập nhật trạng thái đơn hàng | Bắt buộc | 0.50 đ | Chuyển đổi trạng thái (Chờ xác nhận -> Đang pha chế/nấu -> Hoàn thành -> Đã thanh toán -> Đã hủy) |
| 6.3 | Tìm kiếm đơn hàng (Admin) | Điểm cộng | 0.25 đ | Tìm theo mã đơn, tên khách, bàn |
| 6.4 | Lọc đơn hàng theo ngày | Điểm cộng | 0.25 đ | DatePicker chọn khoảng ngày xem doanh thu và danh sách đơn |

---

## III. NGUYÊN TẮC GIẢI TRÌNH ĐIỂM TƯƠNG ĐƯƠNG VỚI GIẢNG VIÊN
Theo quy định đề bài: *"Ngoài các chức năng trên sinh viên phải giải trình để tính theo điểm chức năng tương đương"*.
Dự án sẽ chuẩn bị bảng đối chiếu đối với các đặc thù của Nhà hàng / Cà phê:
1. **Quản lý Bàn ăn / Khu vực (Table & Floor Management)** $\Leftrightarrow$ Tính năng tương đương cấp cao của Quản lý Danh mục & Phân quyền không gian.
2. **Màn hình Bếp/Bar (KDS - Kitchen Display System)** $\Leftrightarrow$ Tính năng tương đương cấp cao của Trạng thái đơn hàng thời gian thực.
3. **In hóa đơn tạm tính / hóa đơn nhiệt ESC/POS** $\Leftrightarrow$ Tính năng tương đương của Xuất phiếu đơn hàng.
4. **Đồng bộ hóa ngoại tuyến (Offline SQLite First)** $\Leftrightarrow$ Đảm bảo khi mất kết nối mạng quán cafe vẫn có thể bấm order, lưu SQLite và đẩy lên SQL Server khi có mạng trở lại.
