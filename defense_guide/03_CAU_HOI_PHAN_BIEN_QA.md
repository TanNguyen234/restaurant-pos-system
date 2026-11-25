# 03 — 18 Câu Hỏi Phản Biện & Đáp Án Chuẩn Vấn Đáp

> Đáp án được viết ngắn gọn, đi thẳng vào kỹ thuật và **trích đúng tên file / cơ chế thực tế** trong source code.

---

### Nhóm 1: Kiến trúc & Đa nền tảng

**Câu 1: Tại sao chọn kiến trúc tách ASP.NET Core 10 Web API và Flutter thay vì viết Web MVC truyền thống?**
- Tách API RESTful giúp **1 Backend duy nhất phục vụ đồng thời 3 nền tảng client** (Android cho phục vụ đi bàn, Web Browser cho khách/quản trị, Windows Desktop cho quầy Thu ngân & màn hình Bếp KDS) mà không phải viết lại business logic.
- Phía Backend chia lớp `Controller → SiteProvider → Repository → EF Core 10` giúp dễ test và bảo trì.

**Câu 2: Cùng một app Flutter, làm sao chạy Offline được trên cả Android, Windows Desktop và Web Browser?**
- Trong [database_helper.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/utils/database_helper.dart):
  - Trên **Android**: dùng `sqflite` SQLite gốc.
  - Trên **Windows/Linux/macOS Desktop**: gọi `DatabaseHelper.initDesktopFfi()` (`sqfliteFfiInit()` + `databaseFactoryFfi`).
  - Trên **Web Browser**: SQLite không chạy trực tiếp nên lớp tương thích tự động chuyển sang cache bộ nhớ + bền hóa qua `SharedPreferences` (`localStorage`), giữ nguyên 100% chữ ký hàm cho các tầng trên.

**Câu 3: Khi mất mạng rồi có mạng trở lại, làm sao đảm bảo đơn offline không bị gửi trùng 2 lần (double-order)?**
- Mỗi đơn tạo ở [order_repository.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/repositories/order_repository.dart) tự sinh `IdempotencyKey` bằng `Uuid().v4()` trước khi gửi hoặc xếp hàng đợi `offline_orders`.
- [offline_sync_service.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/services/offline_sync_service.dart) tự động đồng bộ định kỳ 45s (có khóa chống chạy song song) và xóa đơn cục bộ ngay khi server xác nhận HTTP 200.
- Phía SQL Server có Filtered Unique Index `UX_Orders_IdempotencyKey` và `OrderRepository.CreateOrderAsync` kiểm tra trùng khóa trước khi insert — nếu gửi lại cùng khóa, server trả về chính đơn đã tạo, không bao giờ tạo đơn thứ hai.

---

### Nhóm 2: Bảo mật & Phân quyền (RBAC)

**Câu 4: Em lưu mật khẩu thế nào? Nếu DB cũ có hash SHA-256 thì nâng cấp ra sao?**
- Trong [PasswordHasher.cs](file:///d:/Download/restaurant_pos_app/backend/Services/PasswordHasher.cs), mật khẩu mới được băm bằng **PBKDF2-SHA256** với salt ngẫu nhiên 16 byte và **100.000 iterations**.
- Khi người dùng cũ (từ script SQL seed dùng SHA-256 hex) đăng nhập thành công, hệ thống **tự động re-hash nâng cấp sang PBKDF2-SHA256** và lưu lại DB mà không làm gián đoạn tài khoản.

**Câu 5: Nếu sinh viên khác dùng Postman sửa JWT hoặc gọi thẳng API Admin bằng tài khoản Phục vụ thì sao?**
- Thứ nhất, JWT được ký bằng HMAC-SHA256 trong [JwtTokenService.cs](file:///d:/Download/restaurant_pos_app/backend/Services/JwtTokenService.cs), khóa ký nạp từ biến môi trường / `backend/.env` (bị `.gitignore` chặn), nếu thiếu sẽ fail-fast ngay lúc khởi động.
- Thứ hai, **phân quyền được khóa hai lớp**:
  - Frontend ([main.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/main.dart)): ẩn tab theo role + Route Guard chặn điều hướng kèm màn hình `Không đủ thẩm quyền (403)`.
  - Backend: mọi controller nhạy cảm gắn `[Authorize(Roles = "...")]` ở cả class lẫn action (ví dụ `/api/account/members` chỉ `ADMIN,MANAGER`; `/api/shift/*` chỉ `ADMIN,MANAGER,CASHIER`), gọi sai role sẽ trả **403 Forbidden** hoặc thiếu token trả **401 Unauthorized**.

**Câu 6: Đăng nhập mạng xã hội (OAuth Google/Facebook/Zalo) có lỗ hổng chiếm quyền tài khoản Admin nếu trùng email không?**
- Không. Trong [AuthController.cs](file:///d:/Download/restaurant_pos_app/backend/Api/Controllers/AuthController.cs) (`oauth-login`), hệ thống kiểm tra nếu email đã tồn tại và thuộc các vai trò nội bộ (`ADMIN`, `MANAGER`, `CASHIER`, `WAITER`, `KITCHEN`...) thì **từ chối đăng nhập OAuth ngay lập tức**, buộc dùng xác thực nội bộ mật khẩu mạnh. Chỉ cho phép auto-login/tạo mới cho nhóm `MEMBER`.

**Câu 7: OTP xác thực Email và Quên mật khẩu chạy thật hay chỉ mock `devOtp`?**
- Chạy thật hoàn toàn qua [EmailService.cs](file:///d:/Download/restaurant_pos_app/backend/Services/EmailService.cs) (Gmail SMTP), lưu mã OTP 6 số kèm thời hạn 5 phút trong SQL Server và **tuyệt đối không trả `devOtp` trong JSON response**.

**Câu 8: CORS khi chạy Flutter Web port ngẫu nhiên có bị chặn không? Sản phẩm thực tế xử lý thế nào?**
- Trong [Program.cs](file:///d:/Download/restaurant_pos_app/backend/Program.cs), danh sách nguồn hợp lệ đọc từ `ALLOWED_ORIGINS` (ưu tiên biến môi trường hệ thống trước `.env`). Ở môi trường `Development`, `PosCorsPolicy` cho phép thêm mọi cổng `localhost`/`127.0.0.1` phục vụ Flutter Web dev, còn ở Production chỉ cho phép đúng domain nằm trong `ALLOWED_ORIGINS`.

---

### Nhóm 3: Nghiệp vụ POS, Bếp KDS & Giỏ hàng

**Câu 9: Làm sao chống khách hàng F12 sửa giá món ăn trước khi gửi API đặt đơn (`POST /api/order`)?**
- Client **chỉ gửi `productId`, `quantity` và `attributeIds`**. [OrderRepository.cs](file:///d:/Download/restaurant_pos_app/backend/Models/OrderRepository.cs) luôn truy vấn lại đơn giá `Products.Price` và `ProductAttributes.ExtraPrice` trực tiếp từ SQL Server, kiểm tra trạng thái `IsAvailable` rồi mới tính `TotalAmount`, `DiscountAmount` và `FinalAmount`.

**Câu 10: Nếu khách đặt 2 ly Cà phê sữa đá — 1 ly "Ít đường" và 1 ly "Nhiều sữa" — giỏ hàng xử lý thế nào?**
- Trong [database_helper.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/utils/database_helper.dart), `cart_items` không gộp theo `product_id` đơn thuần mà tạo khóa biến thể `_buildVariantKey` (`product_id | modifiers_json | note`). Khi tăng/giảm/xóa sẽ thao tác theo khóa chính từng dòng (`deleteCartItem(id)`, `updateCartItemQuantityById`), không bao giờ xóa nhầm ly còn lại.

**Câu 11: Nếu Bếp hết nguyên liệu sau khi Phục vụ đã gửi order thì xử lý sao cho đúng kế toán & kho?**
- Bếp trưởng dùng 2 cơ chế trên [kitchen_display_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/kitchen/kitchen_display_page.dart):
  1. **1-Chạm Báo hết món** (`PUT /api/product/{id}/toggle-availability`): tắt mở bán món đó ngay lập tức trên toàn menu và phát sự kiện SignalR để không nhận thêm order mới.
  2. **Hủy món (`POST /api/kds/{orderDetailId}/void`)**: đánh dấu `CookingStatus = 4` (Đã hủy món) kèm lý do, giữ vết lịch sử kiểm toán, **tự động hoàn lại tồn kho nguyên liệu (BOM `REFUND` trong `StockTransactions`)** và **tính lại `TotalAmount` / `FinalAmount`** của hóa đơn trong Transaction.

**Câu 12: Quản lý phòng bàn có bị xung đột hoặc mất đơn khi Chuyển bàn / Gộp bàn / Tách bàn không?**
- Mọi thao tác trong [TableRepository.cs](file:///d:/Download/restaurant_pos_app/backend/Models/TableRepository.cs) (`TransferTable`, `MergeTables`, `SplitTable`) đều bọc trong `BeginTransaction()` và thu ngân/phục vụ có thể thao tác trực tiếp bằng modal **Gộp bàn / Tách món** trên [cashier_pos_terminal_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/cashier/cashier_pos_terminal_page.dart) và [floor_table_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/table/floor_table_page.dart). Hệ thống cũng chặn thao tác trả bàn trống (`Status = 0`) nếu bàn đó vẫn còn `Order` chưa thanh toán (`PaymentStatus == 0`).

**Câu 13: Khi Bếp xong 1 phần món trên đơn, trạng thái `Order.Status` đồng bộ thế nào?**
- Khi KDS chuyển từng `OrderDetail.CookingStatus` (`0 -> 1 -> 2 -> 3`), backend kiểm tra tổng thể các món active trong đơn để tự nâng `Order.Status` sang `Đang chế biến` (1) hoặc `Đã phục vụ` (2) đồng bộ.

---

### Nhóm 4: Thanh toán, Ca làm việc & Khách hàng thân thiết

**Câu 14: Hệ thống hỗ trợ những phương thức thanh toán nào? VNPay kiểm tra toàn vẹn ra sao?**
- Hỗ trợ 4 luồng thực tế trong [PaymentController.cs](file:///d:/Download/restaurant_pos_app/backend/Api/Controllers/PaymentController.cs): **Tiền mặt** (`cash`), **VietQR động chuẩn NAPAS 247** (`vietqr/{orderId}` kèm số tiền và nội dung chuyển khoản tự động), **Chia hóa đơn Split Payment** (`confirm` nhiều lần cộng dồn vào `PaidAmount`), và **VNPay Sandbox** (`vnpay/create-url` + `vnpay/callback`).
- Mọi URL và callback VNPay đều ký và xác thực chữ ký **HMAC-SHA512** bằng `VNPay:HashSecret` theo thứ tự bảng chữ cái tham số `vnp_*`.

**Câu 15: Báo cáo Z-Report cuối ca đối soát két tiền hoạt động thế nào?**
- Thu ngân mở ca bằng `POST /api/shift/open` nhập tiền mặt đầu ca (`InitialCash`). Mọi thanh toán phát sinh được tự động gắn `ShiftId`.
- Khi đóng ca (`POST /api/shift/close`), hệ thống tổng hợp doanh thu phân tách theo từng kênh (`TotalSalesCash`, `TotalSalesVietQr`, `TotalSalesVnPay`), tính `ExpectedCashInDrawer = InitialCash + TotalSalesCash` và đối chiếu với `ActualCashInDrawer` thu ngân đếm thực tế để ghi nhận chênh lệch (`Discrepancy`).

**Câu 16: Điểm Loyalty của hội viên được cộng và tiêu thế nào?**
- Khi hóa đơn thanh toán hoàn tất (`isFullyPaid == true`) và gắn với tài khoản `MEMBER` / `VIP_MEMBER`, [PaymentRepository.cs](file:///d:/Download/restaurant_pos_app/backend/Models/PaymentRepository.cs) tự động cộng `floor(FinalAmount / 1.000)` điểm thưởng và ghi log vào `LoyaltyTransactions` (`Type = 'EARN'`).
- Ở tab Hội viên ([member_home_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/member/member_home_page.dart)), khách có thể đổi điểm (`POST /api/loyalty/redeem`) lấy voucher thật lưu DB để áp mã giảm giá khi đặt đơn.

---

### Nhóm 5: Kiểm thử & Chất lượng kỹ thuật

**Câu 17: Nhóm/em đã kiểm thử hệ thống bằng những cách nào?**
- Kết hợp **3 tầng kiểm thử**:
  1. **Unit & Widget Tests** (`flutter analyze --no-fatal-infos` = 0 lỗi, `flutter test -j 1` = **89/89 pass** bao phủ RBAC, giỏ hàng variant, SignalR frame parser, ESC/POS bytes & Vietnamese folding, QR `?tableId=` parser, BOM UI, offline fallback và hành trình người dùng).
  2. **API + SignalR + BOM Integration Test trên SQL Server Express thật**: kiểm tra 100% quy trình 6 vai trò + Khách QR Self-Order, SignalR WebSocket push `/hubs/pos`, trừ kho BOM khi đặt món & hoàn kho khi void, Export CSV, negative RBAC 401/403, IdempotencyKey, VietQR/VNPay và toàn vẹn ảnh catalog.
  3. **Browser Live QA (Playwright Chromium)** ở 2 kích thước **Mobile (`390×844`)** và **Desktop (`1280×800`)**, bấm thao tác thật qua ngữ nghĩa Flutter Semantics, đạt **0 `pageerror`, 0 `RenderFlex overflow`, 0 HTTP 500, 0 ảnh vỡ**, kèm build thành công cả **Flutter Web** lẫn **Windows Desktop (`restaurant_pos_app.exe`)**.

**Câu 18: Hệ thống đã xử lý đồng bộ thời gian thực và quản lý định lượng kho thế nào? Hướng mở rộng tiếp?**
- Cả hai tính năng nâng cao trọng điểm đã được triển khai hoàn chỉnh trong phiên bản hiện tại: **SignalR `/hubs/pos`** đẩy cập nhật `< 0.5s` giữa Phục vụ – Bếp KDS – Thu ngân – Quản lý kho; và module **BOM Inventory** ([InventoryController.cs](file:///d:/Download/restaurant_pos_app/backend/Api/Controllers/InventoryController.cs), [admin_inventory_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/admin/admin_inventory_page.dart)) tự trừ nguyên liệu theo công thức khi order và hoàn kho khi void, kèm cảnh báo tồn thấp (`InventoryAlert`). Ngoài ra hệ thống còn có **QR Self-Order tại bàn**, **Biểu đồ doanh thu + CSV**, và **In nhiệt ESC/POS LAN TCP 9100**. Hướng mở rộng thương mại v3 xem tại [05_DE_XUAT_NANG_CAP.md](file:///d:/Download/restaurant_pos_app/defense_guide/05_DE_XUAT_NANG_CAP.md).
