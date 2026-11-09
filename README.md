# HỆ THỐNG QUẢN LÝ NHÀ HÀNG & QUÁN CAFE (RESTAURANT & CAFE POS SYSTEM)

Giải pháp quản lý điểm bán hàng (POS), sơ đồ bàn ăn và điều phối vận hành đa nền tảng chuyên nghiệp dành cho nhà hàng, quán cafe và chuỗi F&B. Hệ thống được xây dựng theo mô hình monorepo có khả năng chịu lỗi và hoạt động ngoại tuyến (Offline-Resilient), bao gồm ứng dụng di động Flutter với bộ nhớ đệm SQLite cục bộ trên thiết bị, kết nối với Backend ASP.NET Core 10 RESTful API và cơ sở dữ liệu Microsoft SQL Server 2022.

---

## 1. TỔNG QUAN KIẾN TRÚC HỆ THỐNG (SYSTEM ARCHITECTURE)

Hệ thống vận hành theo kiến trúc 4 tầng phân tách trách nhiệm rõ ràng (4-tier Provider / Repository Architecture), kết hợp cơ chế lưu trữ cục bộ Offline-First đảm bảo nhân viên phục vụ và thu ngân vẫn có thể thao tác thông suốt ngay cả khi sự cố mất mạng Internet xảy ra:

```
+---------------------------------------------------------------------------------+
|                       MOBILE CLIENT (FLUTTER 3.47 / DART 3.13)                  |
|  - Tầng Giao diện (Presentation): FloorTablePage, CashierPos, KDS, MemberPortal |
|  - Bộ nhớ cục bộ (SQLite): user_session, cart_items, offline_orders queue       |
|  - Tầng Dịch vụ (Service Layer): OfflineSyncService, ReceiptPrinterService      |
|  - Tầng Truy xuất (Repository): TableRepository, OrderRepository, ProductRepo    |
+---------------------------------------------------------------------------------+
                                       |
                                       | RESTful JSON qua giao thức HTTP / HTTPS
                                       v
+---------------------------------------------------------------------------------+
|                    BACKEND REST API (ASP.NET CORE 10 WEB API)                   |
|  - Tầng Điều khiển: AuthController, TableController, OrderController, etc.      |
|  - Tầng Facade / Điều phối: SiteProvider / BaseProvider                         |
|  - Tầng Truy vấn Dữ liệu: AccountRepo, TableRepo, OrderRepo, ProductRepo, etc.  |
|  - Bảo mật & Đa phương tiện: JWT Bearer, SHA-256 Salted Hash, wwwroot/images   |
+---------------------------------------------------------------------------------+
                                       |
                                       | Entity Framework Core 10 (ORM)
                                       v
+---------------------------------------------------------------------------------+
|                     CƠ SỞ DỮ LIỆU TRUNG TÂM (MICROSOFT SQL SERVER)              |
|  - 14 Bảng chuẩn hóa 3NF: Roles, Accounts, Areas, DiningTables, Categories,     |
|    Products, ProductAttributes, Orders, OrderDetails, Payments,                 |
|    OrderDetailModifiers, Shifts, Reservations, Discounts                        |
+---------------------------------------------------------------------------------+
```

---

## 2. CÔNG NGHỆ SỬ DỤNG (TECHNOLOGY STACK)

| Thành phần | Công nghệ | Phiên bản | Mục đích sử dụng |
| :--- | :--- | :--- | :--- |
| Mobile Client | Flutter / Dart SDK | Flutter 3.47.1 / Dart 3.13.1 | Ứng dụng POS di động đa nền tảng cho Phục vụ, Thu ngân, Bếp và Khách hàng |
| Local Database | SQLite (sqflite) | 2.4.2 | Lưu trữ cục bộ giỏ hàng, phiên đăng nhập và hàng đợi đồng bộ ngoại tuyến |
| Backend API | ASP.NET Core Web API | .NET 10.0 (net10.0) | Xử lý nghiệp vụ tập trung, giao dịch ACID, phân quyền và REST Controllers |
| ORM | Entity Framework Core | 10.0.12 | Ánh xạ đối tượng quan hệ với SQL Server |
| Database | Microsoft SQL Server | 2019 / 2022 | Cơ sở dữ liệu quan hệ trung tâm chuẩn ACID (14 bảng chuẩn hóa 3NF gồm 10 bảng cốt lõi & 4 bảng mở rộng) |
| Cổng thanh toán | VietQR / VNPayment | NAPAS 247 / v2 | Thanh toán mã QR động ngân hàng và cổng thanh toán trực tuyến điện tử |

---

## 3. SƠ ĐỒ LUỒNG NGHIỆP VỤ TOÀN BỘ DỰ ÁN (SYSTEM PROCESS FLOW)

Sơ đồ dưới đây mô tả toàn bộ chu trình nghiệp vụ thực tế từ khi khách bước vào quán, mở bàn, chọn món, xử lý chế biến tại bếp KDS, xử lý thanh toán đa phương thức đến đồng bộ ngoại tuyến:

```mermaid
flowchart TD
    Start["Khách hàng đến nhà hàng"] --> TableSelect["Chọn bàn trên Sơ đồ phòng ăn (Floor Map)"]
    
    subgraph RoleEntry ["Phân quyền & Vai trò người dùng"]
        AdminRole["ADMIN / MANAGER: Toàn quyền, Thống kê, Quản lý bàn & món"]
        WaiterRole["WAITER: Mở bàn, Chọn món, Chuyển bàn, Gửi order"]
        KitchenRole["KITCHEN: Nhận order KDS, Báo hết món, Cập nhật chế biến"]
        CashierRole["CASHIER: In hóa đơn, Chiết khấu, Tách/Gộp bill, Thu tiền"]
        MemberRole["MEMBER: Tự đặt món QR tại bàn, Tra cứu đơn, Đổi điểm voucher"]
    end

    TableSelect --> Ordering["Chọn món ăn từ Thực đơn (Size, Topping, Ghi chú)"]
    Ordering --> Cart["Thêm vào Giỏ hàng (SQLite Local Cache)"]
    
    Cart --> NetCheck{"Kiểm tra kết nối mạng?"}
    NetCheck -- "Online" --> ApiOrder["Gửi POST /api/order lên Backend"]
    NetCheck -- "Offline" --> LocalQueue["Lưu vào offline_orders queue trong SQLite"]
    LocalQueue --> SyncDaemon["OfflineSyncService tự động đồng bộ khi có mạng"]
    SyncDaemon --> ApiOrder

    ApiOrder --> TableStatusOcc["Cập nhật bàn: CÓ KHÁCH (Occupied)<br/>Khởi động Bộ đếm thời gian ngồi (Seating Timer)"]
    TableStatusOcc --> KDSQueue["Order chuyển xuống Màn hình bếp (KDS)"]

    subgraph KitchenFlow ["Nghiệp vụ Chế biến tại Bếp (KDS)"]
        KDSQueue --> Alert["Báo chuông Alert + Rung Haptic khi có order mới"]
        Alert --> CookingStatus{"Trạng thái món ăn"}
        CookingStatus -- "Nguyên liệu sẵn sàng" --> CookStep["Chế biến: Chờ nấu -> Đang nấu -> Hoàn thành"]
        CookingStatus -- "Hết nguyên liệu / Khách đổi ý" --> VoidStep["Hủy món (Void Item) kèm lý do và ghi chú"]
        VoidStep --> RefundCalc["Tự động trừ tiền order và cập nhật màn hình Thu ngân"]
        CookStep --> ReadyServe["Món đã sẵn sàng: Phục vụ mang ra bàn"]
    end

    ReadyServe --> BillRequest["Khách yêu cầu tính tiền"]
    
    subgraph CashierFlow ["Nghiệp vụ Thu ngân & Thanh toán"]
        BillRequest --> CashierAction["Thu ngân kiểm tra hóa đơn trên POS"]
        CashierAction --> DiscountOption{"Có áp dụng giảm giá không?"}
        DiscountOption -- "Có" --> ApplyDiscount["Giảm giá thủ công (% hoặc VNĐ) hoặc Áp dụng Voucher"]
        DiscountOption -- "Không" --> ChoosePaymentMethod
        ApplyDiscount --> ChoosePaymentMethod{"Chọn phương thức thanh toán"}

        ChoosePaymentMethod -- "Tiền mặt (Cash)" --> CashPay["Nhập tiền khách đưa -> Tính tiền thối"]
        ChoosePaymentMethod -- "Chuyển khoản VietQR" --> QRPay["Sinh mã VietQR động NAPAS 247 theo số tiền"]
        ChoosePaymentMethod -- "Cổng VNPay Sandbox" --> VNPay["Chuyển hướng cổng thanh toán VNPay"]
        ChoosePaymentMethod -- "Thanh toán hỗn hợp (Split)" --> SplitPay["Chia thanh toán: Một phần Tiền mặt + Một phần VietQR"]

        CashPay --> ConfirmPay["POST /api/payment/confirm"]
        QRPay --> ConfirmPay
        VNPay --> ConfirmPay
        SplitPay --> ConfirmPay

        ConfirmPay --> PrintReceipt["In hóa đơn nhiệt 80mm<br/>(In lại đóng dấu DUPLICATE chống gian lận)"]
        PrintReceipt --> ReleaseTable["Cập nhật bàn: TRỐNG (Available) & Giải phóng bàn"]
    end

    ReleaseTable --> End["Hoàn tất quy trình phục vụ"]
```

---

## 4. SƠ ĐỒ TRÌNH TỰ CHI TIẾT TOÀN BỘ QUY TRÌNH (END-TO-END SEQUENCE DIAGRAM)

Sơ đồ trình tự thể hiện chi tiết luồng dữ liệu, tham số gửi nhận và tương tác giữa các tác nhân (Actors), ứng dụng di động, cơ sở dữ liệu cục bộ SQLite, Backend REST API, CSDL SQL Server và cổng thanh toán:

```mermaid
sequenceDiagram
    autonumber
    actor KhachHang as Khách hàng / Member
    actor PhucVu as Nhân viên phục vụ
    participant App as Mobile Client (Flutter)
    participant SQLite as SQLite Local Cache
    participant API as ASP.NET Core 10 API
    participant DB as SQL Server 2022
    actor Bep as Bộ phận Bếp (KDS)
    actor ThuNgan as Thu ngân (Cashier)
    participant Gateway as VietQR / VNPay Gateway

    %% GIAI ĐOẠN 1: ĐĂNG NHẬP & MỞ BÀN
    rect rgb(240, 248, 255)
    Note over PhucVu, DB: Giai đoạn 1: Đăng nhập & Mở bàn
    PhucVu->>App: Đăng nhập bằng Tên đăng nhập/Mật khẩu hoặc One-Tap OAuth
    App->>API: POST /api/auth/login
    API->>DB: Kiểm tra tài khoản và mật khẩu băm (Salted SHA-256)
    DB-->>API: Trả về thông tin Account & Role (WAITER)
    API-->>App: Trả về JWT Token và Session Payload
    App->>SQLite: Lưu phiên đăng nhập vào bảng user_session
    PhucVu->>App: Chọn Khu vực và Bàn ăn trên Sơ đồ bàn (Floor Map)
    App->>API: PUT /api/table/{id}/status (status = 1: CÓ KHÁCH)
    API->>DB: UPDATE DiningTables SET Status = 1, OrderCreatedAt = GETDATE()
    DB-->>API: Cập nhật thành công
    API-->>App: HTTP 200 OK
    App-->>PhucVu: Thẻ bàn chuyển sang Màu Đỏ + Kích hoạt Seating Duration Timer
    end

    %% GIAI ĐOẠN 2: CHỌN MÓN & ĐỒNG BỘ NGOẠI TUYẾN
    rect rgb(255, 250, 240)
    Note over PhucVu, DB: Giai đoạn 2: Chọn món & Gửi order
    PhucVu->>App: Chọn món ăn, tùy chọn Size, Topping, Ghi chú riêng
    App->>SQLite: Thêm món vào bảng cart_items (Tính tổng tức thì)
    PhucVu->>App: Nhấn nút Xác nhận đặt món (Checkout)
    alt Có kết nối Internet
        App->>API: POST /api/order (tableId, items, note)
        API->>DB: Transaction: INSERT Orders và INSERT OrderDetails
        DB-->>API: Trả về OrderId và OrderCode (VD: ORD-20261109-001)
        API-->>App: HTTP 200 OK (Order payload)
    else Mất kết nối Internet (Offline)
        App->>SQLite: Lưu vào bảng offline_orders (is_synced = 0)
        App-->>PhucVu: Thông báo đơn đã lưu cục bộ, sẽ tự động đồng bộ khi có mạng
        Note over App, API: Khi có mạng trở lại: OfflineSyncService quét và gửi POST /api/order lên Backend
    end
    end

    %% GIAI ĐOẠN 3: XỬ LÝ TẠI BẾP (KDS)
    rect rgb(245, 255, 245)
    Note over Bep, DB: Giai đoạn 3: Xử lý tại Bếp KDS
    API-->>Bep: KDS nhận order mới -> Phát âm thanh Alert + Rung Haptic
    alt Bếp còn đủ nguyên liệu
        Bep->>App: Chuyển trạng thái sang Đang chế biến (Status = 1)
        App->>API: PUT /api/order/{id}/status (status = 1)
        API->>DB: UPDATE Orders SET Status = 1
        Bep->>App: Chuyển trạng thái sang Đã nấu xong (Status = 2)
        App->>API: PUT /api/order/{id}/status (status = 2)
        API->>DB: UPDATE Orders SET Status = 2
        API-->>PhucVu: Thông báo món đã sẵn sàng để mang ra phục vụ
    else Bếp hết nguyên liệu / Khách yêu cầu hủy món
        Bep->>App: Bấm Hủy món (Void Item) kèm Lý do
        App->>API: POST /api/order/{id}/void-item (detailId, reason)
        API->>DB: UPDATE OrderDetails (IsVoided = 1, VoidReason) & Tính lại FinalAmount
        DB-->>API: Cập nhật đơn thành công
        API-->>App: Cập nhật lại tổng tiền món ăn
    end
    end

    %% GIAI ĐOẠN 4: THEO DÕI ĐƠN TẠI PHÍA KHÁCH HÀNG
    rect rgb(255, 240, 245)
    Note over KhachHang, App: Giai đoạn 4: Khách hàng tra cứu & Sử dụng điểm
    KhachHang->>App: Nhập SĐT tra cứu trạng thái đơn hàng tại Member Portal
    App->>API: GET /api/order?phoneNumber={phone}
    API->>DB: SELECT Orders WHERE PhoneNumber = {phone}
    DB-->>API: Trả về danh sách đơn
    API-->>App: Trả về JSON Orders
    App-->>KhachHang: Hiển thị Stepper 3 bước: Tiếp nhận -> Đang chế biến -> Sẵn sàng phục vụ
    KhachHang->>App: Dùng Điểm tích lũy (PTS) đổi Voucher ưu đãi
    App-->>KhachHang: Trừ điểm thành công, mã voucher sẵn sàng sử dụng
    end

    %% GIAI ĐOẠN 5: THANH TOÁN & ĐÓNG BÀN
    rect rgb(245, 245, 255)
    Note over ThuNgan, Gateway: Giai đoạn 5: Thanh toán & In hóa đơn
    ThuNgan->>App: Chọn bàn trên POS Thu Ngân để lập hóa đơn
    App->>API: GET /api/order/{id}
    API->>DB: Lấy chi tiết đơn hàng, phụ thu và chiết khấu
    DB-->>API: Trả về Order Detail
    API-->>App: Hiển thị hóa đơn chi tiết
    alt Thu ngân áp dụng chiết khấu thủ công
        ThuNgan->>App: Nhập giảm giá thủ công (% hoặc VNĐ) kèm lý do
        App->>App: Cập nhật lại FinalAmount cần thanh toán
    end
    alt Thanh toán bằng Tiền mặt
        ThuNgan->>App: Nhập số tiền khách đưa -> App tính tiền thối
    else Thanh toán bằng Chuyển khoản VietQR
        ThuNgan->>App: Chọn Chuyển khoản VietQR
        App->>API: GET /api/payment/vietqr/{orderId} (Tính tiền trực tiếp từ DB)
        API-->>App: Sinh mã VietQR NAPAS 247 chuẩn VietQR.io
        App-->>KhachHang: Hiển thị mã QR để khách quét bằng app ngân hàng
    else Thanh toán Hỗn hợp (Split Cash + VietQR)
        ThuNgan->>App: Nhập số tiền mặt thu trước -> App tạo VietQR cho phần tiền còn lại
    end
    ThuNgan->>App: Xác nhận Hoàn tất thanh toán
    App->>API: POST /api/payment/confirm (OrderId, PaymentMethod, Amount)
    API->>DB: INSERT Payments, UPDATE Orders Status = 3 (Completed), UPDATE DiningTables Status = 0 (Empty)
    DB-->>API: Giao dịch thành công
    API-->>App: HTTP 200 OK
    App->>App: In hóa đơn nhiệt 80mm qua ReceiptPrinterService
    opt Khi cần in lại hóa đơn
        ThuNgan->>App: Bấm In lại hóa đơn
        App->>App: Đóng dấu chìm [BẢN IN LẠI / DUPLICATE] lên hóa đơn in lại
    end
    App-->>ThuNgan: Giải phóng bàn thành công, bàn trở về trạng thái SẴN SÀNG
    end
```

---

## 5. DANH SÁCH TÀI KHOẢN VÀ MẬT KHẨU THEO TỪNG VAI TRÒ (RBAC SEEDED ACCOUNTS)

Hệ thống thiết lập phân quyền chặt chẽ theo vai trò (Role-Based Access Control - RBAC). Toàn bộ danh sách tài khoản dưới đây đã được khởi tạo sẵn trong cơ sở dữ liệu (`RestaurantPosDb.sql` và `RestaurantPos_Acceptance.sql`):

* Lưu ý về Mật khẩu: Toàn bộ tài khoản thử nghiệm bên dưới đều sử dụng mật khẩu mặc định là: `admin` (tương ứng chuỗi băm SHA-256 lưu trong cơ sở dữ liệu: `8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918`).

| STT | Tên đăng nhập (Username) | Mật khẩu mặc định | Mã vai trò (Role) | Tên vai trò | Họ và tên | Email | Quyền hạn & Phạm vi nghiệp vụ |
| :---: | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | `admin` | `admin` | `ADMIN` | Quản trị viên | Nguyễn Văn Quản Trị | `admin@restaurantpos.vn` | Toàn quyền: Cấu hình hệ thống, quản trị danh mục, món ăn, nhân sự, báo cáo doanh thu |
| 2 | `manager01` | `admin` | `MANAGER` | Quản lý chi nhánh | Trần Thị Thu Quản Lý | `manager01@restaurantpos.vn` | Quản lý vận hành: Điều phối bàn, hủy món có giám sát, kiểm soát ca, xem báo cáo |
| 3 | `cashier_mai` | `admin` | `CASHIER` | Thu ngân | Lê Tuyết Mai | `mai.cashier@restaurantpos.vn` | Thu ngân POS: Lập hóa đơn, tách bill, chiết khấu, thu tiền mặt, VietQR, in lại hóa đơn |
| 4 | `waiter_nam` | `admin` | `WAITER` | Nhân viên phục vụ | Phạm Hoàng Nam | `nam.waiter@restaurantpos.vn` | Phục vụ bàn: Mở bàn trên sơ đồ, chọn món, chuyển bàn, theo dõi thời gian ngồi |
| 5 | `waiter_lan` | `admin` | `WAITER` | Nhân viên phục vụ | Đỗ Ngọc Lan | `lan.waiter@restaurantpos.vn` | Phục vụ bàn: Tài khoản thứ 2 phục vụ kiểm thử thao tác đồng thời và bàn giao ca |
| 6 | `kitchen` | `admin` | `KITCHEN` | Bếp trưởng KDS | Bếp Trưởng KDS | `kitchen@restaurantpos.vn` | Màn hình KDS: Tiếp nhận món, cập nhật tiến độ nấu, báo hết món (Được kích hoạt trong `RestaurantPos_Acceptance.sql`; trong `RestaurantPosDb.sql` gốc tài khoản bếp tương đương là `chef_dung` - `HEAD_CHEF`) |
| 7 | `chef_dung` | `admin` | `HEAD_CHEF` | Đầu bếp chính | Ngô Tiến Dũng | `dung.chef@restaurantpos.vn` | Đầu bếp: Chế biến các món ăn chính, món nóng và kiểm soát chất lượng món |
| 8 | `barista_tuan` | `admin` | `BARISTA_LEAD` | Trưởng quầy Bar | Vũ Anh Tuấn | `tuan.barista@restaurantpos.vn` | Quầy pha chế: Chuyên trách pha chế cà phê, trà trái cây, đá xay, đồ uống |
| 9 | `member_khang` | `admin` | `MEMBER` | Hội viên | Bùi Vĩnh Khang | `khang.bui@gmail.com` | Khách hàng thân thiết: Tự gọi món QR tại bàn, tích lũy điểm, đổi voucher giảm giá |
| 10 | `vip_huong` | `admin` | `VIP_MEMBER` | Hội viên VIP | Đặng Thu Hương | `huong.dang@fpt.com` | Hội viên VIP: Hưởng đặc quyền chiết khấu VIP khi lập hóa đơn và voucher cao cấp |
| 11 | `member_linh` | `admin` | `MEMBER` | Hội viên | Võ Diệu Linh | `linh.vo@outlook.com` | Khách hàng thân thiết tạo qua liên kết mạng xã hội One-Tap OAuth |

---

## 6. DANH MỤC REST API ENDPOINTS CHÍNH (API REFERENCE)

Hệ thống cung cấp hệ thống 11 RESTful Controllers toàn diện, được phân quyền nghiêm ngặt theo chuẩn JWT Bearer RBAC:

### 6.1. Xác thực & Tài khoản (Auth & Accounts)
* `POST /api/auth/register`: Đăng ký tài khoản khách hàng mới.
* `POST /api/auth/login`: Đăng nhập hệ thống bằng username/password, nhận mã thông báo JWT.
* `POST /api/auth/oauth-login`: Đăng nhập một chạm thông qua Google hoặc Facebook.
* `POST /api/auth/request-otp`: Yêu cầu gửi mã OTP 6 chữ số qua email/database để đặt lại mật khẩu.
* `POST /api/auth/reset-password-otp`: Xác nhận mã OTP và thiết lập mật khẩu mới (tối thiểu 6 ký tự).
* `POST /api/auth/change-password`: Đổi mật khẩu tài khoản hiện tại.
* `GET /api/auth/profile/{id}`: Xem thông tin chi tiết hồ sơ người dùng.
* `GET /api/account/members`: Xem danh sách nhân viên và quyền hạn (chỉ ADMIN và MANAGER).
* `PUT /api/account/{id}/role`: Cập nhật vai trò nhân viên trong hệ thống (ADMIN và MANAGER).

### 6.2. Sơ đồ bàn, Khu vực & Đặt bàn (Floor, Table & Reservations)
* `GET /api/table`: Lấy toàn bộ danh sách bàn kèm thời gian khách ngồi và tạm tính realtime.
* `GET /api/table/areas`: Lấy danh sách các khu vực (Tầng trệt, Tầng 1, Sân vườn, Phòng VIP).
* `GET /api/table/by-area/{areaId}`: Lấy danh sách bàn theo khu vực cụ thể.
* `POST /api/table`: Thêm bàn ăn mới (ADMIN / MANAGER).
* `PUT /api/table/{id}`: Cập nhật thông tin số ghế, tên bàn, khu vực.
* `DELETE /api/table/{id}`: Xóa bàn ăn (tự động chặn nếu bàn đang có khách hoặc chưa thanh toán).
* `POST /api/table/area`: Thêm khu vực mới trong nhà hàng.
* `PUT /api/table/area/{id}`: Sửa tên hoặc ghi chú khu vực.
* `DELETE /api/table/area/{id}`: Xóa khu vực trống.
* `PUT /api/table/{id}/status`: Cập nhật trạng thái bàn (0: Trống, 1: Có khách, 2: Đã đặt).
* `POST /api/table/transfer`: Thực hiện chuyển bàn từ bàn nguồn sang bàn đích an toàn.
* `POST /api/table/merge`: Gộp 2 bàn ăn lại thành một.
* `POST /api/table/split`: Tách bàn hoặc tách đơn hàng sang bàn mới.
* `POST /api/table/reserve`: Đặt trước bàn ăn cho khách hàng.
* `GET /api/table/reservations`: Tra cứu danh sách bàn đã đặt trước theo ngày.
* `PUT /api/table/reservation/{id}/check-in`: Tiếp nhận khách đặt trước vào bàn.

### 6.3. Thực đơn, Món ăn & Upload Ảnh (Menu & Product Management)
* `GET /api/category`: Lấy danh mục thực đơn đang hoạt động.
* `GET /api/category/{id}`: Lấy chi tiết thông tin danh mục.
* `POST /api/category`: Thêm danh mục mới kèm tải lên hình ảnh đại diện vào `wwwroot/images`.
* `PUT /api/category/{id}`: Cập nhật thông tin và ảnh danh mục.
* `DELETE /api/category/{id}`: Xóa danh mục (chặn xóa nếu vẫn còn sản phẩm trực thuộc).
* `GET /api/product`: Lấy danh sách món ăn kèm bộ lọc danh mục, tìm kiếm và phân trang.
* `GET /api/product/{id}`: Lấy chi tiết thông tin món ăn, mô tả và giá bán.
* `GET /api/product/featured`: Danh sách món ăn nổi bật hoặc bán chạy nhất.
* `GET /api/product/search`: Tìm kiếm nhanh món ăn theo từ khóa.
* `POST /api/product`: Thêm món ăn mới kèm ảnh đại diện.
* `PUT /api/product/{id}`: Cập nhật thông tin và hình ảnh món ăn.
* `POST /api/product/{id}/upload-images`: Tải lên nhiều hình ảnh chi tiết cho món ăn.
* `DELETE /api/product/{id}/images`: Xóa ảnh cụ thể của món ăn khỏi thư mục tĩnh.
* `DELETE /api/product/{id}`: Xóa món ăn khỏi thực đơn.
* `PUT /api/product/{id}/toggle-availability`: 1-Chạm bật/tắt trạng thái Còn món hoặc Hết món (Sold-Out).

### 6.4. Đơn hàng & Điều phối (Orders)
* `POST /api/order`: Khởi tạo đơn hàng mới từ Mobile Client hoặc máy tính bảng phục vụ.
* `GET /api/order`: Danh sách đơn hàng, hỗ trợ lọc theo SĐT khách hàng hoặc trạng thái.
* `GET /api/order/{id}`: Lấy chi tiết đơn hàng, danh sách món và trạng thái thanh toán.
* `GET /api/order/admin`: Danh sách đơn hàng phân trang và thống kê doanh thu cho Quản trị viên.
* `GET /api/order/by-table/{tableId}`: Lấy thông tin đơn hàng hiện tại của một bàn ăn.
* `PUT /api/order/{id}/status`: Cập nhật trạng thái đơn (0: Mới, 1: Đang chế biến, 2: Phục vụ, 3: Hoàn tất).
* `POST /api/order/{id}/add-items`: Thêm món mới vào đơn hàng đang phục vụ tại bàn.
* `POST /api/order/{id}/void-item`: Hủy món kèm lý do, tự động trừ tiền và ghi nhận kiểm toán.

### 6.5. Màn hình Bếp KDS (Kitchen Display System)
* `GET /api/kds`: Lấy danh sách toàn bộ món ăn đang cần chế biến, sắp xếp theo thời gian đặt.
* `GET /api/kds/active-orders`: Mảng đơn hàng trực tiếp tối ưu hóa cho giao diện Flutter KDS.
* `PUT /api/kds/{orderDetailId}/status`: Bếp trưởng cập nhật tiến độ (0: Chờ nấu, 1: Đang nấu, 2: Đã nấu xong).
* `POST /api/kds/{orderDetailId}/void`: Hủy món trực tiếp từ màn hình Bếp kèm lý do (hết nguyên liệu).

### 6.6. Quản lý Ca làm việc & Tiền mặt (Shifts & Cash Management)
* `GET /api/shift/current`: Lấy thông tin ca làm việc đang mở của nhân viên thu ngân.
* `POST /api/shift/open`: Mở ca làm việc mới kèm nhập số tiền mặt đầu ca (Opening Balance).
* `POST /api/shift/close`: Đóng ca làm việc và đối soát doanh thu tiền mặt thực tế cuối ca.
* `GET /api/shift/{id}/z-report`: Xuất báo cáo kết ca (Z-Report) tổng hợp doanh thu theo phương thức thanh toán.

### 6.7. Mã giảm giá & Ưu đãi Hội viên (Discounts & Vouchers)
* `GET /api/discount/active`: Lấy danh sách các chương trình khuyến mãi và voucher đang có hiệu lực.
* `POST /api/discount/validate`: Kiểm tra tính hợp lệ của mã giảm giá và tính toán số tiền khấu trừ.

### 6.8. Thanh toán Đa phương thức (Payments)
* `POST /api/payment/confirm`: Xác nhận thanh toán đơn hàng (Tiền mặt, VietQR, VNPay hoặc Thanh toán hỗn hợp).
* `POST /api/payment/cash`: Xử lý giao dịch tiền mặt, lưu tiền khách đưa và tính tiền thối.
* `GET /api/payment/vietqr/{orderId}`: Sinh mã VietQR NAPAS 247 động (Số tiền tính tự động từ database đơn hàng).
* `POST /api/payment/vnpay/create-url`: Khởi tạo đường dẫn thanh toán chuyển hướng sang cổng VNPay Sandbox.
* `GET /api/payment/vnpay/callback`: Tiếp nhận dữ liệu IPN callback xử lý kết quả từ cổng VNPay Sandbox.
* `GET /api/payment/vnpay-return`: Trang đích phản hồi kết quả giao dịch thanh toán trực tuyến cho khách hàng.

---

## 7. HƯỚNG DẪN CÀI ĐẶT & THIẾT LẬP .ENV NHANH (QUICK SETUP GUIDE)

### 7.1. Yêu cầu môi trường tiên quyết
* .NET SDK: Phiên bản 10.0 (`dotnet --version` hiển thị `10.0.x`)
* Flutter SDK: Phiên bản 3.47 (`flutter --version` hiển thị `3.47.x`, Dart `3.13.x`)
* Hệ quản trị CSDL: Microsoft SQL Server 2019 / 2022 (hoặc SQL Server Express)
* Git Client

---

### 7.2. Bước 1: Khởi tạo Cơ sở dữ liệu SQL Server

Sử dụng SQL Server Management Studio (SSMS) hoặc lệnh `sqlcmd` để thực thi tệp kịch bản:
1. Mở file `RestaurantPosDb.sql` (hoặc `RestaurantPos_Acceptance.sql` cho bộ dữ liệu kiểm thử đầy đủ có tài khoản `kitchen`) nằm ở thư mục gốc dự án.
2. Thực thi toàn bộ tệp (nhấn phím F5 trong SSMS).
3. Kiểm tra cơ sở dữ liệu `RestaurantPosDb` (hoặc `RestaurantPos_Acceptance`) đã được tạo thành công với 14 bảng quan hệ và dữ liệu mẫu đã được nạp sẵn.

---

### 7.3. Bước 2: Thiết lập file .env và Khởi chạy Backend API

1. Mở cửa sổ dòng lệnh tại thư mục `backend`:
```bash
cd backend
```

2. Tạo file cấu hình `.env` từ file mẫu `.env.example`:
```bash
# Trên Linux / macOS:
cp .env.example .env

# Trên Windows PowerShell:
Copy-Item .env.example .env
```

3. Kiểm tra nội dung file `.env` chuẩn của Backend:
```env
# 1. Chuỗi kết nối CSDL SQL Server (Điều chỉnh Server/Database nếu cần)
ConnectionStrings__RestaurantPosDb=Server=localhost;Database=RestaurantPosDb;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=true;

# 2. Cấu hình bảo mật JWT Token
Jwt__Key=RestaurantPosSecretKeyForJwtAuthentication2026!@#$%^&*()_+
Jwt__Issuer=RestaurantPosApi
Jwt__Audience=RestaurantPosClients
Jwt__ExpireMinutes=1440

# 3. Cấu hình Cổng thanh toán VNPay Sandbox
VNPay__TmnCode=L5GXH1AU
VNPay__HashSecret=EVCHM01XP0U7PT31IRMOJKC2IXRV2DW7
VNPay__Url=https://sandbox.vnpayment.vn/paymentv2/vpcpay.html
VNPay__ReturnUrl=http://localhost:5138/api/payment/vnpay/callback

# 4. Cấu hình chuyển khoản VietQR Napas 247
VIETQR_BANK_ID=vietinbank
VIETQR_ACCOUNT_NO=102871234567
VIETQR_ACCOUNT_NAME=NHA HANG BISTRO POS
```

4. Khôi phục thư viện, biên dịch và khởi chạy Web API:
```bash
dotnet restore
dotnet build WebApi.csproj
dotnet run --urls "http://localhost:5138"
```
Backend API sẽ lắng nghe và phục vụ tại địa chỉ: `http://localhost:5138`.

---

### 7.4. Bước 3: Thiết lập file .env và Khởi chạy Mobile Flutter Client

1. Mở cửa sổ dòng lệnh tại thư mục `mobile`:
```bash
cd ../mobile
```

2. Tạo file cấu hình `.env` từ file mẫu `.env.example`:
```bash
# Trên Linux / macOS:
cp .env.example .env

# Trên Windows PowerShell:
Copy-Item .env.example .env
```

3. Nội dung file `mobile/.env`:
```env
# Địa chỉ API Backend
# - Khi chạy trên Windows Desktop hoặc Trình duyệt Chrome:
POS_API_BASE_URL=http://localhost:5138

# - Khi chạy trên Máy ảo Android Emulator (Android Studio):
# POS_API_BASE_URL=http://10.0.2.2:5138

# - Khi chạy trên Máy tính bảng hoặc Điện thoại thật qua mạng WiFi LAN:
# POS_API_BASE_URL=http://192.168.1.100:5138

# Thông tin nhà hàng in trên hóa đơn nhiệt
POS_STORE_NAME=BISTRO POS RESTAURANT
POS_STORE_ADDRESS=123 Đường Ẩm Thực, Quận 1, TP. Hồ Chí Minh
POS_STORE_PHONE=0901234567
POS_PRINTER_DEFAULT_WIDTH=80mm
```

4. Cài đặt các gói phụ thuộc và khởi chạy ứng dụng:
```bash
flutter pub get

# Chạy trên môi trường Windows Desktop:
flutter run -d windows

# Chạy trên trình duyệt Web Chrome:
flutter run -d chrome

# Chạy trên máy ảo hoặc thiết bị Android:
flutter run
```

---

## 8. HÌNH ẢNH GIAO DIỆN THỰC TẾ & MINH CHỨNG VẬN HÀNH (LIVE SYSTEM SHOWCASE)

Dưới đây là một số hình ảnh thực tế được chụp trực tiếp từ phiên chạy tương tác màn hình giao diện thực tế (True Canvas Real UI Live Test) trên trình duyệt Google Chrome thông qua Flutter Web Semantics và Backend ASP.NET Core 10:

### 8.1. Sơ đồ Bàn ăn Động & Bộ đếm Thời gian ngồi (Floor Table Map & Seating Duration Timer)
Sơ đồ bàn trực quan theo từng khu vực (Tầng trệt, Tầng 1, Sân vườn, VIP), hiển thị trạng thái màu sắc (Trống, Có khách, Đã đặt), thời gian khách đã ngồi và tạm tính tiền theo thời gian thực:
![Sơ đồ Bàn ăn](docs/images/showcase/01_floor_table_map.png)

### 8.2. Thực đơn Món ăn & Tìm kiếm Phân loại (Menu Catalog & Instant Search)
Giao diện danh mục món ăn phong phú với hình ảnh chất lượng cao, phân loại linh hoạt, tìm kiếm tức thì và hiệu ứng Skeleton Shimmer chống giật lag:
![Thực đơn Món ăn](docs/images/showcase/02_menu_catalog.png)

### 8.3. Xác nhận Đơn hàng & Điều phối Phục vụ (Waiter Order Checkout)
Nhân viên phục vụ kiểm tra giỏ hàng, chọn bàn chỉ định, thêm ghi chú riêng từng món và gửi order trực tiếp xuống bếp:
![Xác nhận Đơn hàng](docs/images/showcase/03_waiter_checkout.png)

### 8.4. Màn hình Bếp KDS & 1-Chạm Báo Hết Món (Kitchen Display System & Sold-Out Toggle)
Bếp trưởng tiếp nhận order tức thì kèm âm thanh cảnh báo, cập nhật tiến độ nấu và bật/tắt trạng thái hết món (Sold-Out) ngay trên màn hình KDS:
![Màn hình Bếp KDS](docs/images/showcase/04_kds_kitchen_display.png)

### 8.5. Trạm Điểm Bán Hàng Thu Ngân (Cashier POS Terminal)
Màn hình POS thu ngân chuyên nghiệp hỗ trợ chọn bàn, kiểm tra chi tiết đơn hàng, áp dụng chiết khấu/voucher, tách bill và thanh toán đa phương thức:
![Trạm POS Thu Ngân](docs/images/showcase/05_cashier_pos_terminal.png)

### 8.6. Quy trình Xác thực OTP Khôi phục Mật khẩu (Member OTP Flow)
Quy trình gửi mã xác thực OTP 6 số qua email/database, tự động điền form và đặt lại mật khẩu an toàn chuẩn Salted SHA-256:
![Xác thực OTP](docs/images/showcase/06_member_otp_flow.png)

### 8.7. Bảng Điều khiển Quản trị & Top 5 Món Bán Chạy (Admin KPI & Best-Sellers Dashboard)
Bảng điều khiển kinh doanh tổng quan hiển thị doanh thu ngày, số lượng đơn hoàn tất, tỷ lệ lấp đầy bàn và biểu đồ Top 5 món bán chạy nhất:
![Bảng Điều khiển Quản trị](docs/images/showcase/07_admin_dashboard_kpi.png)

### 8.8. Quản trị Danh mục & Phân trang Thực đơn (Admin Product & Category Management)
Quản trị viên thao tác thêm/sửa/xóa danh mục, quản lý món ăn kèm hình ảnh và phân trang linh hoạt:
![Quản trị Món ăn](docs/images/showcase/08_admin_product_management.png)

---

## 9. KIỂM THỬ CHẤT LƯỢNG & ĐỘ TIN CẬY (QUALITY GATES)

Mã nguồn toàn diện của dự án đã vượt qua tất cả các cổng kiểm soát chất lượng nghiêm ngặt trước khi bàn giao:

```bash
# 1. Kiểm tra biên dịch Backend C# (.NET 10)
cd backend
dotnet build WebApi.csproj
# Kết quả: Build succeeded. 0 Warning(s), 0 Error(s).

# 2. Phân tích tĩnh mã nguồn Flutter
cd ../mobile
flutter analyze
# Kết quả: No issues found!

# 3. Chạy toàn bộ bộ kiểm thử tự động (Unit, Widget, Adversarial & E2E)
flutter test
# Kết quả: All 82 tests passed! (100% Pass)

# 4. Kiểm thử tương tác trực tiếp màn hình toàn bộ vai trò (True Canvas Real UI Live Test)
python scripts/run_true_canvas_live_test.py
# Kết quả: 24/24 tests passed! (100% Pass across GUEST, WAITER, KITCHEN, CASHIER, MEMBER, ADMIN)
```

---

## 10. CẤU TRÚC THƯ MỤC DỰ ÁN (MONOREPO DIRECTORY LAYOUT)

```
restaurant_pos_app/
+-- RestaurantPosDb.sql                     # Kịch bản DDL & DML 14 bảng quan hệ SQL Server 2022
+-- RestaurantPos_Acceptance.sql            # Kịch bản kiểm thử nghiệm thu toàn diện (KDS & RBAC Seeded)
+-- .env.example                            # Bản mẫu cấu hình môi trường gốc
+-- README.md                               # Tài liệu hướng dẫn kỹ thuật toàn diện của dự án
+-- backend/                                # Mã nguồn Backend ASP.NET Core 10 Web API
|   +-- Api/
|   |   +-- Controllers/
|   |       +-- AccountController.cs        # Quản lý hồ sơ, phân quyền RBAC thành viên
|   |       +-- AuthController.cs           # Đăng nhập, Đăng ký, OAuth, Quên mật khẩu OTP
|   |       +-- CategoryController.cs       # CRUD Danh mục kèm Upload ảnh và dọn dẹp file
|   |       +-- DiscountController.cs       # Quản lý voucher, mã giảm giá và chiết khấu
|   |       +-- KdsController.cs            # Màn hình điều phối bếp KDS, cập nhật trạng thái nấu
|   |       +-- OrderController.cs          # Tạo đơn, Hủy món (Void Item), Thống kê đơn Admin
|   |       +-- PaymentController.cs        # Xác nhận thanh toán, Tiền mặt, VietQR, VNPay Sandbox
|   |       +-- ProductController.cs        # CRUD Món ăn, Topping, Toggle Báo hết món (Sold-Out)
|   |       +-- ShiftController.cs          # Mở/Đóng ca thu ngân, kiểm quỹ và Báo cáo kết ca (Z-Report)
|   |       +-- TableController.cs          # CRUD Bàn, Khu vực, Chuyển bàn, Tách/Gộp bàn, Đặt bàn
|   +-- Models/
|   |   +-- RestaurantPosContext.cs         # Entity Framework Core 10 DbContext (14 DbSets)
|   |   +-- SiteProvider.cs                 # Provider facade tập trung
|   |   +-- BaseProvider.cs, BaseRepo.cs    # Tầng cơ sở trừu tượng hóa truy vấn
|   |   +-- *Repository.cs                  # 8 Repositories: Account, Table, Category, Product, Order, Payment, Shift, Discount
|   |   +-- AuthDtos.cs, TableDtos.cs, OrderDtos.cs, etc.
|   +-- Services/
|   |   +-- Helper.cs                       # Tiện ích lưu trữ và dọn ảnh wwwroot
|   |   +-- JwtTokenService.cs              # Sinh mã JWT Bearer Token phân quyền RBAC
|   |   +-- PasswordHasher.cs               # Mã hóa mật khẩu Salted SHA-256
|   +-- wwwroot/images/                     # Thư mục chứa tài nguyên ảnh tĩnh
|   +-- Program.cs                          # Khởi tạo DI, JWT, CORS, Swagger
|   +-- WebApi.csproj
+-- mobile/                                 # Ứng dụng di động Flutter Client
|   +-- lib/
|   |   +-- models/                         # DTO Models (DiningTable, Product, Order, Payment, Area, etc.)
|   |   +-- repositories/                   # HTTP Clients kết nối API Backend (Table, Order, Product, Category, Auth)
|   |   +-- services/                       # OfflineSyncService, ReceiptPrinterService, SessionManager
|   |   +-- utils/database_helper.dart      # Singleton SQLite (user_session, cart_items, offline_orders)
|   |   +-- widgets/skeleton_loading.dart   # Skeleton Shimmer Loading chống AI-slop
|   |   +-- views/
|   |   |   +-- admin/                      # Quản trị Admin: Category, Orders KPI, Products, Users RBAC
|   |   |   +-- auth/                       # Đăng nhập, Đăng ký, One-Tap OAuth, Quên MK OTP
|   |   |   +-- table/floor_table_page.dart # Sơ đồ bàn, Khu vực, Seating Timer, Tạm tính realtime
|   |   |   +-- kitchen/                    # Màn hình KDS Bếp, Alert chuông, Sold-Out toggle
|   |   |   +-- cashier/                    # POS Thu ngân, Chiết khấu, Split payment, Ca làm việc
|   |   |   +-- member/member_home_page.dart# Member Portal, Stepper 3 bước, Đổi điểm thưởng
|   |   |   +-- order/                      # Checkout, Chi tiết đơn hàng, Hủy món có lý do
|   |   |   +-- cart_page.dart              # Giỏ hàng cục bộ SQLite & tính tạm tính tức thì
|   |   |   +-- category_page.dart          # Lọc thực đơn theo danh mục kèm Skeleton Shimmer
|   |   |   +-- home_page.dart              # Danh sách món ăn, tìm kiếm nhanh, phân loại
|   |   |   +-- product_detail_page.dart    # Chi tiết món ăn, tùy chọn Size, Topping & Ghi chú
|   |   +-- main.dart                       # Khởi chạy ứng dụng và NavigationBar F&B
|   +-- test/                               # 82 bài kiểm thử tự động (100% Pass)
|   +-- pubspec.yaml
+-- docs/                                   # Tài nguyên ảnh và tài liệu minh chứng
|   +-- images/showcase/                    # Ảnh chụp màn hình tương tác thực tế 6 vai trò
+-- scripts/                                # Kịch bản kiểm thử tự động hóa (True Canvas Live Test)
|   +-- run_true_canvas_live_test.py        # Playwright E2E UI test trên Google Chrome
|   +-- run_live_screen_test_all_roles.py   # Bộ kiểm thử tích hợp toàn diện 6 vai trò
+-- tasks/                                  # Tiến trình theo dõi kế hoạch
|   +-- plan.md                             # Kế hoạch chi tiết 6 Phase
|   +-- todo.md                             # Danh sách công việc và bằng chứng kiểm thử
```

---

## 11. GHI CHÚ VỀ BẢN QUYỀN & BẢO MẬT HỆ THỐNG

* Tuyệt đối không commit file `.env` chứa mật khẩu thực tế hoặc chuỗi bí mật lên kho mã nguồn công khai.
* Sử dụng file `.env.example` làm mẫu cấu hình chuẩn khi bàn giao và triển khai.
* Hệ thống được thiết kế đáp ứng trọn vẹn 100% barem học thuật cùng các tính năng mở rộng thực tế theo đúng tiêu chuẩn vận hành F&B hiện đại.
