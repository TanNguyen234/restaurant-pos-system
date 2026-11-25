# Hướng Dẫn Vấn Đáp 1 Người — Restaurant & Cafe POS System

> **Dành riêng cho 1 người trình bày & vấn đáp toàn bộ đồ án** (Backend ASP.NET Core 10 + SQL Server + Flutter Mobile/Web/Desktop).
> Đọc trọn bộ thư mục này trong **10–15 phút** để nắm chắc kiến trúc, ánh xạ code, trả lời phản biện và demo 5 phút mượt mà.

---

## 1. Elevator Pitch (Mở bài 60 giây khi đứng trước giảng viên)

"Thưa thầy/cô, em xin trình bày hệ thống **Quản lý Nhà hàng & Quán Cà phê Đa nền tảng (Restaurant & Cafe POS)** gồm 3 tầng:
1. **Frontend đa nền tảng bằng Flutter** chạy đồng thời trên **Mobile (Android), Web Browser và Windows Desktop**, thiết kế theo hướng **Offline-First** kết hợp **SignalR Realtime Push (`/hubs/pos`)**: mất mạng vẫn chọn bàn, thêm món vào giỏ và lưu đơn vào hàng đợi cục bộ (`SQLite` trên Mobile/Desktop, `SharedPreferences` trên Web) kèm `IdempotencyKey` (UUID v4) chống tạo trùng đơn; khi online các màn hình Bếp KDS / Sơ đồ bàn / Thu ngân POS cập nhật tức thì qua WebSocket, hỗ trợ **QR Self-Order tại bàn** (`/?tableId=X`) và **in bill ESC/POS LAN TCP 9100**.
2. **Backend ASP.NET Core 10 Web API** tổ chức theo kiến trúc Repository (`SiteProvider` + Entity Framework Core 10 + `PosHub` SignalR), bảo mật bằng **JWT Bearer**, **PBKDF2-SHA256** (100.000 iterations), xác thực **Email OTP qua Gmail SMTP**, phân quyền **RBAC 11 vai trò**, hỗ trợ thanh toán **Tiền mặt, VietQR động, Chia hóa đơn (Split Payment)** và **VNPay Sandbox (HMAC-SHA512)**.
3. **Cơ sở dữ liệu SQL Server 18 bảng chuẩn 3NF** đảm bảo toàn vẹn giao dịch ACID (`BeginTransaction`) từ lúc Khách/Phục vụ mở bàn → tự động **trừ kho định lượng nguyên liệu (BOM)** → Bếp (KDS) chế biến / báo hết món / hủy món (**hoàn kho BOM**) → Thu ngân tách/gộp bàn, chiết khấu, thu tiền, in bill LAN/PDF, kết xuất báo cáo **Z-Report cuối ca**, biểu đồ doanh thu + xuất CSV và cộng điểm khách hàng thân thiết."

---

## 2. Bản Đồ Tài Liệu Đọc Nhanh

| STT | Tài liệu | Mục đích đọc nhanh | Thời gian đọc |
| :--- | :--- | :--- | :---: |
| 01 | [01_TONG_QUAN_KIEN_TRUC.md](file:///d:/Download/restaurant_pos_app/defense_guide/01_TONG_QUAN_KIEN_TRUC.md) | Nắm kiến trúc 3 tầng, SignalR, ERD 18 bảng BOM & bảo mật | 3 phút |
| 02 | [02_BAREM_VA_BAN_DO_CODE.md](file:///d:/Download/restaurant_pos_app/defense_guide/02_BAREM_VA_BAN_DO_CODE.md) | Bảng tra cứu 3 giây: giảng viên hỏi mục nào → mở đúng file đó | 3 phút |
| 03 | [03_CAU_HOI_PHAN_BIEN_QA.md](file:///d:/Download/restaurant_pos_app/defense_guide/03_CAU_HOI_PHAN_BIEN_QA.md) | Câu hỏi phản biện "gắt" thường gặp + đáp án bám sát code thật | 4 phút |
| 04 | [04_KICH_BAN_DEMO_5_PHUT.md](file:///d:/Download/restaurant_pos_app/defense_guide/04_KICH_BAN_DEMO_5_PHUT.md) | Kịch bản 1 người cầm chuột/điện thoại demo trọn vẹn các vai trò & 6 nâng cấp | 2 phút |
| 05 | [05_DE_XUAT_NANG_CAP.md](file:///d:/Download/restaurant_pos_app/defense_guide/05_DE_XUAT_NANG_CAP.md) | Tổng kết 6 nâng cấp đã hoàn thiện + Lộ trình mở rộng v3 | 2 phút |

---

## 3. Bộ Biểu Đồ Trực Quan (`diagrams/`)

- [01_system_architecture.png](file:///d:/Download/restaurant_pos_app/defense_guide/diagrams/01_system_architecture.png) — Kiến trúc tổng thể 3 tầng, SignalR `/hubs/pos` & ESC/POS LAN
- [02_erd_database.png](file:///d:/Download/restaurant_pos_app/defense_guide/diagrams/02_erd_database.png) — Lược đồ thực thể kết hợp (ERD 18 bảng chuẩn 3NF + Kho BOM)
- [03_rbac_role_matrix.png](file:///d:/Download/restaurant_pos_app/defense_guide/diagrams/03_rbac_role_matrix.png) — Ma trận phân quyền RBAC từ Khách QR đến Admin
- [04_end_to_end_pos_sequence.png](file:///d:/Download/restaurant_pos_app/defense_guide/diagrams/04_end_to_end_pos_sequence.png) — Sequence Diagram từ QR/Offline → BOM → SignalR KDS → Thanh toán & Z-Report
- [05_auth_security_flow.png](file:///d:/Download/restaurant_pos_app/defense_guide/diagrams/05_auth_security_flow.png) — Luồng xác thực PBKDF2-SHA256, OTP SMTP thật & chống Account Hijack OAuth

---

## 4. Bộ Tài Khoản Demo Đã Seed Sẵn (`RestaurantPos_Acceptance`)

> **Mật khẩu mặc định cho tất cả tài khoản test bên dưới:** `admin`

| Vai trò | Username | Họ tên hiển thị | Điểm nhấn khi demo |
| :--- | :--- | :--- | :--- |
| **ADMIN** | `admin` | Nguyễn Văn Quản Trị | Toàn quyền: CRUD Danh mục/Món/Ảnh, Khóa/Mở user, Phân quyền ADMIN |
| **MANAGER** | `manager01` | Trần Thị Thu Quản Lý | Quản trị vận hành, Thống kê đơn & Top bán chạy, Quản lý nhân sự |
| **CASHIER** | `cashier_mai` | Lê Tuyết Mai | Màn hình POS Split-Screen, Chiết khấu, VietQR/VNPay/Split Pay, Mở & Chốt ca Z-Report |
| **WAITER** | `waiter_nam` | Phạm Hoàng Nam | Sơ đồ 10 bàn (4 khu vực trạng thái), Mở/Chuyển/Gộp/Tách bàn, Đặt món & Hàng đợi Offline |
| **HEAD_CHEF / KDS** | `chef_dung` / `kitchen` | Ngô Tiến Dũng / Bếp Trưởng | Màn hình tối KDS, Lọc Bếp/Bar, Chế biến 0→1→2, 1-chạm Báo hết món, Hủy món |
| **MEMBER** | `member_khang` | Bùi Vĩnh Khang | Điểm tích lũy thật (`1.250 PTS`), Đổi voucher, Tra cứu lịch sử đơn & thanh toán |
| **VIP_MEMBER** | `vip_huong` | Đặng Thu Hương | Hạng VIP (`2.800 PTS`), ưu đãi thành viên thân thiết |
