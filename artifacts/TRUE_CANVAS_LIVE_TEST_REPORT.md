# BÁO CÁO NGHIỆM THU TRUE CANVAS REAL UI LIVE TEST

- **Thời gian thực thi:** `2026-11-09T21:21:18.048269`
- **Tổng thời gian chạy:** `184.87 giây`
- **Chế độ kiểm thử:** Google Chrome Headed (Tương tác thật qua Accessibility Semantics DOM)
- **Tổng số ca kiểm thử:** `24` | **PASS:** `24` | **FAIL:** `0` | **Tỷ lệ:** `100.0%`

## 1. BẢNG TỔNG HỢP KẾT QUẢ THEO TỪNG VAI TRÒ (ROLE)

| STT | Role | Mã Test | Mô Tả Nghiệp Vụ Tương Tác | Kết Quả | Ảnh Chụp Minh Chứng |
|:---:|:---|:---|:---|:---:|:---|
| 1 | `GUEST` | `UI-GUEST-01` | Trình duyệt render Sơ đồ bàn ăn nhà hàng (FloorTablePage) | ✅ PASS | [ui01_guest_floor_plan.png](artifacts/true_canvas_screens\ui01_guest_floor_plan.png) |
| 2 | `GUEST` | `UI-GUEST-02` | Tương tác mở Modal Sheet Thao tác Bàn ăn (Table Action Sheet) | ✅ PASS | [ui02_guest_table_action_sheet.png](artifacts/true_canvas_screens\ui02_guest_table_action_sheet.png) |
| 3 | `GUEST` | `UI-GUEST-03` | Trang chủ duyệt thực đơn món ăn & khuyến mãi (HomePage) | ✅ PASS | [ui03_guest_home_catalog.png](artifacts/true_canvas_screens\ui03_guest_home_catalog.png) |
| 4 | `GUEST` | `UI-GUEST-04` | Tương tác gõ tìm kiếm món ăn 'Cà phê' trên thanh tìm kiếm | ✅ PASS | [ui04_guest_search_results.png](artifacts/true_canvas_screens\ui04_guest_search_results.png) |
| 5 | `GUEST` | `UI-GUEST-05` | Xem chi tiết món ăn kèm hình ảnh lớn & món liên quan | ✅ PASS | [ui05_guest_product_detail.png](artifacts/true_canvas_screens\ui05_guest_product_detail.png) |
| 6 | `GUEST` | `UI-GUEST-06` | Mở Trung tâm Vận hành Phân quyền hiển thị cổng đăng nhập | ✅ PASS | [ui06_guest_operations_gate.png](artifacts/true_canvas_screens\ui06_guest_operations_gate.png) |
| 7 | `WAITER` | `UI-WTR-01` | Giao diện Đăng nhập hệ thống POS cho Phục vụ | ✅ PASS | [ui07_waiter_login_screen.png](artifacts/true_canvas_screens\ui07_waiter_login_screen.png) |
| 8 | `WAITER` | `UI-WTR-02` | Đăng nhập thành công, phiên làm việc phục vụ bàn được kích hoạt | ✅ PASS | [ui08_waiter_authenticated_session.png](artifacts/true_canvas_screens\ui08_waiter_authenticated_session.png) |
| 9 | `WAITER` | `UI-WTR-03` | Màn hình Giỏ hàng phục vụ bàn (CartPage) | ✅ PASS | [ui09_waiter_cart_items.png](artifacts/true_canvas_screens\ui09_waiter_cart_items.png) |
| 10 | `WAITER` | `UI-WTR-04` | Màn hình Xác nhận Đặt món & Chọn bàn gửi bếp | ✅ PASS | [ui10_waiter_order_checkout.png](artifacts/true_canvas_screens\ui10_waiter_order_checkout.png) |
| 11 | `WAITER` | `UI-WTR-05` | Chi tiết Hóa đơn bàn kèm trạng thái món ăn | ✅ PASS | [ui11_waiter_order_detail.png](artifacts/true_canvas_screens\ui11_waiter_order_detail.png) |
| 12 | `KDS` | `UI-KDS-01` | Màn hình Bếp KDS thời gian thực hiển thị danh sách order | ✅ PASS | [ui12_kds_active_queue.png](artifacts/true_canvas_screens\ui12_kds_active_queue.png) |
| 13 | `KDS` | `UI-KDS-02` | Mở hộp thoại 1-Chạm Báo hết món (Sold-Out Dialog) trên KDS | ✅ PASS | [ui13_kds_soldout_toggle_dialog.png](artifacts/true_canvas_screens\ui13_kds_soldout_toggle_dialog.png) |
| 14 | `CASHIER` | `UI-CSH-01` | Giao diện Quầy Thu Ngân POS Quản lý Đơn & Bàn ăn | ✅ PASS | [ui14_cashier_pos_terminal.png](artifacts/true_canvas_screens\ui14_cashier_pos_terminal.png) |
| 15 | `CASHIER` | `UI-CSH-02` | Giao diện Quản lý Ca làm việc & Bàn giao két tiền Thu Ngân | ✅ PASS | [ui15_cashier_shift_management.png](artifacts/true_canvas_screens\ui15_cashier_shift_management.png) |
| 16 | `MEMBER` | `UI-MEM-01` | Tương tác mở Modal Quên mật khẩu / Khôi phục OTP Email | ✅ PASS | [ui16_member_forgot_password_modal.png](artifacts/true_canvas_screens\ui16_member_forgot_password_modal.png) |
| 17 | `MEMBER` | `UI-MEM-02` | Điền mã OTP thực tế (981548) vào ô xác thực trên giao diện | ✅ PASS | [ui17_member_otp_filled_screen.png](artifacts/true_canvas_screens\ui17_member_otp_filled_screen.png) |
| 18 | `MEMBER` | `UI-MEM-03` | Cổng thành viên & Thanh theo dõi tiến độ đơn hàng thời gian thực | ✅ PASS | [ui18_member_home_tracking.png](artifacts/true_canvas_screens\ui18_member_home_tracking.png) |
| 19 | `MEMBER` | `UI-MEM-04` | Hộp thoại Đổi điểm thưởng tích lũy (Loyalty Points Redeem) | ✅ PASS | [ui19_member_redeem_points_modal.png](artifacts/true_canvas_screens\ui19_member_redeem_points_modal.png) |
| 20 | `ADMIN` | `UI-ADM-01` | Bảng điều khiển 4 KPI Doanh thu & Top 5 Món bán chạy nhất | ✅ PASS | [ui20_admin_kpi_bestsellers_dashboard.png](artifacts/true_canvas_screens\ui20_admin_kpi_bestsellers_dashboard.png) |
| 21 | `ADMIN` | `UI-ADM-02` | Quản lý danh mục thực đơn kèm ảnh đại diện & sắp xếp | ✅ PASS | [ui21_admin_category_management.png](artifacts/true_canvas_screens\ui21_admin_category_management.png) |
| 22 | `ADMIN` | `UI-ADM-03` | Hộp thoại Thêm danh mục mới có tải ảnh preview | ✅ PASS | [ui22_admin_add_category_modal.png](artifacts/true_canvas_screens\ui22_admin_add_category_modal.png) |
| 23 | `ADMIN` | `UI-ADM-04` | Quản lý món ăn & phân trang danh mục thực đơn | ✅ PASS | [ui23_admin_product_pagination.png](artifacts/true_canvas_screens\ui23_admin_product_pagination.png) |
| 24 | `ADMIN` | `UI-ADM-05` | Xem danh sách nhân sự & ma trận phân quyền 6 Role RBAC | ✅ PASS | [ui24_admin_user_rbac_matrix.png](artifacts/true_canvas_screens\ui24_admin_user_rbac_matrix.png) |

## 2. XÁC NHẬN TÍNH ĐỘC BẢN CỦA TẬP ẢNH MINH CHỨNG
- 100% các bức ảnh chụp lại từng màn hình, modal popup, dialog chiết khấu, QR code và bottomsheet đều là **trạng thái thị giác độc bản (Zero duplicate screens)**.
- Mọi thao tác form (gõ chữ, chọn bàn, chuyển tab, mở modal) được thực hiện trực tiếp bởi Playwright trên cây DOM thật của Flutter Web.

---
*Báo cáo được khởi tạo tự động bởi True Canvas Automation Harness.*