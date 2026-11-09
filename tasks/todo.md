# DANH SÁCH CÔNG VIỆC THỰC THI (TASK TRACKER) - GIAI ĐOẠN 2
**Trạng thái tổng thể:** HOÀN THÀNH 100% (PHASE 1 - 6 COMPLETED & VERIFIED)  
**Quy trình:** `/planning-and-task-breakdown` | `/systematic-debugging` | `/ui-ux-pro-max` | `/executing-plans`  
**Ngày hoàn thành:** 2026-11-09  

---

## Phase 1: Hoàn Thiện Barem Học Thuật (OAuth, Quên MK & Upload Ảnh)
- [x] **Task 1.1:** Modal Quên mật khẩu & Nhập mã OTP Email trên LoginPage (Barem 1.9)
  - *Evidence:* `backend/Models/AuthDtos.cs`, `AccountRepository.cs`, `AuthController.cs` (`POST /api/auth/request-otp`, `POST /api/auth/reset-password-otp`). Mobile `mobile/lib/views/auth/login_page.dart` & `member_home_page.dart`.
- [x] **Task 1.2:** Đăng nhập mạng xã hội Google / Facebook với One-Tap OAuth (Barem 1.10)
  - *Evidence:* `backend/Api/Controllers/AuthController.cs` (`POST /api/auth/oauth-login`). Mobile `auth_repository.dart` (`loginWithOAuth`) & `login_page.dart` (Google & Facebook One-Tap buttons).
- [x] **Task 1.3:** Quản lý Upload ảnh danh mục & món ăn (Preview, lưu wwwroot, dọn file rác) (Barem 2.6 & 3.2)
  - *Evidence:* `backend/Services/Helper.cs` (`SaveImage`, `DeleteImage`). Mobile `admin_category_page.dart` & `admin_product_page.dart` with image preview and cleanup.

## Phase 2: Nâng Tầm Quản Lý Bàn & Sơ Đồ Khu Vực F&B
- [x] **Task 2.1:** Quản lý Khu vực & Bàn ăn trực tiếp trên Mobile (CRUD Area & Table)
  - *Evidence:* `backend/Models/TableDtos.cs`, `TableRepository.cs`, `TableController.cs` (`POST/PUT/DELETE /api/table`, `POST/PUT/DELETE /api/table/area`). Mobile `TableRepository` & `floor_table_page.dart` modal sheet.
- [x] **Task 2.2:** Hiển thị Thời gian ngồi (Seating Timer) & Tạm tính realtime trên thẻ bàn
  - *Evidence:* `DiningTable` model enriched with `orderCreatedAt`, `runningTotal`, `itemCount`, `seatingDurationText`. Live badges on table cards in `floor_table_page.dart`.
- [x] **Task 2.3:** Giao diện Tách bàn / Tách đơn nâng cao (Interactive Split Bill theo từng món)
  - *Evidence:* Multi-step table action sheet, item selection, bill split dialogs in `floor_table_page.dart` and `cashier_pos_terminal_page.dart`.

## Phase 3: Xử Lý Ngoại Lệ Bếp KDS & Báo Hết Món Thời Gian Thực
- [x] **Task 3.1:** Nghiệp vụ Hủy món / Trả món có lý do (Void Item with Reason)
  - *Evidence:* `backend/Models/OrderDtos.cs` (`VoidItemDto`), `OrderRepository.cs` (`VoidOrderItemAsync`), `OrderController.cs` (`POST /api/order/{id}/void-item`). Mobile modal with reason dropdown in `order_detail_page.dart`.
- [x] **Task 3.2:** 1-Chạm Báo hết món (Sold-Out Toggle) trên KDS & Admin Menu
  - *Evidence:* `backend/Api/Controllers/ProductController.cs` (`PUT /api/product/{id}/toggle-availability`). Mobile 1-tap modal in `kitchen_display_page.dart`.
- [x] **Task 3.3:** Âm thanh thông báo & Rung haptic khi có order mới rơi xuống Bếp
  - *Evidence:* `SystemSound.play(SystemSoundType.alert)` and `HapticFeedback.vibrate()` in `kitchen_display_page.dart`.

## Phase 4: Công Cụ Thu Ngân Nâng Cao & Bảng Điều Khiển Doanh Thu
- [x] **Task 4.1:** In lại hóa đơn (Reprint Receipt) & Chiết khấu thủ công (Manual Discount %)
  - *Evidence:* `ReceiptPrinterService` supports watermark `[BẢN IN LẠI / DUPLICATE]`. Manual discount dialog with % or VNĐ input in `cashier_pos_terminal_page.dart`.
- [x] **Task 4.2:** Dashboard Thống kê Doanh thu & Top 5 Món Bán Chạy (Charts & KPIs)
  - *Evidence:* 4-KPI summary header + Top 5 Best-Selling items with comparative progress bars in `admin_order_list_page.dart`.
- [x] **Task 4.3:** Hỗ trợ Thanh toán Hỗn hợp Đa phương thức (Tiền mặt + Chuyển khoản)
  - *Evidence:* Interactive Split Payment modal (Cash + Dynamic VietQR) with automatic balance calculation in `cashier_pos_terminal_page.dart`.

## Phase 5: Cổng Khách Hàng Thời Gian Thực & Đổi Điểm Thưởng
- [x] **Task 5.1:** Màn hình Theo dõi trạng thái đơn hàng thời gian thực cho Khách hàng
  - *Evidence:* 3-step live tracking stepper (Tiếp nhận -> Đang chế biến -> Sẵn sàng phục vụ), payment badges, and refresh button in `member_home_page.dart`.
- [x] **Task 5.2:** Cơ chế Đổi điểm thưởng tích lũy lấy Voucher giảm giá (Redeem Points)
  - *Evidence:* Interactive loyalty points deduction (`_userPoints`), confirmation modal, voucher code unlocking, celebratory haptic feedback in `member_home_page.dart`.

## Phase 6: Tẩy Trần "AI Slop" Toàn Diện & Đồng Bộ Design System Pro Max
- [x] **Task 6.1:** Thay thế 100% Spinner bằng Skeleton Shimmer Loading toàn hệ thống
  - *Evidence:* Implemented `mobile/lib/widgets/skeleton_loading.dart` (`SkeletonShimmer`, `SkeletonBox`, `SkeletonCardPlaceholder`, `SkeletonListPlaceholder`, `SkeletonGridPlaceholder`). Integrated across `home_page.dart`, `category_page.dart`, `cart_page.dart`, `product_detail_page.dart`, `order_checkout_page.dart`, `order_detail_page.dart`, `admin_order_list_page.dart`, `cashier_pos_terminal_page.dart`.
- [x] **Task 6.2:** Sửa dứt điểm các URL ảnh hardcoded localhost sang ApiConfig động
  - *Evidence:* Replaced all `'http://localhost:5138'` in `mobile/lib/models/category.dart` and `mobile/lib/views/cart_page.dart` with `${ApiConfig.baseUrl.replaceAll('/api', '')}`.
- [x] **Task 6.3:** Tích hợp Haptic Feedback, Badge Animation và kiểm thử hồi quy 100% Pass
  - *Evidence:* `dotnet build backend/WebApi.csproj` -> 0 warnings, 0 errors. `flutter analyze` -> No issues found! `flutter test` -> 82/82 tests passed!
