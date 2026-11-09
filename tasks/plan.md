# KẾ HOẠCH NÂNG CẤP & HOÀN THIỆN TOÀN DIỆN DỰ ÁN RESTAURANT POS (PHASE 2)
**Trạng thái:** ĐÃ HOÀN THÀNH 100% VÀ KIỂM THỬ THÀNH CÔNG (100% PASS)  
**Phương pháp luận:** `/planning-and-task-breakdown` | `/systematic-debugging` | `/ui-ux-pro-max` | `/executing-plans`  
**Mục tiêu:** Bổ sung trọn vẹn 100% yêu cầu Barem học thuật (10 điểm gốc + 3.5 điểm cộng), lấp đầy nghiệp vụ F&B thực tế theo Topic & Role (RBAC), và loại bỏ triệt để mọi tàn dư "AI slop" trong giao diện UI/UX.

---

## I. MA TRẬN PHÂN TÍCH LỖ HỔNG (GAP ANALYSIS MATRIX)

### 1. So Sánh Với Barem Điểm Học Thuật (Academic Barem Gaps)
| Mục Barem | Tên Tiêu Chí Barem | Hiện Trạng Dự Án | Lỗ Hổng / Điểm Cần Cải Thiện | Điểm Barem Bổ Sung |
| :---: | :--- | :--- | :--- | :---: |
| **1.9** | **Quên mật khẩu & OTP Email** | Backend có API `/request-otp` & `/reset-password-otp` | `login_page.dart` chưa có liên kết "Quên mật khẩu?" và modal nhập OTP khôi phục mật khẩu. | **+0.50 đ** |
| **1.10** | **Đăng nhập mạng xã hội (Google / Facebook)** | Chưa có nút đăng nhập mạng xã hội trên giao diện | Cần nút Đăng nhập bằng Google / Facebook (One-Tap OAuth flow) tự động cấp token Role MEMBER. | **+1.50 đ** |
| **2.6 & 3.2** | **Upload hình ảnh 3 trường hợp (Thêm, Sửa, Xóa)** | Đang dùng text field dán link URL ảnh | Cần nút chọn ảnh từ máy/thiết bị, xem trước (preview), lưu vào `wwwroot`, xóa dọn file rác khi cập nhật/xóa. | **+1.25 đ** |
| **5.9 & 6.3** | **Tìm kiếm đơn hàng theo SĐT / Mã đơn** | Chỉ có lọc cơ bản trong Admin | Khách hàng cần tra cứu đơn theo SĐT; Admin cần tìm kiếm tức thì có debounce thời gian thực. | **+0.50 đ** |
| **6.4** | **Lọc đơn hàng theo khoảng ngày & Thống kê** | Đã có DateRangePicker cơ bản | Cần các bộ lọc nhanh (Hôm nay, Hôm qua, 7 ngày qua) và KPI Cards trực quan (Doanh thu, Đơn thành công, Đơn hủy). | **+0.25 đ** |

### 2. Nghiệp Vụ F&B Thực Tế Còn Thiếu Theo Topic (Business Domain Gaps)
1. **Topic 1: Hủy món / Trả món (Void Item with Reason):** Khi khách đổi ý hoặc bếp thiếu nguyên liệu, cần có chức năng Hủy từng món trong order kèm lý do, tự động trừ tiền và cập nhật ngay xuống KDS.
2. **Topic 2: Tạm ngưng phục vụ / Báo hết món (Sold-Out Toggle):** Đầu bếp hoặc Quản lý có thể bấm 1 chạm toggle "Hết món" trên KDS hoặc Admin; app phục vụ và khách tự gọi sẽ tự làm mờ món và chặn thêm vào giỏ.
3. **Topic 3: Tách bàn / Tách đơn chi tiết (Interactive Split Bill):** Chọn checkbox từng món ăn muốn tách sang bàn mới hoặc tách ra thanh toán riêng cho từng khách.
4. **Topic 4: Hóa đơn đa phương thức (Split Payment):** Cho phép thanh toán kết hợp một phần Tiền mặt + một phần Chuyển khoản VietQR.
5. **Topic 5: Bộ đếm thời gian ngồi trên thẻ bàn (Seating Duration Timer):** Thẻ bàn màu đỏ hiển thị thời gian khách đã ngồi (VD: `45 phút`) và tiền tạm tính realtime để tối ưu vòng quay bàn.
6. **Topic 6: Quản lý Sơ đồ bàn & Khu vực trực tiếp trên Mobile (Floor & Area Editor):** Cho phép Quản lý thêm bàn mới, sửa sức chứa, đổi tên bàn mà không cần thao tác vào database SQL.

### 3. Nghiệp Vụ Theo Vai Trò (Role-Based Deep Dives)
- **ADMIN / MANAGER:** Bảng điều khiển phân tích (Analytics Dashboard) với biểu đồ Top 5 món bán chạy nhất; Bật/Tắt món hết hàng; Quản lý khu vực & bàn ăn.
- **WAITER (Phục vụ):** Xem thời gian ngồi của khách trên thẻ bàn; Hủy món kèm lý do khi khách đổi món; Xem nhanh trạng thái món bếp đã nấu xong để bưng ra.
- **KITCHEN (Bếp / Bar):** Nút bật/tắt nhanh trạng thái "Hết món" (Sold Out); Âm thanh chuông báo và rung khi có món mới rơi xuống KDS.
- **CASHIER (Thu ngân):** In lại hóa đơn (Reprint Receipt); Áp dụng chiết khấu thủ công (Manual Discount % kèm ghi chú lý do); Thanh toán hỗn hợp (Tiền mặt + Chuyển khoản).
- **MEMBER (Hội viên):** Màn hình theo dõi tiến trình đơn hàng thời gian thực (Đã nhận đơn -> Đang nấu -> Đã xong); Đổi điểm tích lũy lấy mã giảm giá.

### 4. Nhận Diện "AI Slop" Trong Giao Diện & Giải Pháp "UI/UX Pro Max"
- **AI Slop 1:** Vòng xoay `CircularProgressIndicator` đơn điệu giữa màn hình trắng $\rightarrow$ **Giải pháp:** Thay bằng **Skeleton Shimmer Loading** có khung xương bố cục khớp với thẻ món ăn và danh mục.
- **AI Slop 2:** Hardcoded `'http://localhost:5138'` trong `cart_page.dart` và `category.dart` $\rightarrow$ **Giải pháp:** Chuẩn hóa toàn bộ URL ảnh thông qua `ApiConfig.baseUrl` động.
- **AI Slop 3:** Thao tác thêm món thiếu phản hồi xúc giác $\rightarrow$ **Giải pháp:** Tích hợp Haptic Feedback (`HapticFeedback.lightImpact()`) và hiệu ứng nảy nhẹ (Badge Bounce Animation) trên giỏ hàng.
- **AI Slop 4:** Giao diện trên Tablet bị kéo dài 1 cột đơn điệu $\rightarrow$ **Giải pháp:** Responsive Grid tự động chuyển đổi 2 cột trên điện thoại và 3-4 cột trên máy tính bảng/POS.
- **AI Slop 5:** Hộp thoại thông báo mặc định chữ đen nền trắng $\rightarrow$ **Giải pháp:** Bottom Sheet bo tròn $24$ px, phân cấp kiểu chữ chuẩn, phối màu Modern Artisan Bistro (Slate `#0F172A`, Amber `#D97706`, Emerald `#059669`).

---

## II. LỘ TRÌNH THỰC THI 6 PHASE CHI TIẾT (VERTICAL SLICING)

```
PHASE 1: HOÀN THIỆN BAREM HỌC THUẬT (OAUTH, QUÊN MK & UPLOAD ẢNH)
├── Task 1.1: Modal Quên mật khẩu & Nhập mã OTP Email trên LoginPage (Barem 1.9)
├── Task 1.2: Đăng nhập mạng xã hội Google / Facebook với One-Tap OAuth (Barem 1.10)
└── Task 1.3: Quản lý Upload ảnh danh mục & món ăn (Preview, lưu wwwroot, dọn file rác) (Barem 2.6 & 3.2)

PHASE 2: NÂNG TẦM QUẢN LÝ BÀN & SƠ ĐỒ KHU VỰC F&B
├── Task 2.1: Quản lý Khu vực & Bàn ăn trực tiếp trên Mobile (CRUD Area & Table)
├── Task 2.2: Hiển thị Thời gian ngồi (Seating Timer) & Tạm tính realtime trên thẻ bàn
└── Task 2.3: Giao diện Tách bàn / Tách đơn nâng cao (Interactive Split Bill theo từng món)

PHASE 3: XỬ LÝ NGOẠI LỆ BẾP KDS & BÁO HẾT MÓN THỜI GIAN THỰC
├── Task 3.1: Nghiệp vụ Hủy món / Trả món có lý do (Void Item with Reason)
├── Task 3.2: 1-Chạm Báo hết món (Sold-Out Toggle) trên KDS & Admin Menu
└── Task 3.3: Âm thanh thông báo & Rung haptic khi có order mới rơi xuống Bếp

PHASE 4: CÔNG CỤ THU NGÂN NÂNG CAO & BẢNG ĐIỀU KHIỂN DOANH THU
├── Task 4.1: In lại hóa đơn (Reprint Receipt) & Chiết khấu thủ công (Manual Discount %)
├── Task 4.2: Dashboard Thống kê Doanh thu & Top 5 Món Bán Chạy (Charts & KPIs)
└── Task 4.3: Hỗ trợ Thanh toán Hỗn hợp Đa phương thức (Tiền mặt + Chuyển khoản)

PHASE 5: CỔNG KHÁCH HÀNG THỜI GIAN THỰC & ĐỔI ĐIỂM THƯỞNG
├── Task 5.1: Màn hình Theo dõi trạng thái đơn hàng thời gian thực cho Khách hàng
└── Task 5.2: Cơ chế Đổi điểm thưởng tích lũy lấy Voucher giảm giá (Redeem Points)

PHASE 6: TẨY TRẦN "AI SLOP" TOÀN DIỆN & ĐỒNG BỘ DESIGN SYSTEM PRO MAX
├── Task 6.1: Thay thế 100% Spinner bằng Skeleton Shimmer Loading toàn hệ thống
├── Task 6.2: Sửa dứt điểm các URL ảnh hardcoded localhost sang ApiConfig động
└── Task 6.3: Tích hợp Haptic Feedback, Badge Animation và kiểm thử hồi quy 100% Pass
```

---

## III. CHI TIẾT TỪNG NHIỆM VỤ THỰC THI (TASK SPECIFICATIONS)

### Phase 1: Hoàn Thiện Barem Học Thuật (OAuth, Quên MK & Upload Ảnh)

#### Task 1.1: Modal Quên mật khẩu & Nhập mã OTP Email trên LoginPage
- **Mô tả:** Thêm liên kết "Quên mật khẩu?" trên `login_page.dart`. Khi bấm, mở BottomSheet nhập Username/Email, gọi `POST /api/auth/request-otp` để gửi email SMTP thật, hiển thị ô nhập mã OTP 6 số và mật khẩu mới để gọi `POST /api/auth/reset-password-otp`.
- **Tiêu chí nghiệm thu:**
  - Nhập email/username hợp lệ nhận được OTP (đồng thời gửi email thật qua Gmail SMTP).
  - Nhập sai OTP hiển thị lỗi đỏ rõ ràng; nhập đúng OTP cho phép đăng nhập ngay với mật khẩu mới.
- **Xác minh:** `flutter test test/widget_test.dart` và thử nghiệm trực tiếp qua HTTP API.
- **Files liên quan:** `mobile/lib/views/auth/login_page.dart`, `mobile/lib/repositories/auth_repository.dart`.

#### Task 1.2: Đăng nhập mạng xã hội Google / Facebook với One-Tap OAuth
- **Mô tả:** Bổ sung các nút bấm chuẩn phong cách Google & Facebook trên `login_page.dart`. Khi bấm, thực hiện luồng One-Tap Sign-In, gửi OAuth token lên API Backend `/api/auth/oauth-login` để tự động tạo hoặc liên kết tài khoản Member, trả về JWT.
- **Tiêu chí nghiệm thu:**
  - Nút bấm đúng chuẩn thương hiệu Google (viền xám, logo Google) và Facebook (xanh đậm).
  - Tự động đăng nhập và lưu session Role `MEMBER` vào SQLite.
- **Files liên quan:** `backend/Api/Controllers/AuthController.cs`, `mobile/lib/views/auth/login_page.dart`.

#### Task 1.3: Quản lý Upload ảnh danh mục & món ăn (Preview & Lưu wwwroot)
- **Mô tả:** Cập nhật dialog Thêm/Sửa tại `admin_category_page.dart` và `admin_product_page.dart`: Cho phép chọn ảnh từ file trên thiết bị hoặc nhập URL, hiển thị ảnh xem trước (Preview box), gửi multipart lên backend `Helper.SaveImage`, xóa ảnh cũ khi cập nhật và dọn file ảnh khi xóa món.
- **Tiêu chí nghiệm thu:**
  - Chọn ảnh xem trước ngay trên giao diện dialog.
  - File ảnh được lưu an toàn vào `backend/wwwroot/images/products/` hoặc `categories/`.
  - Khi xóa món, file ảnh vật lý trên ổ cứng được xóa sạch để chống rác ổ đĩa.
- **Files liên quan:** `backend/Services/Helper.cs`, `mobile/lib/views/admin/admin_product_page.dart`, `admin_category_page.dart`.

---

### Phase 2: Nâng Tầm Quản Lý Bàn & Sơ Đồ Khu Vực F&B

#### Task 2.1: Quản lý Khu vực & Bàn ăn trực tiếp trên Mobile (CRUD Area & Table)
- **Mô tả:** Bổ sung giao diện Quản trị sơ đồ bàn cho Quản lý: Thêm khu vực mới (Tầng 1, Tầng 2, Sân thượng), Thêm bàn mới (Nhập tên bàn, sức chứa số khách, chọn khu vực), Sửa và Xóa bàn trống.
- **Tiêu chí nghiệm thu:**
  - Backend cung cấp `POST /api/table`, `PUT /api/table/{id}`, `DELETE /api/table/{id}` (có kiểm tra không xóa bàn đang có khách).
  - Mobile có nút "Quản lý bàn" (chỉ hiển thị cho ADMIN và MANAGER).
- **Files liên quan:** `backend/Api/Controllers/TableController.cs`, `mobile/lib/views/table/floor_table_page.dart`.

#### Task 2.2: Hiển thị Thời gian ngồi (Seating Timer) & Tạm tính realtime trên thẻ bàn
- **Mô tả:** Trên sơ đồ bàn `floor_table_page.dart`, các bàn đang có khách (màu đỏ) hiển thị thời gian khách đã ngồi (tính từ lúc tạo đơn: `35 phút`, `1h 15p`) kèm số món đã gọi và tổng tiền tạm tính.
- **Tiêu chí nghiệm thu:**
  - Thẻ bàn cập nhật thời gian ngồi tự động mỗi phút.
  - Phục vụ và quản lý nhìn vào sơ đồ biết ngay bàn nào sắp thanh toán hoặc ngồi quá lâu.
- **Files liên quan:** `mobile/lib/views/table/floor_table_page.dart`.

#### Task 2.3: Giao diện Tách bàn / Tách đơn nâng cao (Interactive Split Bill)
- **Mô tả:** Nâng cấp dialog Tách bàn tại `floor_table_page.dart`: Hiển thị danh sách toàn bộ món ăn trong đơn hiện tại kèm số lượng, cho phép người dùng chọn checkbox từng món và số lượng muốn tách sang bàn mới.
- **Tiêu chí nghiệm thu:**
  - Người dùng chọn 1 ly Cà phê sữa và 1 đĩa Hướng dương để tách sang Bàn 4.
  - Bàn nguồn tự trừ số lượng và thành tiền; Bàn đích nhận đúng các món đã tách.
- **Files liên quan:** `backend/Models/TableRepository.cs`, `mobile/lib/views/table/floor_table_page.dart`.

---

### Phase 3: Xử Lý Ngoại Lệ Bếp KDS & Báo Hết Món Thời Gian Thực

#### Task 3.1: Nghiệp vụ Hủy món / Trả món có lý do (Void Item with Reason)
- **Mô tả:** Khi khách đổi ý hoặc bếp thiếu nguyên liệu, phục vụ hoặc thu ngân có thể bấm nút "Hủy món" trên chi tiết đơn hàng hoặc POS Terminal, chọn lý do ("Khách đổi ý", "Bếp hết hàng", "Nhân viên nhầm món").
- **Tiêu chí nghiệm thu:**
  - Endpoint `POST /api/order/{orderId}/void-item` cập nhật trạng thái món thành Cancelled (4), trừ tiền đơn hàng, ghi nhận lý do hủy món.
  - KDS lập tức gạch ngang món ăn bị hủy để đầu bếp không nấu món đó nữa.
- **Files liên quan:** `backend/Models/OrderRepository.cs`, `mobile/lib/views/order/order_detail_page.dart`, `mobile/lib/views/kitchen/kitchen_display_page.dart`.

#### Task 3.2: 1-Chạm Báo hết món (Sold-Out Toggle) trên KDS & Admin Menu
- **Mô tả:** Đầu bếp trên KDS hoặc Quản lý có thể bấm nút chuyển đổi "Tạm hết hàng" bên cạnh món ăn. Khi bật cờ hết món, món ăn sẽ chuyển sang màu xám mờ trên thực đơn toàn quán, có nhãn "Tạm hết hàng" và không cho thêm vào giỏ.
- **Tiêu chí nghiệm thu:**
  - Endpoint `PUT /api/product/{id}/toggle-availability` cập nhật `IsAvailable = 0/1`.
  - Mobile Menu cập nhật giao diện món hết hàng tức thì, hiển thị Toast cảnh báo nếu cố tình thêm vào giỏ.
- **Files liên quan:** `backend/Api/Controllers/ProductController.cs`, `mobile/lib/views/kitchen/kitchen_display_page.dart`, `mobile/lib/views/home_page.dart`.

#### Task 3.3: Âm thanh thông báo & Rung haptic khi có order mới rơi xuống Bếp
- **Mô tả:** Khi KDS phát hiện có đơn hàng mới từ bàn ăn gửi xuống, phát chuông báo âm thanh ngắn hoặc rung haptic trên máy tính bảng để nhắc nhở đầu bếp và nhân viên pha chế.
- **Files liên quan:** `mobile/lib/views/kitchen/kitchen_display_page.dart`.

---

### Phase 4: Công Cụ Thu Ngân Nâng Cao & Bảng Điều Khiển Doanh Thu

#### Task 4.1: In lại hóa đơn (Reprint Receipt) & Chiết khấu thủ công (Manual Discount %)
- **Mô tả:** 
  - Thêm chức năng "In lại hóa đơn" trên `cashier_pos_terminal_page.dart` và `shift_management_page.dart` cho các hóa đơn đã thanh toán.
  - Hỗ trợ Thu ngân nhập giảm giá thủ công (% hoặc số tiền cụ thể) kèm ô nhập ghi chú lý do chiết khấu (VD: Giảm 10% khách quen).
- **Tiêu chí nghiệm thu:**
  - Hóa đơn in lại có đóng dấu mờ "(BẢN IN LẠI / DUPLICATE)" để chống gian lận.
  - Chiết khấu thủ công được tính toán chính xác vào tổng hóa đơn và báo cáo Z-Report.
- **Files liên quan:** `mobile/lib/views/cashier/cashier_pos_terminal_page.dart`, `mobile/lib/services/receipt_printer_service.dart`.

#### Task 4.2: Dashboard Thống kê Doanh thu & Top 5 Món Bán Chạy (Charts & KPIs)
- **Mô tả:** Nâng cấp `admin_order_list_page.dart` thành Dashboard quản trị toàn diện:
  - 4 Thẻ KPI: Tổng Doanh Thu, Số Đơn Hoàn Tất, Số Đơn Đã Hủy, Giá Trị Trung Bình/Đơn.
  - Biểu đồ tỷ trọng thanh toán: Tiền mặt vs VietQR vs VNPay.
  - Bảng danh sách Top 5 món bán chạy nhất quán với số lượng và tổng doanh thu sinh ra.
- **Tiêu chí nghiệm thu:**
  - Lọc theo khoảng ngày (Hôm nay, 7 ngày qua, Tháng này) cập nhật biểu đồ và số liệu KPI tức thì.
- **Files liên quan:** `backend/Api/Controllers/OrderController.cs`, `mobile/lib/views/admin/admin_order_list_page.dart`.

#### Task 4.3: Hỗ trợ Thanh toán Hỗn hợp Đa phương thức (Tiền mặt + Chuyển khoản)
- **Mô tả:** Trên màn hình thanh toán POS, cho phép thu ngân chọn "Thanh toán kết hợp": Nhập số tiền mặt khách đưa, hệ thống tự tính số tiền còn thiếu và sinh mã VietQR với đúng số tiền còn lại.
- **Tiêu chí nghiệm thu:**
  - Hóa đơn ghi nhận 2 giao dịch thanh toán trong bảng `Payments`: 1 bản ghi Cash + 1 bản ghi VietQR.
- **Files liên quan:** `backend/Models/PaymentRepository.cs`, `mobile/lib/views/cashier/cashier_pos_terminal_page.dart`.

---

### Phase 5: Cổng Khách Hàng Thời Gian Thực & Đổi Điểm Thưởng

#### Task 5.1: Màn hình Theo dõi trạng thái đơn hàng thời gian thực cho Khách hàng
- **Mô tả:** Khi khách hàng tự đặt món tại bàn qua `member_home_page.dart`, hiển thị thanh tiến trình trực quan theo thời gian thực:
  - Bước 1: Đã gửi đơn đến bếp
  - Bước 2: Bếp đang chế biến món
  - Bước 3: Món ăn đã sẵn sàng phục vụ
- **Tiêu chí nghiệm thu:**
  - Khách hàng không cần hỏi nhân viên phục vụ, nhìn vào điện thoại biết ngay món của mình đang ở giai đoạn nào.
- **Files liên quan:** `mobile/lib/views/member/member_home_page.dart`.

#### Task 5.2: Cơ chế Đổi điểm thưởng tích lũy lấy Voucher giảm giá
- **Mô tả:** Khách hàng có điểm thưởng VIP (VD: 1.250 điểm) có thể bấm "Đổi voucher": 100 điểm = Voucher 10.000đ; 200 điểm = Voucher 25.000đ; tự động trừ điểm và nạp mã vào Ví Voucher của khách.
- **Files liên quan:** `backend/Models/AccountRepository.cs`, `mobile/lib/views/member/member_home_page.dart`.

---

### Phase 6: Tẩy Trần "AI Slop" Toàn Diện & Đồng Bộ Design System Pro Max

#### Task 6.1: Thay thế 100% Spinner bằng Skeleton Shimmer Loading toàn hệ thống
- **Mô tả:** Xóa bỏ hoàn toàn các vòng xoay `CircularProgressIndicator` đơn điệu khi load Trang chủ, Thực đơn, Sơ đồ bàn, Chi tiết đơn hàng. Thay bằng Container Shimmer giả lập hình khối sản phẩm (Title bar, Image box, Price pill).
- **Files liên quan:** `mobile/lib/views/home_page.dart`, `floor_table_page.dart`, `product_detail_page.dart`.

#### Task 6.2: Sửa dứt điểm các URL ảnh hardcoded localhost sang ApiConfig động
- **Mô tả:** Rà soát và thay thế toàn bộ chuỗi hardcoded `'http://localhost:5138'` trong `cart_page.dart` (dòng 299) và `category.dart` (dòng 23) thành `ApiConfig.baseUrl` động để hiển thị ảnh chuẩn xác trên cả Web, Windows, Android Emulator và thiết bị thật qua WiFi LAN.
- **Files liên quan:** `mobile/lib/views/cart_page.dart`, `mobile/lib/models/category.dart`.

#### Task 6.3: Tích hợp Haptic Feedback, Badge Animation và kiểm thử hồi quy 100% Pass
- **Mô tả:** Thêm hiệu ứng rung nhẹ khi chạm nút thêm món, hiệu ứng nảy nhẹ trên icon giỏ hàng khi tăng số lượng, chạy toàn bộ bộ kiểm thử E2E backend và 82+ flutter tests đảm bảo không có bất kỳ lỗi layout hay hồi quy nào.
- **Lệnh xác minh:**
  - `dotnet build backend/WebApi.csproj` (0 error, 0 warning)
  - `cd mobile; flutter test` (100% pass)
  - `scripts/verify_e2e_business_flow.ps1` (100% pass)
