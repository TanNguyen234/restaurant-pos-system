# Restaurant & Cafe POS System (F&B Enterprise Solution)

A production-grade, multi-platform Point of Sale (POS), Floor Map, and Table-Service Management System engineered for modern restaurants and cafes. Built as an offline-resilient monorepo comprising a Flutter mobile client with on-device SQLite persistent caching, backed by an ASP.NET Core 10 RESTful API and Microsoft SQL Server.

---

## Architecture Overview

The system adheres to an offline-first, 4-tier provider/repository architecture designed for high availability and low-latency POS workflows:

```
[ Mobile Client (Flutter 3.47 / Dart 3.13) ]
  +-- Presentation Layer (StatefulWidget / FloorTablePage / CartPage / CategoryPage)
  +-- Local Storage (SQLite via DatabaseHelper)
  |     +-- user_session     --> Persistent authentication state
  |     +-- cart_items       --> Offline cart with atomic amount summation
  |     +-- offline_orders   --> Pending sync queue for network dropouts
  +-- Service Layer (OfflineSyncService) --> Periodic / On-demand cloud synchronization
  +-- Repository Layer (TableRepository, CategoryRepository via HTTP Client)
            |
            | RESTful JSON over HTTP / HTTPS
            v
[ Backend API (ASP.NET Core 10 Web API) ]
  +-- Presentation Layer (BaseController, TableController, CategoryController)
  +-- Facade / Aggregator Layer (SiteProvider / BaseProvider)
  +-- Data Access Layer (BaseRepository / TableRepository / CategoryRepository)
  +-- Media Processing (wwwroot/images for product and category assets)
            |
            | Entity Framework Core 10 (Microsoft.EntityFrameworkCore.SqlServer)
            v
[ Relational Database (Microsoft SQL Server) ]
  +-- 10 Normalized Relational Tables (Roles, Accounts, Areas, DiningTables,
       Categories, Products, ProductAttributes, Orders, OrderDetails, Payments)
```

---

## Technology Stack

| Component | Technology | Version | Purpose |
| :--- | :--- | :--- | :--- |
| **Mobile Client** | Flutter / Dart | 3.47.1 / 3.13.1 | Cross-platform staff ordering terminal, floor map, and POS client |
| **Local Database** | SQLite (sqflite) | 2.4.2 | On-device persistent cart, local session, and offline order queue |
| **Backend API** | ASP.NET Core Web API | 10.0 (net10.0) | Centralized business logic, REST controllers, and transactions |
| **ORM** | Entity Framework Core | 10.0.12 | Object-relational mapping for SQL Server |
| **Central Database** | Microsoft SQL Server | 2019 / 2022 | Primary ACID-compliant transactional datastore (10 tables in 3NF) |
| **Online Payments** | VietQR / VNPayment | NAPAS 247 / v2 | Dynamic banking QR codes and payment gateway integration |

---

## Team Responsibility Matrix (Bảng Phân Công Nhiệm Vụ Nhóm 3 Người)

Dự án được phân bổ trách nhiệm rõ ràng theo [docs/07_BANG_PHAN_CONG_NHOM_3_NGUOI.md](docs/07_BANG_PHAN_CONG_NHOM_3_NGUOI.md) nhằm tối đa hóa điểm số barem (10/10 điểm gốc + điểm cộng mở rộng) và ngăn ngừa xung đột mã nguồn:

### Thành viên 1: Team Leader & Fullstack Architect (100% Hoàn Thành)

| STT | Hạng mục / File mã nguồn | Mô tả chi tiết chức năng | Trạng thái |
| :---: | :--- | :--- | :---: |
| 1 | `RestaurantPosDb.sql` | Khởi tạo CSDL 10 bảng quan hệ chuẩn 3NF, Foreign Keys, Index tối ưu và seed sẵn 10 dòng/bảng. | **Hoàn thành 100%** |
| 2 | `backend/Models/RestaurantPosContext.cs` | DbContext đồng bộ toàn diện 10 thực thể: `Area`, `DiningTable`, `Category`, `Product`, `Order`, `OrderDetail`, `Account`, `Role`, `Payment`, `ProductAttribute`. | **Hoàn thành 100%** |
| 3 | `backend/Models/BaseProvider.cs`, `BaseRepository.cs`, `SiteProvider.cs` | Kiến trúc Facade / Provider chuẩn hóa; đăng ký lazy `TableRepository` vào `SiteProvider`. | **Hoàn thành 100%** |
| 4 | `backend/Api/Controllers/BaseController.cs` | Base Controller cung cấp Provider dùng chung cho toàn bộ controllers. | **Hoàn thành 100%** |
| 5 | `backend/Models/TableRepository.cs` & `TableController.cs` | RESTful API Sơ đồ bàn: Lấy danh sách khu vực (`/api/table/areas`), lấy bàn theo khu vực (`/api/table/by-area/{id}`), lấy toàn bộ bàn (`/api/table`), cập nhật trạng thái bàn (`/api/table/{id}/status`), và giao dịch chuyển bàn an toàn (`/api/table/transfer`). | **Hoàn thành 100%** |
| 6 | `mobile/lib/utils/database_helper.dart` | Singleton SQLite quản lý 3 bảng: `user_session` (lưu phiên đăng nhập), `cart_items` (giỏ hàng tính tổng tức thì), `offline_orders` (hàng đợi đơn ngoại tuyến). | **Hoàn thành 100%** |
| 7 | `mobile/lib/views/table/floor_table_page.dart` | Giao diện Sơ đồ bàn ăn F&B chuyên nghiệp: Phân chia khu vực qua TabBar (Tầng trệt, Tầng 1, Sân vườn, Phòng VIP), thẻ bàn dạng GridView đổi màu theo trạng thái (Xanh = Trống, Đỏ = Có khách, Cam = Đã đặt), chuyển trạng thái nhanh và modal chuyển bàn trực quan. | **Hoàn thành 100%** |
| 8 | `mobile/lib/services/offline_sync_service.dart` | Engine kiểm tra mạng định kỳ / theo yêu cầu, quét đơn hàng chưa đồng bộ từ SQLite `offline_orders` đẩy lên Backend API và cập nhật cờ `is_synced`. | **Hoàn thành 100%** |
| 9 | `mobile/lib/main.dart` | Điều hướng NavigationBar chuẩn F&B kết nối Sơ đồ bàn, Quản lý thực đơn và Giỏ hàng. | **Hoàn thành 100%** |
| 10 | Automated Test Suites (35/35 Tests) | Bộ kiểm thử toàn diện: `widget_test.dart`, `database_helper_test.dart`, `table_model_test.dart`, `table_repository_test.dart`, `floor_table_challenge_test.dart`, `empirical_challenge_test.dart`. | **Hoàn thành 100%** |

### Thành viên 2: Frontend & Catalog Specialist (Collaborator A)
- `backend/Services/Helper.cs`: Lưu và dọn dẹp file ảnh trong `wwwroot/images`.
- `backend/Models/CategoryRepository.cs` & `ProductRepository.cs`: Xử lý phân trang và kiểm tra ràng buộc toàn vẹn khi xóa (không xóa danh mục có sản phẩm, không xóa sản phẩm đã có đơn hàng).
- `mobile/lib/views/home_page.dart`, `product_detail_page.dart`, `cart_page.dart`, `admin_category_page.dart`, `admin_product_page.dart`.

### Thành viên 3: Backend & Security Specialist (Collaborator B)
- `backend/Models/AccountRepository.cs` & `AuthController.cs`: Đăng ký, đăng nhập băm mật khẩu, đổi mật khẩu, phân quyền Role.
- `backend/Models/OrderRepository.cs` & `PaymentRepository.cs`: Giao dịch tạo đơn hàng, quản lý đơn Admin, sinh mã VietQR động và tạo URL VNPay Sandbox.
- `mobile/lib/views/auth/login_page.dart`, `order_checkout_page.dart`, `order_detail_page.dart`, `kitchen_display_page.dart`.

---

## Database Architecture

Hệ thống triển khai CSDL quan hệ trên Microsoft SQL Server theo tệp kịch bản [RestaurantPosDb.sql](RestaurantPosDb.sql) với 10 bảng chuẩn hóa 3NF:

```
Roles (1) <--- Accounts (N)
                 |
Areas (1) <-- DiningTables (N)
                 |
                 +---< Orders (1) <--- OrderDetails (N) ---> Products (1) ---> Categories (1)
                         |                  |                   |
                         |                  |                   +---< ProductAttributes (N)
                         |                  +---< OrderDetailModifiers (N)
                         |
                         +---< Payments (N)
```

### Table Dictionary

| Table | Primary Key | Description | Records Seeded |
| :--- | :--- | :--- | :---: |
| `Roles` | `RoleId` | Phân quyền truy cập hệ thống (Admin, Manager, Cashier, Waiter, Barista, Chef, Member, VIP) | 10 |
| `Accounts` | `AccountId` | Tài khoản nhân viên/khách hàng, mật khẩu băm, token xác thực, OAuth providers | 10 |
| `Areas` | `AreaId` | Khu vực nhà hàng (Tầng trệt máy lạnh, Tầng 1 ban công, Sân vườn ngoài trời, Phòng VIP) | 10 |
| `DiningTables` | `TableId` | Bàn ăn, số ghế (Capacity), trạng thái thời gian thực (0: Trống, 1: Có khách, 2: Đã đặt) | 10 |
| `Categories` | `CategoryId` | Phân loại thực đơn (Cà phê Việt, Espresso & Ý, Trà trái cây, Bánh ngọt, Điểm tâm) | 10 |
| `Products` | `ProductId` | Món ăn / đồ uống, đơn giá VND, đơn vị tính, hình ảnh, cờ kích hoạt | 10 |
| `ProductAttributes` | `AttributeId` | Thuộc tính món: Size (M/L), mức đường (30%/50%/100%), mức đá, topping | 10 |
| `Orders` | `OrderId` | Đơn hàng gắn với Bàn, tổng tiền, chiết khấu, trạng thái đơn (Mới -> Chế biến -> Đã phục vụ -> Hoàn thành) | 10 |
| `OrderDetails` | `OrderDetailId` | Chi tiết món trong đơn, số lượng, đơn giá, ghi chú món cho bếp, trạng thái nấu | 10 |
| `Payments` | `PaymentId` | Thanh toán hóa đơn bằng Tiền mặt, chuyển khoản VietQR NAPAS 247 hoặc cổng VNPay | 10 |

---

## Directory Layout

```
restaurant_pos_app/
+-- RestaurantPosDb.sql                     # Script DDL & DML hoàn chỉnh 10 bảng SQL Server
+-- PROJECT.md                              # Bảng đặc tả tính năng & lộ trình Milestone 1-3
+-- README.md                               # Tài liệu hướng dẫn kỹ thuật toàn diện
+-- backend/                                # ASP.NET Core 10 Web API (net10.0)
|   +-- Api/
|   |   +-- Controllers/
|   |       +-- BaseController.cs           # Controller cơ sở cung cấp SiteProvider
|   |       +-- TableController.cs          # API Quản lý Sơ đồ bàn, Trạng thái & Chuyển bàn
|   |       +-- CategoryController.cs       # API Quản lý Danh mục món
|   +-- Models/
|   |   +-- RestaurantPosContext.cs         # EF Core DbContext 10 bảng quan hệ
|   |   +-- BaseProvider.cs                 # Base provider quản lý HttpContext & DbContext
|   |   +-- SiteProvider.cs                 # Provider facade tích hợp Category & Table repositories
|   |   +-- BaseRepository.cs               # Base data access layer
|   |   +-- TableRepository.cs              # Truy vấn Khu vực, Bàn & Transaction chuyển bàn
|   |   +-- CategoryRepository.cs           # Truy vấn Danh mục & kiểm tra ràng buộc xóa
|   +-- Services/
|   |   +-- Helper.cs                       # Tiện ích upload & dọn dẹp file ảnh wwwroot
|   +-- wwwroot/images/                     # Thư mục lưu trữ hình ảnh tĩnh
|   +-- appsettings.json                    # Connection strings & Logging
|   +-- Program.cs                          # Cấu hình DI, CORS policy, JSON serialization & Pipeline
|   +-- WebApi.csproj                       # Dự án .NET 10 Web API
+-- mobile/                                 # Ứng dụng Flutter Mobile Client
|   +-- lib/
|   |   +-- models/
|   |   |   +-- area.dart                   # Thực thể Khu vực (Area DTO)
|   |   |   +-- dining_table.dart           # Thực thể Bàn ăn (DiningTable DTO)
|   |   |   +-- category.dart               # Thực thể Danh mục (Category DTO)
|   |   +-- repositories/
|   |   |   +-- table_repository.dart       # HTTP client sơ đồ bàn kèm cơ chế Offline Fallback
|   |   |   +-- category_repository.dart    # HTTP client danh mục sản phẩm
|   |   +-- services/
|   |   |   +-- offline_sync_service.dart   # Engine đồng bộ đơn hàng ngoại tuyến SQLite -> Backend
|   |   +-- utils/
|   |   |   +-- database_helper.dart        # Singleton SQLite (user_session, cart_items, offline_orders)
|   |   +-- views/
|   |   |   +-- table/
|   |   |   |   +-- floor_table_page.dart   # Giao diện Sơ đồ bàn theo Tab khu vực & Đổi màu bàn
|   |   |   +-- category_page.dart          # Giao diện Danh mục món
|   |   +-- main.dart                       # Khởi chạy ứng dụng, F&B theme & NavigationBar
|   +-- pubspec.yaml                        # Thư viện Flutter (http, sqflite, path, intl)
|   +-- test/                               # Bộ kiểm thử tự động
|       +-- widget_test.dart                # Kiểm thử giao diện và tích hợp
|       +-- database_helper_test.dart       # Kiểm thử các thao tác SQLite (Session, Cart, Offline Orders)
|       +-- table_model_test.dart           # Kiểm thử serialization Area & DiningTable
|       +-- table_repository_test.dart      # Kiểm thử TableRepository & Offline fallback
|       +-- floor_table_challenge_test.dart # Kiểm thử các trường hợp biên của Sơ đồ bàn
|       +-- empirical_challenge_test.dart   # Kiểm thử thực nghiệm đồng bộ ngoại tuyến & xử lý sự cố
+-- docs/                                   # Bộ tài liệu đặc tả và hướng dẫn chi tiết
    +-- 01_YEU_CAU_CUNG_VA_BAREM_DIEM.md
    +-- 02_CHUC_NANG_MO_RONG_DANG_LAM.md
    +-- 03_LUONG_HOAT_DONG_CHI_TIET.md
    +-- 04_THIET_KE_CO_SO_DU_LIEU_MERMAID.md
    +-- 05_MERMAID_SEQUENCE_FLOWS.md
    +-- 06_KE_HOACH_PHAN_CHIA_PHASE_CONG_VIEC.md
    +-- 07_BANG_PHAN_CONG_NHOM_3_NGUOI.md
    +-- TAI_LIEU_HUONG_DAN_COLLABORATOR_FULL.docx
```

---

## REST API Reference

### 1. Quản lý Sơ đồ Bàn & Khu vực (Floor & Table Management - Thành viên 1)

| Phương thức | Endpoint | Mô tả nghiệp vụ | Tham số / Body | Mã phản hồi |
| :--- | :--- | :--- | :--- | :--- |
| `GET` | `/api/table/areas` | Lấy danh sách toàn bộ các khu vực đang hoạt động | Không có | `200 OK` (Danh sách Area) |
| `GET` | `/api/table/by-area/{areaId}` | Lấy danh sách bàn theo mã khu vực cụ thể | `areaId` (int) | `200 OK` (Danh sách DiningTable) |
| `GET` | `/api/table` | Lấy toàn bộ danh sách bàn kèm trạng thái trong nhà hàng | Không có | `200 OK` (Danh sách DiningTable) |
| `GET` | `/api/table/{id}` | Lấy thông tin chi tiết của một bàn theo mã bàn | `id` (int) | `200 OK` / `404 Not Found` |
| `PUT` | `/api/table/{id}/status` | Cập nhật trạng thái bàn (0: Trống, 1: Có khách, 2: Đã đặt) | `id` (int), Body: `{"status": 1}` | `200 OK` / `400 Bad Request` |
| `POST` | `/api/table/transfer` | Thực hiện giao dịch chuyển bàn từ bàn nguồn sang bàn đích | Body: `{"fromTableId": 1, "toTableId": 2}` | `200 OK` / `400 Bad Request` |

### 2. Quản lý Danh mục (Category Management - Thành viên 2)

| Phương thức | Endpoint | Mô tả nghiệp vụ | Quyền hạn |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/category` | Lấy danh sách danh mục thực đơn | Public |
| `POST` | `/api/category` | Thêm danh mục mới kèm upload ảnh | Admin |
| `PUT` | `/api/category/{id}` | Cập nhật danh mục và thay thế ảnh | Admin |
| `DELETE` | `/api/category/{id}` | Xóa danh mục (chặn nếu còn sản phẩm) | Admin |

### 3. Đơn hàng & Thanh toán (Order & Payment Management - Thành viên 3)

| Phương thức | Endpoint | Mô tả nghiệp vụ | Quyền hạn |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/order` | Tạo đơn hàng mới từ giỏ hàng client | Staff / Member |
| `GET` | `/api/order/admin` | Quản trị đơn hàng kèm bộ lọc ngày và trạng thái | Admin / Cashier |
| `PUT` | `/api/order/{id}/status` | Chuyển đổi trạng thái đơn và món ăn trong bếp | Staff / Chef |
| `POST` | `/api/payment/confirm` | Xác nhận thanh toán (Tiền mặt, VietQR, VNPay) | Cashier |

---

## Hướng Dẫn Cài Đặt & Khởi Chạy (Getting Started)

### Yêu cầu môi trường
- **.NET SDK:** 10.0 (`dotnet --version` >= 10.0.100)
- **Flutter SDK:** 3.47 (`flutter --version` >= 3.47.1, Dart >= 3.13.1)
- **Microsoft SQL Server:** 2019 / 2022 và SQL Server Management Studio (SSMS)

---

### Bước 1: Khởi tạo Cơ sở dữ liệu SQL Server

1. Mở SSMS hoặc terminal `sqlcmd`, kết nối đến instance SQL Server của bạn.
2. Mở file [RestaurantPosDb.sql](RestaurantPosDb.sql) và chạy toàn bộ kịch bản (F5).
3. Kiểm tra CSDL `RestaurantPosDb` đã được tạo đầy đủ 10 bảng và nạp 10 dòng mẫu mỗi bảng:

```sql
USE RestaurantPosDb;
SELECT t.name AS TableName, p.rows AS RecordCount
FROM sys.tables t
JOIN sys.partitions p ON t.object_id = p.object_id AND p.index_id < 2
ORDER BY TableName;
```

---

### Bước 2: Cấu hình & Chạy Backend ASP.NET Core 10 Web API

1. Mở terminal tại thư mục `backend`:
   ```bash
   cd backend
   ```
2. Cấu hình chuỗi kết nối trong `appsettings.json` cho phù hợp với máy của bạn:
   ```json
   "ConnectionStrings": {
     "RestaurantPosDb": "Server=localhost;Database=RestaurantPosDb;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=true;"
   }
   ```
3. Biên dịch và khởi chạy Web API:
   ```bash
   dotnet restore
   dotnet build
   dotnet run --urls "http://localhost:5138"
   ```
4. Kiểm tra endpoint kiểm tra sức khỏe hệ thống:
   ```bash
   curl http://localhost:5138/api/table/areas
   ```

---

### Bước 3: Cấu hình & Khởi Chạy Mobile Flutter Client

1. Mở terminal tại thư mục `mobile`:
   ```bash
   cd mobile
   ```
2. Tải các thư viện phụ thuộc:
   ```bash
   flutter pub get
   ```
3. Chạy phân tích mã nguồn và bộ kiểm thử tự động:
   ```bash
   flutter analyze
   flutter test
   ```
4. Khởi chạy ứng dụng:
   ```bash
   # Chạy trên Windows Desktop
   flutter run -d windows

   # Chạy trên trình duyệt Chrome
   flutter run -d chrome

   # Chạy trên máy ảo Android AVD
   flutter run
   ```

*Lưu ý khi chạy trên Android Emulator:* Địa chỉ `localhost` của máy tính sẽ được map thành `http://10.0.2.2:5138` trên máy ảo Android. Ứng dụng đã được tích hợp cơ chế Offline Fallback an toàn giúp giao diện Sơ đồ bàn ăn và giỏ hàng vẫn hoạt động mượt mà ngay cả khi chưa kết nối đến server backend.

---

## Kiểm Thử & Kiểm Soát Chất Lượng (Quality Gates)

Toàn bộ mã nguồn đã vượt qua các cổng kiểm thử nghiêm ngặt trước khi bàn giao:

```bash
# 1. Kiểm thử biên dịch Backend .NET 10 (0 Error, 0 Warning)
cd backend
dotnet build --configuration Release

# 2. Phân tích tĩnh Flutter Mobile (0 Issue)
cd ../mobile
flutter analyze

# 3. Chạy toàn bộ 35 bài kiểm thử đơn vị & tích hợp (All Passed)
flutter test
```

Kết quả nghiệm thu:
- **Backend:** `dotnet build` succeeded with 0 Warning(s), 0 Error(s).
- **Mobile Analysis:** `flutter analyze` reported `No issues found!`.
- **Unit & Integration Tests:** `35/35 tests passed` (`widget_test`, `database_helper_test`, `table_model_test`, `table_repository_test`, `floor_table_challenge_test`, `empirical_challenge_test`).
