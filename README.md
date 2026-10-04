# 🍽️ Restaurant & Coffee POS System

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-3.47.1-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13.1-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![.NET Core](https://img.shields.io/badge/.NET_Core-10.0-512BD4?logo=dotnet&logoColor=white)](https://dotnet.microsoft.com)
[![SQL Server](https://img.shields.io/badge/Database-SQL_Server_2022-CC292B?logo=microsoftsqlserver&logoColor=white)](https://www.microsoft.com/sql-server)
[![SQLite](https://img.shields.io/badge/Local_DB-SQLite_3-003B57?logo=sqlite&logoColor=white)](https://www.sqlite.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Hệ thống Quản lý Bán hàng, Gọi món & Phục vụ Toàn diện cho Nhà hàng & Quán Cà phê**

*Kiến trúc Đa nền tảng: Mobile App (Flutter + SQLite Offline-First) kết nối Backend REST API (C# ASP.NET Core 10 + Microsoft SQL Server)*

</div>

---

## 📌 1. Giới Thiệu Dự Án (Project Overview)

**Restaurant & Coffee POS** là giải pháp công nghệ toàn diện dành cho các mô hình kinh doanh F&B (Food & Beverage), từ quán cà phê nhỏ, trà sữa đến chuỗi nhà hàng ẩm thực. Ứng dụng hỗ trợ nhân viên phục vụ ghi order trực tiếp tại bàn bằng thiết bị di động, điều phối tự động xuống màn hình bếp/bar (KDS), đồng bộ ngoại tuyến khi mất kết nối mạng và hỗ trợ thanh toán đa kênh (Tiền mặt, VietQR NAPAS 247, VNPayment).

Dự án được xây dựng theo chuẩn **Monorepo** với 3 phân vùng chính:
- **`mobile/`**: Ứng dụng di động Flutter (Dart), lưu trữ cục bộ SQLite (`sqflite`), áp dụng Repository Pattern và StatefulWidget chuẩn mực.
- **`backend/`**: Hệ thống RESTful API viết bằng C# ASP.NET Core 10 (`net10.0`), Entity Framework Core, áp dụng Provider & Repository Pattern (Unit of Work).
- **`docs/`**: Hệ thống tài liệu đặc tả nghiệp vụ, biểu đồ luồng Mermaid, sổ tay hướng dẫn cộng tác (`TAI_LIEU_HUONG_DAN_COLLABORATOR_FULL.docx`), và script CSDL `RestaurantPosDb.sql`.

---

## ✨ 2. Tính Năng Nổi Bật (Key Features)

### 🔐 A. Nhóm Xác Thực & Phân Quyền (Authentication & RBAC)
- **Đăng ký / Đăng nhập / Đổi mật khẩu:** Mã hóa mật khẩu bảo mật (SHA-256 / BCrypt), sinh JWT/Session token lưu vào SQLite.
- **Phân quyền người dùng:** Điều hướng thông minh dựa trên vai trò (Admin vào Dashboard quản trị, Staff/Waiter vào POS bán hàng).
- **Xác thực mở rộng:** Xác thực email kích hoạt qua mã OTP, quên mật khẩu và tích hợp đăng nhập mạng xã hội (Google, Facebook, Zalo).

### 📋 B. Quản Lý Danh Mục & Sản Phẩm (Catalog Management)
- **Quản lý Danh mục (Admin):** Thêm, sửa, xóa danh mục. **Kiểm tra ràng buộc:** Chặn xóa nếu danh mục đang chứa món ăn/uống.
- **Upload hình ảnh 3 trường hợp:** Tự động lưu ảnh vào `wwwroot/images`, dọn dẹp xóa file ảnh cũ khi cập nhật và xóa ảnh vật lý khi xóa món.
- **Quản lý Sản phẩm theo Danh mục:** Tìm kiếm và hiển thị phân trang (Pagination) mượt mà bằng kỹ thuật Lazy Loading.
- **Kiểm tra lịch sử hóa đơn:** Chặn xóa sản phẩm nếu đã phát sinh trong đơn hàng nhằm bảo toàn dữ liệu kế toán.

### 📱 C. Trang Chủ & Trải Nghiệm Người Dùng (Home Showcase)
- **Hiển thị trực quan:** Thanh ngang danh mục, danh sách món mới nhất có phân trang, lọc sản phẩm theo từng danh mục.
- **Tìm kiếm thông minh:** Search bar tìm kiếm theo tên món hoặc mô tả có phân trang.
- **Chi tiết & Gợi ý:** Xem chi tiết hình ảnh, đơn giá, mô tả và danh sách **Sản phẩm liên quan** cùng danh mục.

### 🛒 D. Quản Lý Giỏ Hàng & Đặt Hàng (Cart & Checkout)
- **Offline-First với SQLite:** Lưu trữ giỏ hàng trong bảng SQLite `cart_items` trên máy. Tắt ứng dụng mở lại vẫn bảo toàn nguyên vẹn.
- **Badge giỏ hàng thời gian thực:** Hiển thị tổng số lượng món tức thì trên AppBar.
- **Điều chỉnh giỏ hàng:** Nút `+` và `-` tăng giảm số lượng, tính toán lại tổng tiền giỏ hàng ngay lập tức.
- **Đặt hàng (Checkout):** Chọn bàn ăn hoặc mang về, gửi đơn lên API, lưu vào SQL Server và cập nhật trạng thái bàn.
- **Thanh toán trực tuyến:** Tích hợp sinh mã **VietQR NAPAS 247** động và cổng thanh toán **VNPayment Sandbox**.

### 📊 E. Quản Lý Đơn Hàng & Tính Năng Mở Rộng F&B
- **Quản lý Đơn hàng (Admin):** Theo dõi đơn hàng theo thời gian thực, cập nhật trạng thái (Mới $\rightarrow$ Đang nấu $\rightarrow$ Đã phục vụ $\rightarrow$ Hoàn thành).
- **Bộ lọc doanh thu:** Lọc đơn hàng theo khoảng ngày (`DateRangePicker`) và tìm kiếm theo mã đơn.
- **Sơ đồ Bàn & Khu vực (Floor/Table Map):** Hiển thị trực quan bàn trống (Xanh), bàn có khách (Đỏ), bàn đặt trước (Vàng), chuyển và gộp bàn.
- **Màn hình Bếp (Kitchen Display System - KDS):** Màn hình riêng cho đầu bếp nhận order và bấm chuyển trạng thái món.

---

## 🏗️ 3. Cấu Trúc Thư Mục Dự Án (Monorepo Directory Structure)

```
restaurant_pos_app/
├── mobile/                                 # Ứng dụng di động Flutter
│   ├── lib/
│   │   ├── models/                         # Thực thể dữ liệu (Category, Product, Cart...)
│   │   ├── repositories/                   # Tầng giao tiếp mạng http & SQLite
│   │   ├── utils/database_helper.dart      # Singleton SQLite Database Helper
│   │   ├── views/                          # Giao diện UI người dùng
│   │   └── main.dart                       # Điểm khởi chạy ứng dụng
│   ├── pubspec.yaml                        # Dependencies (http, sqflite, path, intl...)
│   └── test/widget_test.dart               # Unit test kiểm thử mô hình dữ liệu
│
├── backend/                                # REST API ASP.NET Core 10
│   ├── Api/Controllers/                    # BaseController, CategoryController...
│   ├── Models/                             # DbContext, BaseProvider, BaseRepository, SiteProvider
│   ├── Services/Helper.cs                  # Helper xử lý upload & xóa ảnh wwwroot
│   ├── wwwroot/images/                     # Thư mục lưu ảnh danh mục và sản phẩm
│   ├── appsettings.json                    # Cấu hình chuỗi kết nối SQL Server
│   └── Program.cs                          # Cấu hình CORS AllowAll, DbContext & DI
│
├── docs/                                   # Hệ thống tài liệu kỹ thuật & Barem
│   ├── 01_YEU_CAU_CUNG_VA_BAREM_DIEM.md    # Barem chấm điểm chi tiết
│   ├── 02_CHUC_NANG_MO_RONG_DANG_LAM.md    # Đặc tả tính năng F&B mở rộng
│   ├── 03_LUONG_HOAT_DONG_CHI_TIET.md      # Luồng xử lý Frontend - Backend - Database
│   ├── 04_THIET_KE_CO_SO_DU_LIEU_MERMAID.md# ERD CSDL Mermaid & Script T-SQL
│   ├── 05_MERMAID_SEQUENCE_FLOWS.md        # 7 Sơ đồ tuần tự Mermaid chi tiết
│   ├── 06_KE_HOACH_PHAN_CHIA_PHASE_CONG_VIEC.md # 6 Phase triển khai công việc
│   ├── TAI_LIEU_HUONG_DAN_COLLABORATOR_FULL.docx # File Word hướng dẫn chuẩn học thuật
│   └── RestaurantPosDb.sql                 # Script SQL Server 10 bảng (10 dòng/bảng)
│
├── RestaurantPosDb.sql                     # Script CSDL SQL Server gốc tại root
└── README.md                               # Tài liệu hướng dẫn cài đặt & tổng quan
```

---

## 🗄️ 4. Thiết Kế Cơ Sở Dữ Liệu (Database Architecture)

Cơ sở dữ liệu được chuẩn hóa cao độ với 10 bảng thực thể quan hệ trên Microsoft SQL Server và 4 bảng cục bộ trên SQLite điện thoại:

```
[Roles] ──< [Accounts] ──< [Orders] >── [DiningTables] >── [Areas]
                                │
                        [OrderDetails] >── [Products] >── [Categories]
                                │               │
                    [OrderDetailModifiers]  [ProductAttributes]
                                │
                            [Payments]
```

### 10 Bảng dữ liệu trên SQL Server (`RestaurantPosDb.sql`):
1. **`Roles`**: Vai trò người dùng (Admin, Manager, Cashier, Barista, Chef, Waiter, Member...).
2. **`Accounts`**: Tài khoản, băm mật khẩu, thông tin cá nhân, cờ xác thực email, OAuth social token.
3. **`Areas`**: Khu vực trong quán (Tầng trệt máy lạnh, Ban công, Sân vườn, Phòng VIP 1, Phòng VIP 2...).
4. **`DiningTables`**: Bàn ăn (Mã bàn, sức chứa, trạng thái: Trống, Có khách, Chờ món, Đã đặt).
5. **`Categories`**: Danh mục món (Cà phê phin, Cà phê máy, Trà trái cây, Trà sữa, Đá xay, Bánh ngọt...).
6. **`Products`**: Thực đơn sản phẩm (Tên món, đơn giá VNĐ, đơn vị tính, ảnh, trạng thái còn/hết hàng).
7. **`ProductAttributes`**: Tùy biến món ăn (Size M/L, Đường, Đá, Topping trân châu, Kem cheese...).
8. **`Orders`**: Hóa đơn đặt món (Mã đơn ORD-XXXX, mã bàn, loại đơn DineIn/Takeaway, tổng tiền, trạng thái).
9. **`OrderDetails`**: Chi tiết từng món trong đơn, ghi chú riêng, trạng thái nấu KDS (Chờ nấu, Đang làm, Xong).
10. **`Payments`**: Giao dịch thanh toán (Tiền mặt, VietQR NAPAS 247, VNPayment).

---

## 🚀 5. Hướng Dẫn Cài Đặt & Khởi Chạy (Getting Started)

### Yêu cầu tiên quyết (Prerequisites)
- **.NET SDK**: Phiên bản 10.0 (`dotnet --version` hiển thị `10.0.xxx`).
- **Flutter SDK**: Phiên bản 3.x (`flutter --version`).
- **Database**: Microsoft SQL Server 2019/2022 và công cụ SQL Server Management Studio (SSMS).

---

### Bước 1: Khởi tạo Cơ sở dữ liệu SQL Server
1. Mở phần mềm **SSMS (SQL Server Management Studio)** và kết nối tới SQL Server Localhost.
2. Mở file [`RestaurantPosDb.sql`](RestaurantPosDb.sql) tại thư mục gốc dự án.
3. Bấm **Execute (F5)** để thực thi. Hệ thống sẽ tự động tạo CSDL `RestaurantPosDb`, 10 bảng quan hệ và nạp sẵn đúng 10 dòng dữ liệu mẫu chuẩn thực tế.

---

### Bước 2: Khởi chạy Backend ASP.NET Core 10 Web API
1. Mở cửa sổ dòng lệnh tại thư mục `backend/`:
   ```bash
   cd backend
   ```
2. Phục hồi dependencies và kiểm tra build:
   ```bash
   dotnet restore
   dotnet build
   ```
3. Khởi chạy Web API trên cổng `5138`:
   ```bash
   dotnet run --urls "http://localhost:5138"
   ```
4. Kiểm tra endpoint danh mục hoạt động trên trình duyệt:
   ```
   http://localhost:5138/api/category
   ```

---

### Bước 3: Khởi chạy Ứng dụng Mobile Flutter
1. Mở cửa sổ dòng lệnh tại thư mục `mobile/`:
   ```bash
   cd mobile
   ```
2. Cài đặt các gói thư viện:
   ```bash
   flutter pub get
   ```
3. Kiểm tra tính toàn vẹn mã nguồn:
   ```bash
   flutter analyze
   flutter test
   ```
4. Khởi chạy ứng dụng:
   ```bash
   # Chạy trên máy ảo / máy thật Android hoặc Windows Desktop
   flutter run
   ```

> 💡 **Mẹo kết nối mạng:**
> - Khi chạy trên **máy ảo Android Emulator**, đổi `localhost` thành `http://10.0.2.2:5138/api/...` để máy ảo truy cập được Web API trên máy chủ tính.
> - Khi chạy trên **Windows Desktop / Chrome / iOS Simulator**, dùng trực tiếp `http://localhost:5138/api/...`.

---

## 📡 6. Bảng Tra Cứu API Endpoints (API Reference)

| Phương thức | Đường dẫn API (Endpoint) | Mục đích nghiệp vụ | Quyền truy cập |
| :---: | :--- | :--- | :---: |
| `POST` | `/api/auth/register` | Đăng ký tài khoản người dùng mới | Public |
| `POST` | `/api/auth/login` | Đăng nhập hệ thống, cấp token | Public |
| `POST` | `/api/auth/change-password` | Đổi mật khẩu tài khoản | Authenticated |
| `GET` | `/api/category` | Lấy danh sách toàn bộ danh mục | Public |
| `POST` | `/api/category` | Thêm danh mục mới (hỗ trợ upload file ảnh) | Admin |
| `PUT` | `/api/category/{id}` | Cập nhật danh mục (xóa ảnh cũ lưu ảnh mới) | Admin |
| `DELETE` | `/api/category/{id}` | Xóa danh mục (chặn xóa nếu có sản phẩm) | Admin |
| `GET` | `/api/product?page=1&pageSize=10` | Lấy danh sách sản phẩm có phân trang | Public |
| `POST` | `/api/product` | Thêm sản phẩm mới (upload ảnh) | Admin |
| `PUT` | `/api/product/{id}` | Cập nhật sản phẩm | Admin |
| `DELETE` | `/api/product/{id}` | Xóa sản phẩm (chặn xóa nếu có trong đơn) | Admin |
| `POST` | `/api/order` | Đặt hàng (Checkout từ giỏ hàng SQLite) | Staff / Member |
| `GET` | `/api/order/admin?fromDate=...` | Quản lý danh sách đơn hàng, lọc theo ngày | Admin / Cashier |
| `PUT` | `/api/order/{id}/status` | Cập nhật trạng thái đơn hàng (KDS) | Admin / Chef |
| `POST` | `/api/payment/confirm` | Xác nhận thanh toán (Cash / VietQR / VNPay) | Cashier |

---

## 👥 7. Đóng Góp & Hướng Dẫn Collaborator

Vui lòng tham khảo sổ tay hướng dẫn chi tiết dành cho lập trình viên tại:
- [06_KE_HOACH_PHAN_CHIA_PHASE_CONG_VIEC.md](docs/06_KE_HOACH_PHAN_CHIA_PHASE_CONG_VIEC.md)
- [TAI_LIEU_HUONG_DAN_COLLABORATOR_FULL.docx](docs/TAI_LIEU_HUONG_DAN_COLLABORATOR_FULL.docx)

Mọi thay đổi mã nguồn cần tuân thủ quy trình kiểm thử:
```bash
cd mobile && flutter analyze && flutter test
cd ../backend && dotnet build
```

---

## 📄 8. Bản Quyền (License)

Dự án được phân phối dưới giấy phép **MIT License**. Mọi quyền được bảo lưu bởi nhóm phát triển sinh viên.
