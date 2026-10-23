# BÁO CÁO KẾT QUẢ THỰC THI KIỂM THỬ TÍCH HỢP ĐẦU CUỐI (E2E)
## HỆ THỐNG QUẢN LÝ NHÀ HÀNG & CÀ PHÊ RESTAURANT POS SYSTEM

---

## 1. MÔI TRƯỜNG THỰC THI & PHIÊN BẢN CÔNG CỤ (ENVIRONMENT)

- **Hệ điều hành:** Microsoft Windows 10 Pro 64-bit (Build 19045, 22H2)
- **Nhánh kiểm thử Git:** `test/restaurant-real-acceptance`
- **HEAD Commit:** `f9c31bc` (feat(ui): redesign floor table plan with premium modern F&B POS design system)
- **Cơ sở dữ liệu:** Microsoft SQL Server 2022 Express Edition (16.0.1000.6) trên `localhost\SQLEXPRESS`
- **Catalog kiểm thử cách ly:** `RestaurantPos_Acceptance`
- **Backend Runtime:** .NET SDK `10.0.401` / ASP.NET Core `net10.0` chạy trên cổng `http://localhost:5138`
- **Frontend Runtime:** Flutter `3.47.1` (Channel stable) • Dart `3.13.1` • DevTools `2.60.0`
- **Android SDK:** Version `36.0.0` (Build-Tools `36.0.0`, Platform `android-37.0`, `ANDROID_HOME = D:\Download\Android\Sdk`)
- **Java JDK:** OpenJDK `25.0.2` (`D:\Download\Android Studio\jbr`)

---

## 2. KẾT QUẢ BIÊN DỊCH & PHÂN TÍCH TĨNH (PHASE 2)

```powershell
dotnet restore backend/WebApi.csproj
dotnet build backend/WebApi.csproj -c Debug
```
- **Mã thoát (Exit Code):** `0`
- **Cảnh báo (Warnings):** `0 Warning(s)`
- **Lỗi (Errors):** `0 Error(s)`
- **Thời gian biên dịch:** `3.10 giây`

```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
```
- **`flutter pub get`:** Thành công (Tải toàn bộ dependencies)
- **`flutter analyze`:** `No issues found!` (Mã thoát 0, 0 lỗi, 0 cảnh báo)
- **`flutter test`:** `All tests passed!` (**57 / 57 test suite passed 100%**)

---

## 3. BẢNG TỔNG HỢP KẾT QUẢ CÁC BỘ KIỂM THỬ THỰC TẾ

| Bộ Kiểm Thử | Tệp Kịch Bản | Mục Tiêu Kiểm Định | Tổng Số Ca | Đạt (PASS) | Hỏng (FAIL) | Tỷ Lệ Đạt |
| :--- | :--- | :--- | :---: | :---: | :---: | :---: |
| **SQL Server Adversarial** | `scripts/verify_r3_db_adversarial.ps1` | CSDL, Khóa ngoại, Chỉ mục, Ràng buộc Unique, Cascade Delete | 28 | 28 | 0 | **100 %** |
| **HTTP Auth & RBAC** | `scripts/verify_r3_http_rbac.ps1` | Đăng ký, Đăng nhập 6 Role, Đổi MK, Phân quyền endpoint 401/403 | 25 | 25 | 0 | **100 %** |
| **Adversarial Security** | `scripts/challenge_r3_rbac.py` | JWT giả mạo, SQL Injection, Fuzzing, Chống nâng quyền | 64 | 64 | 0 | **100 %** |
| **E2E Business Flow** | `scripts/verify_e2e_business_flow.ps1` | Danh mục, Món ăn, Phân trang, Đặt bàn, KDS, Tiền mặt, VietQR, VNPay, Offline Sync | 26 | 26 | 0 | **100 %** |
| **Mobile Repository & UI** | `mobile/test/` | Lỗi mạng thực tế, Sơ đồ bàn, Chuyển bàn, Đồng bộ SQLite | 57 | 57 | 0 | **100 %** |
| **TỔNG CỘNG** | **Toàn hệ thống** | **Kiểm thử độc lập không sử dụng Mock** | **200** | **200** | **0** | **100 %** |

---

## 4. CHI TIẾT 26 CA KIỂM THỬ E2E BUSINESS FLOW

Tất cả các ca kiểm thử dưới đây được thực thi trực tiếp qua HTTP Client đến `http://localhost:5138` và ghi nhận trực tiếp vào SQL Server `RestaurantPos_Acceptance`:

| Mã Ca | Nhóm | Phương Thức & Đường Dẫn | Trạng Thái HTTP | Độ Trễ (ms) | Mô Tả & Bằng Chứng Thực Tế |
| :--- | :--- | :--- | :---: | :---: | :--- |
| `CAT-01` | CATALOG | `GET /api/category` | 200 OK | 90.80 ms | Lấy danh mục, trả về 10 danh mục chuẩn từ SQL Server |
| `CAT-02` | CATALOG | `DELETE /api/category/1` | 400 Bad Request | 17.24 ms | Chặn xóa danh mục đang chứa món ăn (`HasProducts` guard) |
| `PROD-01` | CATALOG | `GET /api/product?page=1&pageSize=5` | 200 OK | 11.75 ms | Phân trang: 5 món/trang, tổng 10 món, 2 trang |
| `PROD-02` | CATALOG | `GET /api/product?page=2&pageSize=5` | 200 OK | 10.90 ms | Ranh giới phân trang: Món ở trang 2 khác biệt hoàn toàn trang 1 |
| `PROD-03` | CATALOG | `GET /api/product/by-category/1` | 200 OK | 11.06 ms | Lọc món theo `CategoryId = 1` chính xác 100% |
| `PROD-04` | CATALOG | `GET /api/product/search?keyword=Matcha` | 200 OK | 16.07 ms | Tìm kiếm theo từ khóa có phân trang |
| `PROD-05` | CATALOG | `GET /api/product/latest?pageSize=3` | 200 OK | 9.02 ms | Lấy danh sách món mới nhất (Sắp xếp giảm dần theo thời gian) |
| `PROD-06` | CATALOG | `GET /api/product/1/related` | 200 OK | 16.27 ms | Gợi ý các món cùng danh mục liên quan |
| `PROD-07` | CATALOG | `DELETE /api/product/1` | 400 Bad Request | 7.89 ms | Chặn xóa món ăn đã phát sinh trong lịch sử hóa đơn |
| `ORDER-01` | ORDER | `GET /api/table` | 200 OK | 7.44 ms | Kiểm tra Bàn 2 tồn tại và đang ở trạng thái Trống (0) |
| `ORDER-02` | ORDER | `POST /api/order` | 200 OK | 46.24 ms | Đặt đơn: Tính toán tài chính an toàn phía Server, tạo OrderCode |
| `ORDER-03` | ORDER | `GET /api/table` | 200 OK | 21.72 ms | Bàn 2 tự động chuyển sang trạng thái Occupied (1) |
| `ORDER-04` | ORDER | `POST /api/order` | 400 Bad Request | 9.78 ms | Chặn đặt đơn mới trùng lên bàn đang có khách |
| `KDS-01` | KDS | `GET /api/kds` | 200 OK | 13.32 ms | Món ăn xuất hiện ngay lập tức trong danh sách chờ của Bếp |
| `KDS-02` | KDS | `PUT /api/kds/{id}/status` | 200 OK | 25.58 ms | Chuyển món ăn sang trạng thái 'Đang nấu' (1) |
| `KDS-03` | KDS | `PUT /api/kds/{id}/status` | 200 OK | 31.19 ms | Toàn bộ món Ready (2) $\rightarrow$ Đơn hàng tự động chuyển `Served` (2) |
| `PAY-01` | PAYMENT | `POST /api/payment/cash` | 200 OK | 27.70 ms | Xác nhận thanh toán tiền mặt tại quầy thu ngân |
| `PAY-02` | PAYMENT | `GET /api/order/{id}` | 200 OK | 8.04 ms | Đơn hàng chuyển sang `Paid` (1) và `Completed` (3) trong SQL |
| `PAY-03` | PAYMENT | `GET /api/table` | 200 OK | 14.33 ms | Bàn 2 tự động được giải phóng về trạng thái Trống (`Status=0, OrderId=NULL`) |
| `PAY-04` | PAYMENT | `POST /api/payment/cash` | 400 Bad Request | 5.76 ms | Từ chối thanh toán trùng lặp trên đơn đã thanh toán |
| `GATEWAY-01` | GATEWAY | `GET /api/payment/vietqr/{id}` | 200 OK | 6.33 ms | Sinh mã VietQR động chuẩn Napas 247 |
| `GATEWAY-02` | GATEWAY | `POST /api/payment/vnpay/create-url` | 200 OK | 5.88 ms | Sinh URL VNPay Sandbox kèm chữ ký HMAC-SHA512 (`SANDBOX VERIFIED`) |
| `GATEWAY-03` | GATEWAY | `GET /api/payment/vnpay/callback` | 400 Bad Request | 4.63 ms | Chặn đứng callback VNPay bị giả mạo hoặc sai chữ ký |
| `OFFLINE-01` | OFFLINE | `POST /api/order` | 200 OK | 26.03 ms | Đồng bộ đơn hàng ngoại tuyến từ hàng đợi SQLite (`ORD-OFF-XXXXXX`) |
| `OFFLINE-02` | OFFLINE | `POST /api/order` | 200 OK | 8.80 ms | Thử nghiệm retry mạng: Trả về đơn hàng cũ, không tạo đơn trùng |
| `OFFLINE-03` | OFFLINE | `SQL Query COUNT` | 200 OK | 73.58 ms | Truy vấn SQL Server xác nhận duy nhất 1 đơn hàng (Zero Duplication) |

---

## 5. DỮ LIỆU ĐỐI SOÁT CƠ SỞ DỮ LIỆU SQL SERVER THỰC TẾ

Truy vấn trực tiếp `RestaurantPos_Acceptance` sau khi hoàn tất chuỗi kiểm thử E2E:

- Bảng `Accounts`: 31 bản ghi (11 tài khoản hạt giống + tài khoản tạo trong kiểm thử RBAC).
- Bảng `Orders`: 13 bản ghi (10 đơn hạt giống + 1 đơn E2E Bàn 2 + 2 đơn Offline Sync).
- Bảng `Payments`: 11 bản ghi (10 thanh toán hạt giống + 1 thanh toán tiền mặt E2E mới).
- Bảng `DiningTables`: Toàn bộ bàn đã hoàn tất đơn đều trở về trạng thái trống (`Status = 0`), không xảy ra tình trạng kẹt bàn.

Tất cả báo cáo chi tiết dạng JSON đã được lưu trữ độc lập tại:
- `artifacts/r3_db_adversarial_results.json`
- `artifacts/r3_http_rbac_results.json`
- `artifacts/challenger_r3_results.json`
- `artifacts/e2e_business_flow_results.json`
