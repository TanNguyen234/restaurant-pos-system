# BÁO CÁO NGHIỆM THU LIVE TEST TƯƠNG TÁC MÀN HÌNH FULL ROLE

- **Thời gian thực thi:** `2026-11-09T20:48:23.841421`
- **Tổng thời gian chạy:** `117.89 giây`
- **Hệ thống mục tiêu:** Backend `http://localhost:5138` | Flutter Web `http://localhost:8080`
- **Chế độ kiểm thử:** Google Chrome Headed (Hiển thị trực tiếp màn hình tương tác)
- **Tổng số ca kiểm thử:** `36` | **PASS:** `36` | **FAIL:** `0` | **Tỷ lệ:** `100.0%`

## 1. BẢNG TỔNG HỢP KẾT QUẢ THEO TỪNG VAI TRÒ (ROLE)

| STT | Role | Mã Test | Mô Tả Nghiệp Vụ | HTTP | Thời Gian | Kết Quả | Ảnh Minh Chứng |
|:---:|:---|:---|:---|:---:|:---:|:---:|:---|
| 1 | `GUEST` | `GUEST-01` | Xem sơ đồ bàn ăn nhà hàng (Floor Table Map) | 200 | 639.6ms | ✅ PASS | [step01_guest_floor.png](artifacts/live_test_screens\step01_guest_floor.png) |
| 2 | `GUEST` | `GUEST-02` | Duyệt thực đơn trang chủ & món mới nhất (HomePage) | 200 | 100.0ms | ✅ PASS | [step02_guest_home.png](artifacts/live_test_screens\step02_guest_home.png) |
| 3 | `GUEST` | `GUEST-03` | Tìm kiếm món ăn 'Cà phê' trên thanh tìm kiếm | 200 | 22.6ms | ✅ PASS | [step03_guest_search.png](artifacts/live_test_screens\step03_guest_search.png) |
| 4 | `GUEST` | `GUEST-04` | Xem thông tin chi tiết món ăn & món liên quan | 200 | 100.0ms | ✅ PASS | [step04_guest_product_detail.png](artifacts/live_test_screens\step04_guest_product_detail.png) |
| 5 | `GUEST` | `GUEST-05` | Cổng an ninh: Chặn khách vãng lai truy cập dữ liệu nội bộ (401) | 401 | 4.0ms | ✅ PASS | - |
| 6 | `WAITER` | `WTR-01` | Đăng nhập Nhân viên phục vụ bàn (waiter_nam) | 200 | 28.1ms | ✅ PASS | [step05_waiter_login.png](artifacts/live_test_screens\step05_waiter_login.png) |
| 7 | `WAITER` | `WTR-02` | Phục vụ tra cứu sơ đồ chọn bàn trống (Bàn T1-02) | 200 | 100.0ms | ✅ PASS | [step06_waiter_table_select.png](artifacts/live_test_screens\step06_waiter_table_select.png) |
| 8 | `WAITER` | `WTR-03` | Thêm món vào Giỏ hàng & gửi order bàn (Đơn #40) | 200 | 46.9ms | ✅ PASS | [step07_waiter_cart.png](artifacts/live_test_screens\step07_waiter_cart.png) |
| 9 | `WAITER` | `WTR-04` | Màn hình xác nhận đơn hàng thành công (Order #40) | 200 | 100.0ms | ✅ PASS | [step08_waiter_order_created.png](artifacts/live_test_screens\step08_waiter_order_created.png) |
| 10 | `WAITER` | `WTR-05` | Bàn 2 đổi trạng thái sang Có Khách (Status: 1) | 200 | 100.0ms | ✅ PASS | [step09_waiter_table_occupied.png](artifacts/live_test_screens\step09_waiter_table_occupied.png) |
| 11 | `WAITER` | `WTR-06` | Chuyển bàn từ Bàn 2 sang Bàn 7 | 200 | 27.5ms | ✅ PASS | [step10_waiter_transfer_table.png](artifacts/live_test_screens\step10_waiter_transfer_table.png) |
| 12 | `KDS` | `KDS-01` | Đăng nhập Đầu Bếp KDS (chef_dung) | 200 | 23.4ms | ✅ PASS | [step11_kds_login.png](artifacts/live_test_screens\step11_kds_login.png) |
| 13 | `KDS` | `KDS-02` | Màn hình Bếp KDS hiển thị danh sách order thời gian thực | 200 | 14.1ms | ✅ PASS | [step12_kds_active_queue.png](artifacts/live_test_screens\step12_kds_active_queue.png) |
| 14 | `KDS` | `KDS-03` | Chuyển món #7 sang trạng thái 'Đang nấu' (1) | 200 | 33.4ms | ✅ PASS | [step13_kds_cooking_state.png](artifacts/live_test_screens\step13_kds_cooking_state.png) |
| 15 | `KDS` | `KDS-04` | Chuyển món #7 sang 'Sẵn sàng phục vụ' (2) | 200 | 14.3ms | ✅ PASS | [step14_kds_ready_state.png](artifacts/live_test_screens\step14_kds_ready_state.png) |
| 16 | `KDS` | `KDS-05` | 1-Chạm Báo hết món (Sold-Out Toggle) trên KDS | 200 | 17.2ms | ✅ PASS | [step15_kds_soldout_toggle.png](artifacts/live_test_screens\step15_kds_soldout_toggle.png) |
| 17 | `CASHIER` | `CSH-01` | Đăng nhập Thu Ngân Quầy POS (cashier_mai) | 200 | 22.8ms | ✅ PASS | - |
| 18 | `CASHIER` | `CSH-02` | Mở giao diện Thu Ngân POS Quầy tính tiền (Đơn #40) | 200 | 100.0ms | ✅ PASS | [step16_cashier_terminal.png](artifacts/live_test_screens\step16_cashier_terminal.png) |
| 19 | `CASHIER` | `CSH-03` | Áp dụng chiết khấu thủ công / mã giảm giá (Discount %) | 200 | 12.3ms | ✅ PASS | [step17_cashier_discount.png](artifacts/live_test_screens\step17_cashier_discount.png) |
| 20 | `CASHIER` | `CSH-04` | Sinh mã thanh toán VietQR động chuẩn Napas 247 cho đơn #40 | 200 | 6.8ms | ✅ PASS | [step18_cashier_vietqr_dialog.png](artifacts/live_test_screens\step18_cashier_vietqr_dialog.png) |
| 21 | `CASHIER` | `CSH-05` | Tạo liên kết thanh toán VNPay Sandbox có HMAC-SHA512 | 200 | 7.5ms | ✅ PASS | - |
| 22 | `CASHIER` | `CSH-06` | Xác nhận thanh toán tiền mặt đơn #40 & In hóa đơn | 200 | 27.4ms | ✅ PASS | [step19_cashier_paid_receipt.png](artifacts/live_test_screens\step19_cashier_paid_receipt.png) |
| 23 | `CASHIER` | `CSH-07` | Bàn 7 được giải phóng tự động về trạng thái Trống (0) | 200 | 100.0ms | ✅ PASS | [step20_cashier_table_released.png](artifacts/live_test_screens\step20_cashier_table_released.png) |
| 24 | `MEMBER` | `MEM-01` | Gửi yêu cầu OTP quên mật khẩu (Mã lấy từ hệ thống: 239805) | 200 | 9.6ms | ✅ PASS | [step21_member_forgot_otp_modal.png](artifacts/live_test_screens\step21_member_forgot_otp_modal.png) |
| 25 | `MEMBER` | `MEM-02` | Xác thực mã OTP 6 chữ số và đổi mật khẩu mới thành công | 200 | 14.5ms | ✅ PASS | - |
| 26 | `MEMBER` | `MEM-03` | Cổng thành viên & Thanh theo dõi tiến độ đơn hàng thời gian thực | 200 | 100.0ms | ✅ PASS | [step23_member_home_tracking.png](artifacts/live_test_screens\step23_member_home_tracking.png) |
| 27 | `MEMBER` | `MEM-04` | Tích điểm Loyalty Points & Cơ chế đổi voucher giảm giá | 200 | 100.0ms | ✅ PASS | [step24_member_redeem_points.png](artifacts/live_test_screens\step24_member_redeem_points.png) |
| 28 | `MEMBER` | `MEM-05` | Đăng nhập Khách Hàng VIP (vip_huong) với mức ưu đãi 10% | 200 | 12.5ms | ✅ PASS | - |
| 29 | `ADMIN` | `ADM-01` | Đăng nhập Quản Trị Viên Hệ Thống (admin) | 200 | 54.8ms | ✅ PASS | - |
| 30 | `ADMIN` | `ADM-02` | Bảng điều khiển 4 KPI Doanh thu & Top 5 Món bán chạy nhất | 200 | 24.1ms | ✅ PASS | [step25_admin_kpi_dashboard.png](artifacts/live_test_screens\step25_admin_kpi_dashboard.png) |
| 31 | `ADMIN` | `ADM-03` | Thêm danh mục mới 'Thực Đơn Mùa Lễ 87' kèm hình ảnh | 200 | 84.8ms | ✅ PASS | [step26_admin_category_management.png](artifacts/live_test_screens\step26_admin_category_management.png) |
| 32 | `ADMIN` | `ADM-04` | Chặn xóa danh mục đang chứa món ăn (Cổng bảo vệ HasProducts: 400) | 400 | 7.7ms | ✅ PASS | - |
| 33 | `ADMIN` | `ADM-05` | Quản lý món ăn & phân trang danh mục (Pagination) | 200 | 13.8ms | ✅ PASS | [step27_admin_product_pagination.png](artifacts/live_test_screens\step27_admin_product_pagination.png) |
| 34 | `ADMIN` | `ADM-06` | Chặn xóa món ăn đã có trong lịch sử đơn hàng (HasOrders gate: 400) | 400 | 8.3ms | ✅ PASS | - |
| 35 | `ADMIN` | `ADM-07` | Xem danh sách nhân sự & ma trận phân quyền 6 Role RBAC | 200 | 11.6ms | ✅ PASS | [step28_admin_user_rbac.png](artifacts/live_test_screens\step28_admin_user_rbac.png) |
| 36 | `MANAGER` | `MGR-01` | Đăng nhập Quản Lý Chi Nhánh (manager01) | 200 | 12.1ms | ✅ PASS | - |

## 2. KIỂM SOÁT AN TOÀN TOÀN VẸN DỮ LIỆU & ĐỘNG TÁC XỬ LÝ NGOẠI LỆ

1. **Bảo toàn Database:** Toàn bộ dữ liệu sẵn có trong `RestaurantPos_Acceptance` được bảo toàn nguyên vẹn, các bàn trống được dò tìm động và giải phóng hoàn tất sau thanh toán.
2. **Khôi phục mật khẩu OTP:** Tài khoản `member_khang` sau khi đổi mật khẩu test qua OTP đã được tự động hoàn nguyên về mật khẩu ban đầu (`admin`).
3. **Bảo vệ toàn vẹn:** Các cổng chặn xóa danh mục có sản phẩm và chặn xóa món ăn đã có trong lịch sử đơn hàng hoạt động chính xác (HTTP 400).
4. **Kiểm tra DevTools Console & Network:** 100% request giao tiếp ổn định, không có lỗi crash unhandled exception.

---
*Báo cáo được khởi tạo tự động bởi Live Screen Test Automation Harness.*