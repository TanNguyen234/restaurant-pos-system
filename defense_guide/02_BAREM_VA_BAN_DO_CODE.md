# 02 — Bảng Đối Chiếu Core Barem & Bản Đồ Mở Code Trong 3 Giây

> Khi giảng viên hỏi: *"Chức năng X xử lý ở đâu, cho thầy xem code?"*, nhìn cột **Backend** hoặc **Flutter UI** để mở chính xác file trong 3 giây.

## 1. Xác thực, Bảo mật & Tài khoản

| Chức năng | Backend (.NET 10) | Flutter Client (`mobile/lib/`) |
| :--- | :--- | :--- |
| Đăng ký / Đăng nhập / Đổi MK / OAuth | [AuthController.cs](file:///d:/Download/restaurant_pos_app/backend/Api/Controllers/AuthController.cs) | [login_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/auth/login_page.dart), [register_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/auth/register_page.dart), [change_password_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/auth/change_password_page.dart) |
| PBKDF2-SHA256 Hash & Auto-Rehash | [PasswordHasher.cs](file:///d:/Download/restaurant_pos_app/backend/Services/PasswordHasher.cs) | — |
| JWT Token Signing & Role Claims | [JwtTokenService.cs](file:///d:/Download/restaurant_pos_app/backend/Services/JwtTokenService.cs) | [api_config.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/config/api_config.dart) (`authHeaders()`) |
| Gửi Email OTP thật qua SMTP | [EmailService.cs](file:///d:/Download/restaurant_pos_app/backend/Services/EmailService.cs) | [profile_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/auth/profile_page.dart), [login_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/auth/login_page.dart) |
| Phân quyền RBAC & Route Guards | `[Authorize(Roles = ...)]` trên Controllers | [main.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/main.dart) (`_buildTabsForRole`, `onGenerateRoute`), [user.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/models/user.dart) |
| Quản trị nhân sự / Khóa-Mở TK | [AccountController.cs](file:///d:/Download/restaurant_pos_app/backend/Api/Controllers/AccountController.cs), [AccountRepository.cs](file:///d:/Download/restaurant_pos_app/backend/Models/AccountRepository.cs) | [admin_user_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/admin/admin_user_page.dart) |

## 2. Danh mục, Thực đơn & Giỏ hàng Variant

| Chức năng | Backend (.NET 10) | Flutter Client (`mobile/lib/`) |
| :--- | :--- | :--- |
| Thực đơn, Lọc danh mục, Tìm kiếm, Sắp xếp | [CategoryController.cs](file:///d:/Download/restaurant_pos_app/backend/Api/Controllers/CategoryController.cs), [ProductController.cs](file:///d:/Download/restaurant_pos_app/backend/Api/Controllers/ProductController.cs) | [home_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/home_page.dart), [category_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/category_page.dart) |
| Chi tiết món, Gallery nhiều ảnh, Size/Topping | [ProductRepository.cs](file:///d:/Download/restaurant_pos_app/backend/Models/ProductRepository.cs) | [product_detail_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/product_detail_page.dart) |
| Giỏ hàng tách dòng theo Size/Topping/Note | — | [cart_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/cart_page.dart), [database_helper.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/utils/database_helper.dart) (`_buildVariantKey`, `deleteCartItem`) |
| CRUD Danh mục/Món & Upload/Xóa ảnh | [Helper.cs](file:///d:/Download/restaurant_pos_app/backend/Services/Helper.cs), [ProductController.cs](file:///d:/Download/restaurant_pos_app/backend/Api/Controllers/ProductController.cs) | [admin_category_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/admin/admin_category_page.dart), [admin_product_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/admin/admin_product_page.dart) |

## 3. Vận hành Phòng bàn, Đặt món & Đồng bộ Offline

| Chức năng | Backend (.NET 10) | Flutter Client (`mobile/lib/`) |
| :--- | :--- | :--- |
| Sơ đồ bàn, Mở/Chuyển/Gộp/Tách/Đặt bàn | [TableController.cs](file:///d:/Download/restaurant_pos_app/backend/Api/Controllers/TableController.cs), [TableRepository.cs](file:///d:/Download/restaurant_pos_app/backend/Models/TableRepository.cs) | [floor_table_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/table/floor_table_page.dart) |
| Tạo đơn (tính giá server-side + IdempotencyKey) | [OrderController.cs](file:///d:/Download/restaurant_pos_app/backend/Api/Controllers/OrderController.cs), [OrderRepository.cs](file:///d:/Download/restaurant_pos_app/backend/Models/OrderRepository.cs) | [order_checkout_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/order/order_checkout_page.dart), [order_repository.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/repositories/order_repository.dart) |
| Gọi thêm món vào bàn & Hủy từng món (Void) | [OrderController.cs](file:///d:/Download/restaurant_pos_app/backend/Api/Controllers/OrderController.cs) (`add-items`, `void-item`) | [order_detail_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/order/order_detail_page.dart) |
| Hàng đợi Offline & Tự đồng bộ 45s | Unique Index `UX_Orders_IdempotencyKey` | [offline_sync_service.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/services/offline_sync_service.dart), `OrdersSyncPage` trong [main.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/main.dart) |

## 4. Bếp KDS, Thu ngân POS, Ca làm & Hội viên

| Chức năng | Backend (.NET 10) | Flutter Client (`mobile/lib/`) |
| :--- | :--- | :--- |
| Màn hình Bếp/Bar, Gom món, Báo hết món 1-chạm | [KdsController.cs](file:///d:/Download/restaurant_pos_app/backend/Api/Controllers/KdsController.cs), `toggle-availability` | [kitchen_display_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/kitchen/kitchen_display_page.dart) |
| POS Thu ngân (Split-Screen / Tab), Chiết khấu tay | [OrderController.cs](file:///d:/Download/restaurant_pos_app/backend/Api/Controllers/OrderController.cs) (`discount`) | [cashier_pos_terminal_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/cashier/cashier_pos_terminal_page.dart) |
| Tiền mặt, VietQR động, Split Payment, VNPay Sandbox | [PaymentController.cs](file:///d:/Download/restaurant_pos_app/backend/Api/Controllers/PaymentController.cs), [PaymentRepository.cs](file:///d:/Download/restaurant_pos_app/backend/Models/PaymentRepository.cs) | [order_detail_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/order/order_detail_page.dart), [receipt_printer_service.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/services/receipt_printer_service.dart) |
| Mở ca, Đóng ca & Báo cáo Z-Report | [ShiftController.cs](file:///d:/Download/restaurant_pos_app/backend/Api/Controllers/ShiftController.cs), [ShiftRepository.cs](file:///d:/Download/restaurant_pos_app/backend/Models/ShiftRepository.cs) | [shift_management_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/cashier/shift_management_page.dart) |
| Quản lý đơn hàng & Top món bán chạy | [OrderController.cs](file:///d:/Download/restaurant_pos_app/backend/Api/Controllers/OrderController.cs) (`admin`, `lookup`) | [admin_order_list_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/admin/admin_order_list_page.dart) |
| Hội viên, Điểm thưởng, Đổi Voucher & Mã giảm giá | [LoyaltyController.cs](file:///d:/Download/restaurant_pos_app/backend/Api/Controllers/LoyaltyController.cs), [DiscountController.cs](file:///d:/Download/restaurant_pos_app/backend/Api/Controllers/DiscountController.cs) | [member_home_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/member/member_home_page.dart) |
