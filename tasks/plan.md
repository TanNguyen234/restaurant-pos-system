# KẾ HOẠCH TỔNG THỂ PHÂN TÍCH, NÂNG CẤP NGHIỆP VỤ & TÁI THIẾT KẾ UI/UX
## DỰ ÁN: RESTAURANT & CAFE POS SYSTEM (F&B ENTERPRISE SOLUTION)
**Phiên bản kế hoạch:** 1.0 (Master Audit & Implementation Plan)  
**Tác giả:** Antigravity Fullstack & UI/UX Senior Architect  
**Trạng thái:** DRAFT FOR USER REVIEW (CHỜ NGƯỜI DÙNG DUYỆT TRƯỚC KHI THỰC HIỆN)  

---

## MỤC LỤC
1. [TỔNG QUAN HIỆN TRẠNG & ĐIỂM NGHẼN KỸ THUẬT (FORENSIC AUDIT)](#1-tổng-quan-hiện-trạng--điểm-nghẽn-kỹ-thuật)
2. [MA TRẬN ĐỐI CHIẾU THIẾU HỤT SO VỚI TÀI LIỆU (DOCS GAP ANALYSIS)](#2-ma-trận-đối-chiếu-thiếu-hụt-so-với-tài-liệu)
3. [DANH MỤC THIẾU HỤT NGHIỆP VỤ THEO CHỦ ĐỀ (TOPIC BREAKDOWN)](#3-danh-mục-thiếu-hụt-nghiệp-vụ-theo-chủ-đề)
4. [DANH MỤC THIẾU HỤT NGHIỆP VỤ THEO VAI TRÒ (ROLE-BASED RBAC WORKFLOWS)](#4-danh-mục-thiếu-hụt-nghiệp-vụ-theo-vai-trò)
5. [CHIẾN LƯỢC XÓA BỎ "AI SLOP" & NÂNG CẤP UI/UX CHUẨN POS CÔNG NGHIỆP](#5-chiến-lược-xóa-bỏ-ai-slop--nâng-cấp-uiux)
6. [LỘ TRÌNH THỰC HIỆN CHI TIẾT THEO TỪNG GIAI ĐOẠN (ACTIONABLE ROADMAP)](#6-lộ-trình-thực-hiện-chi-tiết-theo-từng-giai-đoạn)
7. [CHECKLIST DUYỆT & CÁC CÂU HỎI QUYẾT ĐỊNH DÀNH CHO BẠN](#7-checklist-duyệt--các-câu-hỏi-quyết-định)

---

## 1. TỔNG QUAN HIỆN TRẠNG & ĐIỂM NGHẼN KỸ THUẬT

### 1.1. Những gì codebase hiện đang có:
- **Cơ sở dữ liệu:** SQL Server với 10 bảng cơ sở (`Accounts`, `Roles`, `Areas`, `DiningTables`, `Categories`, `Products`, `ProductAttributes`, `Orders`, `OrderDetails`, `Payments`).
- **Backend .NET 10 Web API:** Cấu trúc 4 tầng `BaseController` -> `SiteProvider` -> `BaseRepository` -> `RestaurantPosContext`. Có các controller: `AuthController`, `AccountController`, `CategoryController`, `ProductController`, `TableController`, `OrderController`, `KdsController`, `PaymentController`.
- **Mobile Client (Flutter):**
  - Các màn hình cơ bản: `FloorTablePage`, `HomePage`, `CategoryPage`, `ProductDetailPage`, `CartPage`, `OrderCheckoutPage`, `OrderDetailPage`, `KitchenDisplayPage`, `AdminOrderListPage`, `AdminCategoryPage`, `AdminProductPage`, `AdminUserPage`, `LoginPage`, `RegisterPage`, `ChangePasswordPage`.
  - SQLite cục bộ (`DatabaseHelper`): Quản lý `user_session`, `cart_items`, `offline_orders`.
  - Service `OfflineSyncService` chạy nền định kỳ để đẩy đơn hàng ngoại tuyến.

### 1.2. Các "ảo tưởng hoàn thành" (Surface-level / False-pass / Bottlenecks) phát hiện trong kiểm định:
1. **Lỗ hổng RBAC nghiêm trọng ở Backend:**
   - Chỉ duy nhất `AccountController.cs` có gán `[Authorize(Roles = "ADMIN,MANAGER")]`.
   - Tất cả các controller còn lại: `OrderController`, `TableController`, `CategoryController`, `ProductController`, `KdsController`, `PaymentController` đều **KHÔNG CÓ `[Authorize]`**! Bất kỳ ai gửi request HTTP đều có thể tạo đơn, hủy đơn, đổi trạng thái bàn, xóa món ăn hoặc xác nhận thanh toán mà không cần đăng nhập.
2. **Ảo tưởng lưu trữ Web In-Memory Mock:**
   - Trong `mobile/lib/utils/database_helper.dart`, khi chạy trên môi trường Web (`kIsWeb`), hệ thống fallback về dữ liệu mẫu cứng (`_webSession` gán sẵn `admin`, `_webCart` có sẵn 3 món cứng, `_webOrders` có sẵn 2 đơn cứng). Điều này làm sai lệch trải nghiệm thực tế và che giấu lỗi khi chạy kiểm thử trên trình duyệt.
3. **Ảo tưởng Tùy chọn món (Toppings / Modifiers):**
   - Database có bảng `ProductAttributes` và bảng `OrderDetailModifiers`. Giao diện `ProductDetailPage` cho chọn Size, Đường, Đá, Topping.
   - **NHƯNG:** Khi bấm "Thêm vào giỏ", toàn bộ lựa chọn chỉ được nối thành 1 chuỗi text trong cột `note` (ví dụ: `"Size L, 50% đường, Trân châu"`). Khi checkout, Server không hề lưu vào bảng `OrderDetailModifiers` và không tính giá riêng lẻ từng modifier, gây sai lệch thống kê nguyên liệu và tính tiền.
4. **Ảo tưởng Ngoại tuyến (Offline-First):**
   - `OfflineSyncService` chỉ đồng bộ đơn hàng khi mất mạng.
   - **NHƯNG:** Nếu mở app khi không có mạng, người dùng **KHÔNG THỂ XEM MENU** vì `CategoryRepository` và `ProductRepository` gọi trực tiếp HTTP đến server mà không có cơ chế cache danh mục/sản phẩm vào SQLite! Một ứng dụng POS nhà hàng thực thụ phải mở và order được ngay cả khi mất internet hoàn toàn.
5. **UI/UX "AI Slop" nặng nề:**
   - Màn hình mobile kéo giãn kỳ quặc trên tablet/desktop, phí 70% diện tích màn hình.
   - Nút "Floating Action Button" (hình icon tune nhỏ) là một "hộp rác" chứa đến 8 chức năng cốt lõi (Checkout, KDS, Đơn hàng, Quản lý danh mục, Quản lý sản phẩm, Quản trị user, Tài khoản) - biểu hiện kinh điển của AI sinh mã khi hết chỗ đặt menu.
   - Tab "Đồng bộ đơn" bị ép thành 1 trong 5 tab chính dưới đáy màn hình của mọi nhân viên!

---

## 2. MA TRẬN ĐỐI CHIẾU THIẾU HỤT SO VỚI TÀI LIỆU (DOCS GAP ANALYSIS)

| Tài liệu tham chiếu | Hạng mục quy định | Hiện trạng mã nguồn | Mức độ thiếu hụt & Đánh giá |
|---|---|---|---|
| **01 Barem §1.8** | Xác thực Email qua mã OTP | Chưa có code gửi email hoặc bảng lưu OTP | **THIẾU 100%** (Mất 0.50 đ điểm cộng) |
| **01 Barem §1.9** | Quên mật khẩu qua email link/OTP | Chưa có API hoặc màn hình Forgot Password | **THIẾU 100%** (Mất 0.50 đ điểm cộng) |
| **01 Barem §1.10** | Đăng nhập Google, Facebook, Zalo | CSDL có cột `OAuthProvider` nhưng chưa có luồng đăng nhập | **THIẾU 100%** (Mất 1.50 đ điểm cộng) |
| **01 Barem §4.6** | Món liên quan có phân trang | `ProductDetailPage` chỉ gọi 4 món cố định, không có phân trang cuộn | **THIẾU MỘT NỬA** (Chưa đúng yêu cầu phân trang) |
| **01 Barem §5.9** | Tìm kiếm đơn hàng cho khách | Chỉ có thanh tìm kiếm ở trang Admin, khách không tự tra cứu được | **THIẾU GIAO DIỆN KHÁCH** |
| **02 Mở rộng §2** | Gộp bàn (Merge) & Tách bàn/đơn (Split) | Chỉ có chức năng chuyển bàn đơn lẻ (`POST /api/table/transfer`) | **THIẾU 100%** (Nghiệp vụ cốt lõi F&B) |
| **02 Mở rộng §4** | In Hóa đơn nhiệt ESC/POS & Xuất PDF | Chưa có service in, chưa có màn hình hóa đơn nhiệt xem trước | **THIẾU 100%** (Nghiệp vụ thanh toán bắt buộc) |
| **02 Mở rộng §5** | Offline-First Cache Thực đơn | Chỉ lưu cart và pending orders, chưa cache menu/món vào SQLite | **THIẾU CACHE THỰC ĐƠN** |
| **02 Mở rộng §6** | Lưu thuộc tính món vào `OrderDetailModifiers` | Chưa lưu bảng quan hệ ở Backend, chỉ ghép chuỗi vào `note` | **LÀM ẨU / CHƯA ĐẠT CHUẨN** |
| **02 Mở rộng §7** | Quản lý Ca làm việc & Chốt két (Shift Register) | Chưa có mở ca, kiểm tiền lẻ đầu ca, chốt ca cuối ngày (Z-Report) | **THIẾU 100%** (Nghiệp vụ thu ngân thiết yếu) |
| **02 Mở rộng §8** | Khuyến mãi, Voucher & Khách hàng thân thiết | `_discount => 0` hardcode trong code, chưa có voucher & tích điểm | **THIẾU 100%** |
| **03 & 05 Flows** | Trạng thái đặt bàn trước (Reservation) | Cột `Status = 2 (Reserved)` có trong DB nhưng không có luồng đặt chỗ | **THIẾU LUỒNG ĐẶT BÀN** |

---

## 3. DANH MỤC THIẾU HỤT NGHIỆP VỤ THEO CHỦ ĐỀ (TOPIC BREAKDOWN)

### 📌 Topic 1: Quản lý Bàn ăn & Mặt bằng (Floor & Table Management)
- **Thiếu 1.1 - Gộp bàn (Table Merge):** Khi khách đi nhóm đông muốn ghép 2 bàn (ví dụ Bàn 01 và Bàn 02) thành 1 bàn duy nhất. Backend cần gộp chung các món trong `OrderDetails`, dồn tổng tiền và đánh dấu 1 bàn là bàn chính, giải phóng hoặc liên kết bàn phụ.
- **Thiếu 1.2 - Tách bàn & Tách hóa đơn (Table & Bill Split):** Nhóm khách muốn tách 1 vài món sang bàn khác ngồi riêng, hoặc thanh toán riêng lẻ (chia bill theo món hoặc chia đều tiền).
- **Thiếu 1.3 - Đặt bàn trước (Reservation Workflow):** Đặt bàn cho khách: nhập tên khách, số điện thoại, giờ đến dự kiến, số lượng khách, ghi chú đặc biệt (ví dụ: chuẩn bị ghế trẻ em, trang trí sinh nhật). Bàn chuyển sang màu Cam (Đã đặt trước) và tự động nhắc nhở khi gần đến giờ hẹn.
- **Thiếu 1.4 - Thời gian khách ngồi (Table Dwell Time):** Thẻ bàn cần hiển thị khách đã ngồi bao lâu (ví dụ: `45 phút`), cảnh báo các bàn ngồi quá 2 tiếng để nhân viên chú ý chăm sóc.

### 📌 Topic 2: Thực đơn, Món ăn & Tùy biến (Menu, Modifiers & Attributes)
- **Thiếu 2.1 - Lưu trữ Modifiers chuẩn hóa vào CSDL:** Mỗi món chọn Size L (+10.000đ), Thêm trân châu (+8.000đ) phải được lưu thành từng bản ghi trong bảng `OrderDetailModifiers` gắn với `OrderDetailId`.
- **Thiếu 2.2 - Quản lý Trạng thái Hết món (Out of stock / 86-ing):** Bếp hoặc Quản lý có thể bấm 1 chạm để đánh dấu "Tạm hết món" ngay trên KDS hoặc Admin. Ngay lập tức trên menu của nhân viên phục vụ, món đó bị làm mờ và không cho thêm vào giỏ.
- **Thiếu 2.3 - Bộ lọc thực đơn đa tiêu chí:** Lọc món theo: Món chay, Món cay, Đồ uống có cồn, Món bán chạy nhất (Best-sellers), Món theo khung giờ (ví dụ: Điểm tâm sáng chỉ bán trước 10h).

### 📌 Topic 3: Giỏ hàng, Đặt món & Điều phối Order (Cart & Ordering Flow)
- **Thiếu 3.1 - Phân tách hình thức phục vụ (Dine-in vs Takeaway vs Delivery):** Giao diện gọi món cho phép chọn ngay từ đầu: "Ăn tại bàn" (bắt buộc chọn bàn), "Mang về" (không cần bàn, in mã nhận món), hoặc "Giao hàng".
- **Thiếu 3.2 - Gọi thêm món vào bàn đang phục vụ (Add items to active order):** Hiện tại hệ thống chặn đặt món lên bàn có khách (`Status = 1`). Thực tế nhà hàng khách luôn gọi thêm món trong lúc ăn! Hệ thống phải cho phép nhân viên phục vụ mở bàn đang có khách và bấm "Gọi thêm món", các món mới tự động bắn vào bếp với nhãn `[GỌI THÊM]`.
- **Thiếu 3.3 - In phiếu tạm tính (Proforma Bill / Pre-check bill):** Cho phép nhân viên in phiếu kiểm đồ đem ra cho khách đối soát trước khi thanh toán.

### 📌 Topic 4: Màn hình Bếp & Pha chế (Kitchen Display System - KDS)
- **Thiếu 4.1 - Phân tách khu vực chế biến (Bếp nấu vs Quầy Bar):**
  - Màn hình Bếp (Kitchen): Chỉ hiển thị các món ăn (Phở, Cơm, Bánh mì, Món ăn vặt).
  - Màn hình Barista (Quầy Bar): Chỉ hiển thị đồ uống (Cà phê, Trà hoa quả, Đá xay, Nước ép).
  - Tránh tình trạng đầu bếp bị ngập lụt bởi 30 ly cà phê, còn nhân viên pha chế phải nhìn thấy món phở xào!
- **Thiếu 4.2 - Chế độ xem Gom món (Aggregated Prep View):** Thay vì chỉ xem từng order rời rạc, KDS có thêm tab "Tổng hợp món": ví dụ hiển thị `5 Cà phê sữa đá`, `3 Trà đào cam sả` đang chờ làm để pha chế làm một mẻ nhanh gấp 3 lần.
- **Thiếu 4.3 - Cảnh báo âm thanh & Thời gian thực:** Phát chuông "Ting ting" khi có order mới bắn xuống bếp. Thẻ món đổi màu theo thời gian: Xanh (<8 phút) -> Vàng (8-15 phút) -> Đỏ nhấp nháy (>15 phút).

### 📌 Topic 5: Thanh toán & Thu ngân (Settlement & Cashier Register)
- **Thiếu 5.1 - Bàn phím số Numpad & Phím tắt tiền mặt (Quick Cash Buttons):** Màn hình thu ngân phải có các nút tiền mệnh giá Việt Nam thông dụng: `50.000đ`, `100.000đ`, `200.000đ`, `500.000đ`, `Đúng số tiền`. Hệ thống tự động tính số tiền thừa trả lại khách (`Change Due`), giảm thiểu sai sót nhầm lẫn tiền bạc.
- **Thiếu 5.2 - In hóa đơn chuẩn F&B (Thermal Receipt 58mm/80mm & PDF):** Mẫu hóa đơn chuyên nghiệp gồm: Logo, Tên quán, Địa chỉ, Số bàn, Giờ vào/Giờ ra, Tên thu ngân, Chi tiết món kèm topping, Tiền hàng, Thuế VAT, Giảm giá, Mã VietQR động để quét thanh toán, Lời cảm ơn. Hỗ trợ xuất file PDF hoặc in qua máy in nhiệt.
- **Thiếu 5.3 - Thanh toán kết hợp (Split Payment):** Khách muốn trả một nửa bằng tiền mặt, một nửa quét mã QR chuyển khoản.

### 📌 Topic 6: Quản lý Ca làm việc & Két tiền (Shift & Cash Management)
- **Thiếu 6.1 - Mở ca làm việc (Open Shift):** Thu ngân đăng nhập đầu ngày, đếm và nhập số tiền lẻ trong két (Tiền đầu ca - Float Cash, ví dụ: 1.000.000đ).
- **Thiếu 6.2 - Theo dõi dòng tiền trong ca:** Ghi nhận tiền thu vào (Tiền mặt, VietQR, VNPay), các khoản chi khẩn cấp (ví dụ: mua đá, mua thêm chanh 50.000đ).
- **Thiếu 6.3 - Đóng ca & In báo cáo Z-Report:** Cuối ca, thu ngân đếm tiền mặt thực tế trong két. Hệ thống đối chiếu với doanh thu lý thuyết, tính chênh lệch thừa/thiếu, in phiếu bàn giao ca (Z-Report) có chữ ký của Quản lý và Thu ngân.

### 📌 Topic 7: Khách hàng thân thiết & Khuyến mãi (Loyalty & Promotion)
- **Thiếu 7.1 - Quản lý Voucher / Mã giảm giá:** Nhập mã giảm giá (ví dụ: `BANMOI10` giảm 10%, `COFFEE20K` giảm 20.000đ), kiểm tra điều kiện áp dụng (đơn tối thiểu, hạn sử dụng).
- **Thiếu 7.2 - Tích điểm hội viên theo SĐT:** Khách đọc số điện thoại -> Hệ thống hiển thị tên khách, hạng thẻ (Đồng, Bạc, Vàng, Kim Cương), số điểm hiện có. Cho phép dùng điểm để trừ trực tiếp vào hóa đơn.

### 📌 Topic 8: Ngoại tuyến toàn diện (True Offline-First POS)
- **Thiếu 8.1 - Đồng bộ 2 chiều (Sync Down Menu & Sync Up Orders):** Khi mở app lúc có mạng, tải toàn bộ Danh mục, Sản phẩm, Bàn ăn lưu vào SQLite. Khi đứt mạng, toàn bộ giao diện menu, tìm kiếm, giỏ hàng, sơ đồ bàn vẫn hoạt động mượt mà 100%. Khi có mạng, tự động đồng bộ đơn hàng lên server.

---

## 4. DANH MỤC THIẾU HỤT NGHIỆP VỤ THEO VAI TRÒ (ROLE-BASED RBAC)

Hiện tại, ứng dụng gộp chung 1 thanh điều hướng Bottom Navigation cho mọi vai trò. Điều này hoàn toàn phản nghiệp vụ trong một nhà hàng F&B chuyên nghiệp. Dưới đây là phân tích chi tiết:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        ROLE-BASED WORKSPACE ARCHITECTURE                               │
├─────────────┬──────────────────────────────────────────────────────────────────────────┤
│ ADMIN       │ System Config • Staff Management • Full Menus • Analytics & P&L Reports  │
├─────────────┼──────────────────────────────────────────────────────────────────────────┤
│ MANAGER     │ Floor Live Monitor • Void/Discount Overrides • Shift Audit • Inventory   │
├─────────────┼──────────────────────────────────────────────────────────────────────────┤
│ CASHIER     │ Split-Screen POS • Fast Numpad Checkout • Shift Open/Close • Bill Print  │
├─────────────┼──────────────────────────────────────────────────────────────────────────┤
│ WAITER      │ Handheld Table Floor Map • Quick Order • Modifier Sheet • Ready Alerts   │
├─────────────┼──────────────────────────────────────────────────────────────────────────┤
│ KITCHEN/BAR │ KDS Station (Kitchen vs Bar) • 1-Tap Cooking Status • Batch Prep • 86-ing│
├─────────────┼──────────────────────────────────────────────────────────────────────────┤
│ MEMBER/VIP  │ E-Menu Digital Catalog • Table QR Self-Order • Points & Vouchers • Book  │
└─────────────┴──────────────────────────────────────────────────────────────────────────┘
```

### 1. VAI TRÒ ADMIN (Quản trị viên hệ thống):
- **Giao diện cần có:** Admin Dashboard tổng thể (không phải qua nút Floating Action Button ẩn).
- **Nghiệp vụ cần bổ sung:**
  - Cấu hình thông tin nhà hàng (Tên, địa chỉ, hotline, wifi, % thuế VAT mặc định).
  - Quản trị tài khoản & cấp quyền (Tạo tài khoản nhân viên, gán vai trò Thu ngân/Phục vụ/Bếp, reset mật khẩu nhân viên).
  - Báo cáo phân tích doanh thu chuyên sâu: Biểu đồ doanh thu theo ngày/tháng, tỷ lệ thanh toán tiền mặt vs chuyển khoản, danh sách 10 món bán chạy nhất và 10 món ế ẩm nhất.
  - Quản lý khu vực & sơ đồ bàn (Thêm khu vực mới, thêm bàn, đổi tên bàn).

### 2. VAI TRÒ MANAGER (Quản lý nhà hàng):
- **Giao diện cần có:** Live Floor Monitor & Manager Operations.
- **Nghiệp vụ cần bổ sung:**
  - Giám sát sàn phục vụ: Tỷ lệ lấp đầy bàn (Occupancy Rate), bàn nào đang chờ món quá 15 phút.
  - Mã PIN phê duyệt quyền hạn đặc biệt (Manager Override): Duyệt hủy món khi bếp đã nấu, duyệt áp dụng chiết khấu đặc biệt cho khách VIP, duyệt hoàn tiền hóa đơn.
  - Kiểm tra và ký duyệt báo cáo đóng ca (Z-Report) của thu ngân.

### 3. VAI TRÒ CASHIER (Thu ngân):
- **Giao diện cần có:** **Split-Screen Cashier POS Terminal** (Màn hình chia đôi: Bên trái là Menu chọn món/chọn bàn, Bên phải là Hóa đơn trực tiếp).
- **Nghiệp vụ cần bổ sung:**
  - Thanh toán 1 chạm (Fast Checkout): Bàn phím số Numpad tính tiền thừa trả khách cực nhanh.
  - Quản lý két tiền & Ca làm việc (Mở ca đầu ngày, Đóng ca đối soát tiền mặt cuối ngày).
  - In hóa đơn tạm tính và In hóa đơn thanh toán nhiệt ESC/POS / PDF.
  - Chuyển đổi linh hoạt giữa các phương thức thanh toán: Tiền mặt, VietQR (hiển thị mã QR to rõ trên màn hình để khách quét), VNPay Sandbox.

### 4. VAI TRÒ WAITER (Nhân viên phục vụ):
- **Giao diện cần có:** Handheld Mobile Ordering (Tối ưu cho thao tác 1 tay trên điện thoại di động).
- **Nghiệp vụ cần bổ sung:**
  - Chạm vào bàn trống -> Mở nhanh menu gọi món.
  - Chạm vào bàn có khách -> Mở order đang ăn để gọi thêm món (Add items).
  - Chọn Size, Đường, Đá, Topping và ghi chú nhanh cho bếp ("không hành", "ít cay").
  - Chuyển bàn / Yêu cầu gộp bàn trực quan.
  - **Nhận thông báo Realtime:** Bếp nấu xong món nào -> Điện thoại nhân viên phục vụ rung và hiện thông báo: "Bàn T1-02: Phở bò đã sẵn sàng bưng!".

### 5. VAI TRÒ KITCHEN / CHEF / BARISTA (Bếp trưởng & Pha chế):
- **Giao diện cần có:** KDS Fullscreen Display (Chế độ Dark Mode chống chói, tối ưu cho tablet treo tường bếp).
- **Nghiệp vụ cần bổ sung:**
  - Bộ lọc trạm: "Trạm Bếp nấu" vs "Trạm Pha chế Bar".
  - Chế độ Gom món (Batch Prep): Hiển thị tổng số lượng từng món cần làm.
  - Đồng hồ đếm giờ trực quan: Đổi màu theo độ khẩn cấp (<8p Xanh, 8-15p Vàng, >15p Đỏ nhấp nháy).
  - Nút "Báo hết món" (Out of stock) trực tiếp từ bếp.
  - Âm thanh cảnh báo khi có đơn mới.

### 6. VAI TRÒ MEMBER / VIP (Khách hàng):
- **Giao diện cần có:** Customer Self-Service Portal (Thực đơn số & Thành viên).
- **Nghiệp vụ cần bổ sung:**
  - Xem Thực đơn số đẹp mắt với hình ảnh lớn, mô tả nguyên liệu, giá rõ ràng.
  - Quét mã QR dán tại bàn để tự xem menu và gửi yêu cầu gọi món.
  - Xem thông tin thành viên: Điểm tích lũy, Hạng thẻ, Danh sách mã voucher được dùng.
  - Tra cứu lịch sử hóa đơn các lần ăn uống trước đây.
  - Đặt bàn trước trực tuyến (Reservation).

---

## 5. CHIẾN LƯỢC XÓA BỎ "AI SLOP" & NÂNG CẤP UI/UX CHUẨN POS CÔNG NGHIỆP

Áp dụng toàn diện tri thức từ kỹ năng `/ui-ux-pro-max`:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        F&B POS DESIGN SYSTEM SPECIFICATION                             │
├─────────────────────┬──────────────────────────────────────────────────────────────────┤
│ Triết lý thiết kế   │ Modern Artisan Bistro & High-Efficiency Ergonomic POS            │
├─────────────────────┼──────────────────────────────────────────────────────────────────┤
│ Bảng màu chủ đạo    │ Primary: Deep Slate Navy (#0F172A) • Secondary: Slate (#1E293B)  │
│ (Color Palette)     │ Accent / Brand: Warm Caramel Amber (#D97706 / #F59E0B)           │
│                     │ Empty / Ready / Paid: Emerald Mint (#059669 / #10B981)           │
│                     │ Occupied / Urgent: Crimson Coral (#DC2626 / #EF4444)             │
│                     │ Background: Clean Light Slate (#F8FAFC) • Card: White (#FFFFFF)  │
├─────────────────────┼──────────────────────────────────────────────────────────────────┤
│ Typography          │ Heading: Karla / Roboto Condensed (Bold, high contrast, clean)   │
│                     │ Body & Monospace: Roboto / Inter (14-16px, high readability)     │
├─────────────────────┼──────────────────────────────────────────────────────────────────┤
│ Ergonomics & Touch  │ Tất cả nút bấm thao tác POS tối thiểu 48x48px (Touch Target)     │
│                     │ Khoảng cách tối thiểu giữa các nút hành động 8-12px              │
│                     │ Haptic feedback & Visual Ripple khi chạm                         │
├─────────────────────┼──────────────────────────────────────────────────────────────────┤
│ Bố cục thích ứng    │ Mobile (<600px): Handheld Waiter View tối ưu 1 tay               │
│ (Adaptive Layout)   │ Tablet/Desktop (>=600px): Split-Screen POS Grid chuyên nghiệp    │
└─────────────────────┴──────────────────────────────────────────────────────────────────┘
```

### 5.1. Xóa bỏ hoàn toàn các Anti-Pattern "AI Slop":
1. **Loại bỏ Nút Floating Action Button "Hộp rác" (`Icons.tune_rounded`):**
   - Thay thế bằng **Role-Aware Navigation Shell**: Khi đăng nhập với tài khoản nào, hệ thống tự động tải thanh điều hướng và không gian làm việc chuyên biệt cho vai trò đó.
   - Thêm Drawer hoặc Top Header Bar với avatar người dùng, badge vai trò nổi bật, nút đổi ca/đăng xuất trực quan.
2. **Loại bỏ Tab "Đồng bộ đơn" trên Bottom Navigation:**
   - Đưa trạng thái đồng bộ lên **Status Pill** trên AppBar (Ví dụ: Icon đám mây xanh `Online • Đã đồng bộ`, hoặc icon đám mây vàng `Offline • 3 đơn chờ đồng bộ`). Bấm vào pill sẽ mở modal đồng bộ chi tiết. Giải phóng vị trí quý giá trên thanh điều hướng cho các nghiệp vụ chính.
3. **Thay thế giao diện Single-Column co giãn trên Tablet/Desktop:**
   - Xây dựng **Split-Screen POS Layout** cho Thu ngân và Phục vụ trên màn hình lớn:
     - **Cột trái (65% chiều rộng):** Danh mục món dạng Tabs/Chips + Lưới sản phẩm ảnh lớn, bấm vào món là tự động nhảy sang phiếu bên phải.
     - **Cột phải (35% chiều rộng):** Phiếu Order thời gian thực (Active Ticket) với danh sách món, nút tăng giảm số lượng (+/-) to rõ (48px), tổng tiền tức thời, và 2 nút hành động lớn: "Gửi Bếp" (Xanh dương) và "Thanh toán" (Xanh lá).
4. **Thay thế SnackBar che khuất màn hình:**
   - Thay SnackBar nổi bằng thông báo Toast tinh tế ở góc trên hoặc banner trạng thái inline không che chắn nút bấm thanh toán.
5. **Nâng cấp Thao tác Chạm & Phản hồi Thị giác (Micro-interactions):**
   - Loại bỏ các icon xóa nhỏ xíu khó bấm.
   - Thêm hiệu ứng chuyển động mượt mà (150-200ms ease) khi đổi trạng thái bàn, khi món nhảy vào giỏ, khi đơn chuyển trạm KDS.
   - Bổ sung Skeleton Loading hiện đại thay vì vòng xoay tròn đơn điệu.

---

## 6. LỘ TRÌNH THỰC HIỆN CHI TIẾT THEO TỪNG GIAI ĐOẠN (ACTIONABLE ROADMAP)

Kế hoạch được chia thành **6 Giai đoạn (Phases)** theo nguyên tắc **Vertical Slicing** (mỗi task hoàn thành trọn vẹn từ CSDL -> Backend API -> Giao diện Mobile/Tablet -> Bộ kiểm thử xác thực):

```
PHASE 1: NỀN TẢNG BẢO MẬT, CƠ SỞ DỮ LIỆU & KIẾN TRÚC ĐIỀU HƯỚNG THEO ROLE (RBAC SHELL)
   │
   ▼
PHASE 2: TOÀN DIỆN SƠ ĐỒ BÀN, THỰC ĐƠN, MODIFIERS VÀ OFFLINE-FIRST CACHE
   │
   ▼
PHASE 3: MÀN HÌNH BẾP KDS CHUYÊN NGHIỆP & IN HÓA ĐƠN NHIỆT / XUẤT PDF
   │
   ▼
PHASE 4: POS THU NGÂN SPLIT-SCREEN, QUẢN LÝ CA (SHIFT) & THANH TOÁN ĐA KÊNH
   │
   ▼
PHASE 5: CỔNG KHÁCH HÀNG (MEMBER PORTAL), VOUCHER, ĐẶT BÀN & OAUTH/EMAIL
   │
   ▼
PHASE 6: TẨY TRẦN AI SLOP, TÚT LẠI TOÀN DIỆN UI/UX VÀ TỔNG KIỂM THỬ E2E
```

---

### 🚀 GIAI ĐOẠN 1: Nền tảng Bảo mật, CSDL & Điều hướng theo Vai trò (RBAC Shell)
*Mục tiêu: Đóng các lỗ hổng an ninh backend, mở rộng schema database cho nghiệp vụ F&B cao cấp, xây dựng hệ thống điều hướng thông minh theo từng role.*

#### Task 1.1: Bảo vệ toàn bộ Backend API bằng JWT RBAC `[Authorize]`
- **Mô tả:** Áp dụng chặt chẽ thuộc tính `[Authorize(Roles = "...")]` lên từng endpoint trong `OrderController`, `TableController`, `CategoryController`, `ProductController`, `KdsController`, `PaymentController`.
- **Tiêu chí chấp nhận (Acceptance Criteria):**
  - Khách vãng lai gọi các API quản trị/thanh toán/bếp sẽ nhận `401 Unauthorized`.
  - Phục vụ (WAITER) không thể truy cập API Quản trị tài khoản (`403 Forbidden`).
  - Thu ngân (CASHIER) và Quản lý (MANAGER/ADMIN) mới được quyền gọi API thanh toán và kết toán.
- **Xác thực:** Chạy script kiểm thử HTTP RBAC đạt 100% PASS.
- **Tệp chỉnh sửa:** Các file Controller trong `backend/Api/Controllers/`.

#### Task 1.2: Mở rộng CSDL SQL Server & Entity Framework Core
- **Mô tả:** Cập nhật script `RestaurantPosDb.sql` và `RestaurantPosContext.cs` để hỗ trợ:
  - Bảng `Shifts` (Ca làm việc: `ShiftId`, `AccountId`, `StartTime`, `EndTime`, `InitialCash`, `TotalCash`, `TotalCard`, `TotalTransfer`, `Discrepancy`, `Status`, `ZReportJson`).
  - Bảng `Reservations` (Đặt bàn: `ReservationId`, `TableId`, `CustomerName`, `PhoneNumber`, `GuestCount`, `ArrivalTime`, `Note`, `Status`).
  - Bảng `Discounts` (Voucher/Khuyến mãi: `DiscountId`, `Code`, `Percentage`, `MaxAmount`, `MinOrderAmount`, `ExpiryDate`, `IsActive`).
  - Hoàn thiện bảng `OrderDetailModifiers` kết nối với `ProductAttributes`.
- **Tiêu chí chấp nhận:** Chạy script tạo bảng trên SQL Server không có lỗi, DbContext ánh xạ chuẩn xác các DbSet.
- **Tệp chỉnh sửa:** `RestaurantPosDb.sql`, `backend/Models/RestaurantPosContext.cs`, các entity model mới.

#### Task 1.3: Tái cấu trúc Hệ thống Điều hướng Mobile (Role-Aware Navigation Shell)
- **Mô tả:** Xóa bỏ hoàn toàn thanh điều hướng cào bằng và nút Floating Action Button "Hộp rác". Xây dựng `RoleAwareScaffold`:
  - Đăng nhập `CASHIER` -> Mở thẳng màn hình POS Thu ngân Split-screen.
  - Đăng nhập `WAITER` -> Mở Sơ đồ bàn & Gọi món nhanh.
  - Đăng nhập `KITCHEN/BARISTA` -> Mở Màn hình Bếp KDS Fullscreen.
  - Đăng nhập `MANAGER/ADMIN` -> Mở Bảng điều khiển Quản trị & Giám sát tổng thể.
  - Đăng nhập `MEMBER` -> Mở Thực đơn số & Trang cá nhân tích điểm.
- **Tiêu chí chấp nhận:** Chuyển đổi role người dùng tự động thay đổi hoàn toàn giao diện làm việc tương ứng, hiển thị thanh trạng thái kết nối Online/Offline chuyên nghiệp trên AppBar.
- **Tệp chỉnh sửa:** `mobile/lib/main.dart`, tạo mới `mobile/lib/views/navigation/role_navigation_shell.dart`.

---

### 🚀 GIAI ĐOẠN 2: Toàn diện Sơ đồ Bàn, Thực đơn, Modifiers & Offline-First Cache
*Mục tiêu: Hoàn thiện 100% nghiệp vụ bàn ăn F&B, lưu trữ modifier chuẩn hóa và cache thực đơn ngoại tuyến vào SQLite.*

#### Task 2.1: Nghiệp vụ Gộp bàn (Merge) & Tách bàn/đơn (Split)
- **Mô tả:**
  - Backend: Viết API `POST /api/table/merge` (chuyển toàn bộ món từ Bàn B sang Bàn A, giải phóng Bàn B) và `POST /api/table/split` (tách một số món sang bàn mới).
  - Mobile: Thêm modal "Gộp bàn" và "Tách bàn" trực quan trong `FloorTablePage`.
- **Tiêu chí chấp nhận:** Giao dịch database diễn ra trong transaction an toàn, kiểm tra tính toàn vẹn tài chính, cập nhật trạng thái bàn trên UI tức thời.
- **Tệp chỉnh sửa:** `TableController.cs`, `TableRepository.cs`, `mobile/lib/views/table/floor_table_page.dart`.

#### Task 2.2: Nghiệp vụ Đặt bàn trước (Reservation Workflow)
- **Mô tả:**
  - Backend: API `POST /api/table/reserve`, `GET /api/table/reservations`, `PUT /api/table/reservation/{id}/check-in`.
  - Mobile: Form đặt bàn trực quan, bàn đã đặt đổi màu Cam/Hổ phách (`#D97706`), hiển thị giờ hẹn và thông tin khách khi chạm vào.
- **Tiêu chí chấp nhận:** Bàn tự động chuyển sang `Occupied` khi khách đến và nhân viên bấm "Nhận bàn / Check-in".
- **Tệp chỉnh sửa:** `TableController.cs`, `mobile/lib/views/table/reservation_dialog.dart`.

#### Task 2.3: Chuẩn hóa Lưu trữ Modifiers vào `OrderDetailModifiers`
- **Mô tả:**
  - Cập nhật DTO và logic trong `OrderRepository.cs`: Khi tạo đơn, bóc tách danh sách thuộc tính món (Size, Topping, Ghi chú) và lưu vào bảng `OrderDetailModifiers` kèm phụ thu `ExtraPrice`.
  - Server tự động cộng dồn `UnitPrice = Product.Price + Sum(Modifiers.ExtraPrice)` để bảo vệ tính toán tiền tệ.
- **Tiêu chí chấp nhận:** Dữ liệu hóa đơn trong SQL Server hiển thị chi tiết từng topping và phụ thu tương ứng.
- **Tệp chỉnh sửa:** `backend/Models/OrderRepository.cs`, `mobile/lib/models/order.dart`, `product_detail_page.dart`.

#### Task 2.4: Bộ nhớ đệm Thực đơn Ngoại tuyến Toàn diện (Offline Menu SQLite Cache)
- **Mô tả:**
  - Bổ sung bảng `cached_categories` và `cached_products` trong SQLite di động.
  - Khi có mạng, tự động đồng bộ thực đơn từ server về lưu cục bộ.
  - Khi mất mạng hoặc mở app ở chế độ ngoại tuyến: Ứng dụng đọc dữ liệu thực đơn từ SQLite cực nhanh (<10ms), cho phép tìm kiếm, lọc danh mục và thêm vào giỏ bình thường.
- **Tiêu chí chấp nhận:** Tắt wifi/ngắt backend, ứng dụng vẫn mở được trang menu, xem chi tiết món và thêm vào giỏ hàng offline 100%.
- **Tệp chỉnh sửa:** `mobile/lib/utils/database_helper.dart`, `category_repository.dart`, `product_repository.dart`.

---

### 🚀 GIAI ĐOẠN 3: Màn hình Bếp KDS Chuyên nghiệp & In Hóa đơn Nhiệt / PDF
*Mục tiêu: Nâng tầm trạm chế biến KDS và hoàn thiện chức năng in hóa đơn chuẩn F&B.*

#### Task 3.1: Nâng cấp KDS phân trạm Bếp vs Bar & Chế độ Gom món (Batch View)
- **Mô tả:**
  - Phân loại món: Danh mục Đồ ăn -> Bắn trạm Bếp; Danh mục Đồ uống -> Bắn trạm Barista.
  - Bổ sung màn hình "Gom món chế biến" (Aggregated View): Tổng hợp số lượng các món giống nhau đang chờ nấu.
  - Đồng hồ đếm giờ chuyển 3 mức màu: Xanh (<8p), Vàng (8-15p), Đỏ nhấp nháy (>15p).
  - Tích hợp âm thanh chuông báo (Sound chime) khi có order mới.
- **Tiêu chí chấp nhận:** Đầu bếp chuyển trạng thái 1 chạm, nhân viên phục vụ nhận được cập nhật món đã xong.
- **Tệp chỉnh sửa:** `KdsController.cs`, `mobile/lib/views/kitchen/kitchen_display_page.dart`.

#### Task 3.2: Module In Hóa đơn Nhiệt (Thermal Receipt 58/80mm) & Xuất Hóa đơn PDF
- **Mô tả:**
  - Xây dựng Layout hóa đơn chuẩn F&B: Logo quán, Tiêu đề, Mã đơn, Bàn, Tên nhân viên, Danh sách món chi tiết kèm size/topping, Tiền hàng, Giảm giá, VAT, Mã VietQR động, Lời cảm ơn.
  - Hỗ trợ xem trước mẫu hóa đơn nhiệt và xuất/in file PDF đẹp mắt.
  - Hỗ trợ in 2 chế độ: "Phiếu tạm tính" (cho khách đối soát) và "Hóa đơn thanh toán" (sau khi thu tiền).
- **Tiêu chí chấp nhận:** Hóa đơn hiển thị chuẩn nét, khớp số tiền đến từng đồng, quét được mã VietQR trực tiếp trên hóa đơn.
- **Tệp chỉnh sửa:** Thêm `mobile/lib/services/receipt_printer_service.dart`, tích hợp nút "In tạm tính" và "In hóa đơn" vào `order_detail_page.dart` và màn hình thu ngân.

---

### 🚀 GIAI ĐOẠN 4: POS Thu ngân Split-Screen, Quản lý Ca (Shift) & Thanh toán Đa kênh
*Mục tiêu: Xây dựng trạm làm việc chuyên nghiệp cho thu ngân với tốc độ thanh toán siêu tốc.*

#### Task 4.1: Xây dựng Giao diện POS Thu ngân Split-Screen
- **Mô tả:**
  - Thiết kế màn hình POS chuẩn cho Tablet/Desktop:
    - Nửa bên trái: Phân loại danh mục theo tab + Lưới món ăn ảnh lớn chạm nhanh.
    - Nửa bên phải: Phiếu order đang chọn, danh sách món, nút tăng giảm số lượng to, chọn bàn, nhập voucher, và tổng tiền.
  - Bàn phím số Numpad tiền mặt: Các nút mệnh giá nhanh (`50k`, `100k`, `200k`, `500k`, `Khách đưa đủ`) tự động tính tiền thừa trả khách.
- **Tiêu chí chấp nhận:** Thu ngân thao tác nhập món và tính tiền hoàn tất trong dưới 15 giây.
- **Tệp chỉnh sửa:** Tạo mới `mobile/lib/views/cashier/cashier_pos_terminal_page.dart`.

#### Task 4.2: Nghiệp vụ Quản lý Ca làm việc & Chốt két (Shift Register & Z-Report)
- **Mô tả:**
  - Backend: API `POST /api/shift/open`, `POST /api/shift/close`, `GET /api/shift/current`, `GET /api/shift/{id}/z-report`.
  - Mobile: Màn hình mở ca (nhập tiền lẻ float), theo dõi doanh thu trong ca theo phương thức thanh toán, và màn hình đóng ca đếm tiền thực tế kèm in phiếu Z-Report.
- **Tiêu chí chấp nhận:** Báo cáo Z-Report thể hiện chính xác doanh thu tiền mặt, chuyển khoản VietQR, VNPay, và ghi nhận tiền chênh lệch thừa/thiếu nếu có.
- **Tệp chỉnh sửa:** Tạo mới Controller/Repository Shift, tạo `mobile/lib/views/cashier/shift_management_page.dart`.

#### Task 4.3: Gọi thêm món vào Bàn đang phục vụ (Add Items Flow)
- **Mô tả:** Cho phép Thu ngân hoặc Phục vụ mở bàn đang có khách (`Occupied`), bấm "Gọi thêm món", chọn thêm đồ ăn và bấm "Cập nhật vào đơn". Các món mới được thêm vào đơn hàng hiện tại và bắn xuống KDS.
- **Tiêu chí chấp nhận:** Đơn hàng được cập nhật tổng tiền mà không tạo đơn mới, bàn giữ nguyên trạng thái.
- **Tệp chỉnh sửa:** `OrderController.cs`, `OrderRepository.cs`, `floor_table_page.dart`.

---

### 🚀 GIAI ĐOẠN 5: Cổng Khách hàng (Member Portal), Voucher, Đặt bàn & Xác thực Nâng cao
*Mục tiêu: Đạt trọn vẹn điểm cộng Barem (Voucher, Đặt bàn, Tra cứu đơn, OTP Email, Quên mật khẩu).*

#### Task 5.1: Cổng Thực đơn số & Khách hàng Thành viên (Member Portal)
- **Mô tả:**
  - Giao diện dành riêng cho khách hàng: Xem Menu số đẹp mắt, xem ưu đãi, lịch sử hóa đơn các lần ăn trước.
  - Tích điểm thành viên: Hiển thị hạng thành viên, tích lũy điểm thưởng theo tỷ lệ 100.000đ = 10 điểm, quy đổi điểm để giảm giá hóa đơn.
  - Tra cứu đơn hàng: Nhập mã đơn hoặc số điện thoại để xem trạng thái phục vụ.
- **Tiêu chí chấp nhận:** Khách hàng đăng nhập có không gian riêng, không nhìn thấy các nút quản trị nội bộ của nhân viên quán.
- **Tệp chỉnh sửa:** Tạo mới `mobile/lib/views/member/member_home_page.dart`.

#### Task 5.2: Tích hợp Mã giảm giá / Voucher (Discount Engine)
- **Mô tả:**
  - Backend: API `POST /api/discount/validate` kiểm tra tính hợp lệ của mã giảm giá.
  - Áp dụng mã giảm giá vào đơn hàng: Trừ tiền theo % hoặc số tiền cố định, lưu `DiscountAmount` và `FinalAmount` chính xác vào SQL Server.
- **Tiêu chí chấp nhận:** Đơn hàng tính toán tài chính chuẩn xác, hiển thị tiền giảm giá trên hóa đơn in ra.
- **Tệp chỉnh sửa:** `DiscountController.cs`, `order_checkout_page.dart`.

#### Task 5.3: Xác thực Nâng cao (Xác thực Email OTP & Quên mật khẩu)
- **Mô tả:**
  - Bổ sung API `POST /api/auth/send-otp`, `POST /api/auth/verify-email`, `POST /api/auth/forgot-password`, `POST /api/auth/reset-password`.
  - Giao diện quên mật khẩu & nhập mã OTP xác thực trên mobile.
- **Tiêu chí chấp nhận:** Đạt trọn vẹn 1.0 điểm cộng Barem theo Mục 1.8 và 1.9 của tài liệu giảng viên.
- **Tệp chỉnh sửa:** `AuthController.cs`, `AccountRepository.cs`, tạo `mobile/lib/views/auth/forgot_password_page.dart`.

---

### 🚀 GIAI ĐOẠN 6: Tẩy trần "AI Slop", Tút lại Toàn diện UI/UX & Kiểm thử E2E
*Mục tiêu: Nâng tầm toàn bộ giao diện thành sản phẩm F&B thương mại đẳng cấp, loại bỏ triệt để mọi chi tiết generic, đảm bảo bộ kiểm thử 100% Pass.*

#### Task 6.1: Tút lại Toàn bộ Màn hình theo Design System "Modern Artisan Bistro"
- **Mô tả:**
  - Áp dụng bảng màu nhất quán: Deep Slate `#0F172A`, Caramel Amber `#D97706`, Emerald Mint `#059669`.
  - Tăng kích thước toàn bộ các nút bấm tương tác $\ge 48 \times 48$ px.
  - Thay thế toàn bộ vòng quay tròn bằng Skeleton Shimmer Loading chuyên nghiệp.
  - Xây dựng Empty States có đồ họa minh họa ấm cúng mang phong cách nhà hàng/quán cà phê.
  - Loại bỏ hoàn toàn các dòng code mock cứng trong `database_helper.dart`.
- **Tiêu chí chấp nhận:** Giao diện sắc nét, phân cấp thông tin rõ ràng, không còn dấu vết của mã mẫu AI generic.
- **Tệp chỉnh sửa:** Toàn bộ các file views trong `mobile/lib/views/`.

#### Task 6.2: Tổng kiểm thử E2E & Bàn giao Sản phẩm
- **Mô tả:**
  - Chạy toàn bộ các bộ kiểm thử tự động: Unit test, Widget test, Backend integration test, Security RBAC test.
  - Chạy kịch bản người dùng trọn vòng (Full User Journey): Mở ca -> Đặt bàn -> Gọi món tại bàn -> Gửi Bếp KDS -> Nấu xong -> In tạm tính -> Thanh toán tiền mặt/VietQR/VNPay -> Giải phóng bàn -> Đóng ca in Z-Report.
  - Cập nhật tài liệu nghiệm thu `REQUIREMENTS_TRACEABILITY.md` và `PROJECT.md` với đầy đủ bằng chứng thực tế.
- **Tiêu chí chấp nhận:** Toàn bộ test suite PASS 100%, 0 lỗi biên dịch, 0 lỗi cảnh báo.

---

## 7. CHECKLIST DUYỆT & CÁC CÂU HỎI QUYẾT ĐỊNH DÀNH CHO BẠN

Trước khi bắt tay vào triển khai thực tế, xin gửi đến bạn các quyết định chiến lược để bạn duyệt:

1. **Về Giao diện Điều hướng:**  
   Bạn có đồng ý xóa bỏ nút Floating Action Button (hộp rác ẩn chức năng) và Tab "Đồng bộ đơn" dưới đáy, để chuyển sang **Role-Aware Navigation Shell** (chia màn hình riêng theo vai trò: Thu ngân vào POS Split-Screen, Bếp vào KDS, Phục vụ vào Sơ đồ bàn, Khách vào Menu số) không?
   
2. **Về Thứ tự Ưu tiên Triển khai:**  
   Bạn có muốn triển khai theo đúng trình tự **Phase 1 -> Phase 2 -> Phase 3 -> Phase 4 -> Phase 5 -> Phase 6** như kế hoạch, hay muốn tập trung dứt điểm ngay vào phần nào trước (ví dụ: làm ngay POS Thu ngân & In hóa đơn, hoặc làm ngay Gộp/Tách bàn)?

3. **Về Mẫu In Hóa đơn:**  
   Bạn có muốn hỗ trợ in hóa đơn nhiệt dạng xem trước (Preview Receipt) và xuất PDF hóa đơn có mã VietQR động trực tiếp trên điện thoại/máy tính không?

---
*Kế hoạch được lập với sự cẩn trọng cao nhất, sẵn sàng chờ bạn phản hồi và bấm duyệt để tiến hành từng bước!*
