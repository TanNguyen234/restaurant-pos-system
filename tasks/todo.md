# DANH SÁCH CÔNG VIỆC THỰC THI (TASK TRACKER)
**Trạng thái tổng thể:** COMPLETED (100% VERIFIED)  
**Quy trình:** `/lean-execute` (TDD, Systematic Debugging, UI/UX Pro Max)  
**Ngày hoàn thành:** 2026-11-09  

---

## Phase 1: Nền tảng Bảo mật, CSDL & Điều hướng theo Vai trò (RBAC Shell)
- [x] **Task 1.1:** Bảo vệ toàn bộ Controller bằng `[Authorize(Roles = "...")]` & Thử nghiệm RBAC
  - *Evidence:* `scripts/verify_r3_http_rbac.ps1` chạy 25/25 PASS (100%), kiểm soát chặt chẽ 6 vai trò: ADMIN, MANAGER, CASHIER, WAITER, KITCHEN, MEMBER.
- [x] **Task 1.2:** Mở rộng CSDL SQL Server & Entity Framework: Thêm bảng `Shifts`, `Reservations`, `Discounts`, hoàn thiện `OrderDetailModifiers`
  - *Evidence:* SQL script `scripts/add_extended_fb_tables.sql` đã provisioning lên `RestaurantPos_Acceptance`. EF Core Context mapping 14 DbSet đầy đủ.
- [x] **Task 1.3:** Xây dựng `RoleAwareScaffold`: Điều hướng tự động theo 6 vai trò, xóa bỏ nút Floating Button ẩn và thanh điều hướng cào bằng
  - *Evidence:* `mobile/lib/main.dart` phân quyền rẽ nhánh chính xác theo vai trò đăng nhập; Cashier thấy POS + Shift, Kitchen thấy KDS, Waiter thấy Sơ đồ bàn, Member thấy Thẻ thành viên VIP.

## Phase 2: Toàn diện Nghiệp vụ Bàn, Thực đơn, Modifiers & Offline Menu Cache
- [x] **Task 2.1:** Nghiệp vụ Gộp bàn (Merge) và Tách bàn / Tách đơn (Split bill)
  - *Evidence:* Đã bổ sung `/api/table/merge`, `/api/table/split` trong backend (`TableRepository.cs`, `TableController.cs`) và modal tương tác trực quan trong `floor_table_page.dart`.
- [x] **Task 2.2:** Nghiệp vụ Đặt bàn trước (Reservation): Nhập giờ đến, tên khách, số ghế, hiển thị màu Cam
  - *Evidence:* `/api/table/reserve`, `/api/table/reservation/{id}/check-in`, giao diện đặt bàn & nhận khách trạng thái màu Hổ phách (Amber) chuyên nghiệp.
- [x] **Task 2.3:** Chuẩn hóa lưu trữ Modifiers (Size, Topping, Phụ thu) vào bảng `OrderDetailModifiers` trong CSDL
  - *Evidence:* Size & Topping được lưu cấu trúc JSON trong SQLite cart, đẩy vào API qua `CreateOrderItemModifierDto`, lưu trữ persistent trong bảng SQL Server `OrderDetailModifiers`.
- [x] **Task 2.4:** Bộ nhớ đệm Thực đơn Ngoại tuyến vào SQLite: Lưu danh mục & món ăn, chạy offline 100% khi mất mạng
  - *Evidence:* `CategoryRepository` và `ProductRepository` tích hợp SQLite caching trong suốt, tự động fallback khi mất mạng, xóa bỏ hoàn toàn mock in-memory.

## Phase 3: Màn hình Bếp KDS Chuyên nghiệp & In Hóa đơn Nhiệt / PDF
- [x] **Task 3.1:** KDS phân trạm Bếp nấu (Food) vs Quầy Bar (Drink), chế độ Gom món (Batch Prep), chuông báo đơn mới và timer 3 mức màu
  - *Evidence:* `mobile/lib/views/kitchen/kitchen_display_page.dart` hỗ trợ lọc Food/Drink, Gom món tổng lực (tổng số lượng từng món cần chế biến), timer cảnh báo trực quan Xanh/Vàng/Đỏ.
- [x] **Task 3.2:** Module In Hóa đơn nhiệt ESC/POS (58mm/80mm) và Xuất PDF: Hỗ trợ "Phiếu tạm tính" và "Hóa đơn thanh toán" có mã VietQR động
  - *Evidence:* `mobile/lib/services/receipt_printer_service.dart` xem trước hóa đơn nhiệt chuẩn 58mm/80mm, xuất file PDF, tích hợp VietQR chuẩn NAPAS 247.

## Phase 4: POS Thu ngân Split-Screen, Quản lý Ca (Shift) & Thanh toán Đa kênh
- [x] **Task 4.1:** Giao diện POS Thu ngân Split-Screen cho Tablet/Desktop với bàn phím số Numpad và các nút tiền mệnh giá nhanh (`50k`, `100k`, `200k`, `500k`, `Đủ tiền`)
  - *Evidence:* `mobile/lib/views/cashier/cashier_pos_terminal_page.dart` chia 2 cột công nghiệp (Catalog + Bill), tính tiền thừa tự động, in tạm tính 1 chạm.
- [x] **Task 4.2:** Quản lý Ca làm việc (Shift Register): Mở ca nhập tiền lẻ float, Đóng ca đối soát tiền mặt & in Z-Report
  - *Evidence:* `mobile/lib/views/cashier/shift_management_page.dart` kết nối `/api/shift/open`, `/api/shift/close`, `/api/shift/{id}/z-report`, đối soát chênh lệch tiền mặt thực tế vs hệ thống.
- [x] **Task 4.3:** Luồng Gọi thêm món (Add items) vào bàn đang có khách mà không tạo đơn mới
  - *Evidence:* `/api/order/{id}/add-items` backend endpoint hoạt động, tự động cộng dồn món và cập nhật `SubTotal`, `FinalAmount`, thông báo tức thời sang KDS.

## Phase 5: Cổng Khách hàng (Member Portal), Voucher & Xác thực Email OTP
- [x] **Task 5.1:** Cổng Khách hàng (Member Portal): Xem Thực đơn số, Quét QR bàn tự gọi món, Xem điểm tích lũy & Hạng thẻ, Tra cứu đơn hàng theo SĐT
  - *Evidence:* `mobile/lib/views/member/member_home_page.dart` thẻ VIP Gold sang trọng, ví voucher, tra cứu đơn bằng SĐT, gọi món tự động theo mã QR bàn.
- [x] **Task 5.2:** Engine Khuyến mãi / Voucher: Áp dụng mã giảm giá (% hoặc số tiền), trừ điểm hội viên vào hóa đơn
  - *Evidence:* `/api/discount/active`, `/api/discount/validate` backend hỗ trợ mã `BANMOI10`, `GIAM20K`, `VIPMEMBER`. `order_checkout_page.dart` tích hợp ô nhập & xác thực trực tiếp.
- [x] **Task 5.3:** Xác thực nâng cao: Gửi mã OTP xác thực email và Quên mật khẩu (đạt trọn điểm cộng Barem 1.8 và 1.9)
  - *Evidence:* `/api/auth/request-otp` và `/api/auth/reset-password-otp` hoạt động ổn định, có modal UI phục hồi mật khẩu tiện lợi trên Mobile.

## Phase 6: Tẩy trần "AI Slop" Toàn diện & Kiểm thử Tích hợp E2E
- [x] **Task 6.1:** Áp dụng Design System "Modern Artisan Bistro" lên toàn bộ màn hình, chuẩn hóa Touch Targets $\ge 48$ px, thay thế vòng quay bằng Skeleton loading, thêm Empty states minh họa đồ ăn ấm cúng, xóa bỏ toàn bộ mock web trong `database_helper.dart`
  - *Evidence:* Đã thanh lọc `database_helper.dart` (xóa `_webCart`, `_webOrders`, `_webSession`), thay bằng SQLite thực, nâng cấp UI theo bảng màu Warm Bistro Slate & Amber.
- [x] **Task 6.2:** Tổng kiểm thử E2E Full User Journey: Mở ca -> Đặt bàn -> Gọi món -> Bếp KDS -> In tạm tính -> Thanh toán VietQR/VNPay/Tiền mặt -> Giải phóng bàn -> Đóng ca in Z-Report. Đảm bảo 100% test pass
  - *Evidence:*
    - Backend Build: 0 Warning, 0 Error (`dotnet build backend/WebApi.csproj`).
    - Backend E2E Business Acceptance: 26/26 PASS (100% pass rate in `scripts/verify_e2e_business_flow.ps1`).
    - Backend RBAC Matrix: 25/25 PASS (100% pass rate in `scripts/verify_r3_http_rbac.ps1`).
    - Mobile Static Analysis: `flutter analyze` -> 0 issues found!
    - Mobile Test Suite: 82/82 test assertions PASS (100% pass rate in `flutter test`).
