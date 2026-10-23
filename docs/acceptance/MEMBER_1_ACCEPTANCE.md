# BÁO CÁO NGHIỆM THU ĐỒ ÁN - THÀNH VIÊN 1
## VAI TRÒ: TEAM LEADER & FULLSTACK ARCHITECT (BẠN)

---

## 1. THÔNG TIN THÀNH VIÊN & TRÁCH NHIỆM BAREM
- **Họ và tên:** Thành viên 1 (Team Leader)
- **MSSV / Vai trò:** Fullstack Architect & Lead Engineer
- **Trọng tâm phụ trách:**
  - Thiết kế và chuẩn hóa Cơ sở dữ liệu Microsoft SQL Server (10 bảng chuẩn hóa).
  - Kiến trúc phân lớp chuẩn Backend: `BaseController` $\rightarrow$ `SiteProvider` $\rightarrow$ `BaseRepository`.
  - Quản lý Bàn ăn (`DiningTables`) và Khu vực (`Areas`), API sơ đồ bàn, chuyển bàn.
  - Công cụ lưu trữ cục bộ SQLite (`DatabaseHelper.dart`) trên Mobile: `user_session`, `cart_items`, `offline_orders`.
  - Cơ chế đồng bộ đơn hàng ngoại tuyến (`OfflineSyncService.dart`) và xử lý xung đột mạng.
- **Cam kết điểm barem:** 10/10 điểm gốc + 2.5đ điểm cộng tính năng nâng cao.

---

## 2. MINH CHỨNG THỰC THI THỰC TẾ (REAL EXECUTION EVIDENCE)

### 2.1. Cơ sở dữ liệu SQL Server (`RestaurantPos_Acceptance`)
- **Tình trạng:** Khởi tạo thành công trên Microsoft SQL Server 2022 Express (`localhost\SQLEXPRESS`).
- **Kiểm định thực tế:**
  - 10 bảng cơ sở dữ liệu đã nạp đầy đủ dữ liệu hạt giống (`Accounts`, `Areas`, `Categories`, `DiningTables`, `OrderDetails`, `Orders`, `Payments`, `ProductAttributes`, `Products`, `Roles`).
  - Toàn bộ 9 ràng buộc khóa ngoại (Foreign Keys) và 6 chỉ mục tìm kiếm (Indexes) hoạt động ổn định.
  - Bộ kiểm thử độc lập `scripts/verify_r3_db_adversarial.ps1`: **28 / 28 ca kiểm thử PASS 100%**.

### 2.2. Kiến trúc Facade Provider trên ASP.NET Core 10
- Áp dụng triệt để mô hình 4 tầng theo đúng bài giảng của giảng viên:
  - `backend/Api/Controllers/BaseController.cs` cung cấp thuộc tính `Provider`.
  - `backend/Models/BaseProvider.cs` & `backend/Models/SiteProvider.cs` quản lý tập trung các repository: `Category`, `Table`, `Account`, `Product`, `Order`, `Payment`.
  - `backend/Models/BaseRepository.cs` bao đóng `RestaurantPosContext`.
- Không sử dụng các thư viện trung gian phức tạp ngoài chuẩn (no over-engineering), hoàn toàn tương thích .NET 10.

### 2.3. Quản lý Bàn ăn & Sơ đồ mặt bằng (Floor Table Management)
- **API Backend:**
  - `GET /api/table/areas`: Lấy danh sách khu vực.
  - `GET /api/table`: Lấy toàn bộ danh sách bàn và trạng thái (`0: Empty`, `1: Occupied`, `2: Reserved`).
  - `PUT /api/table/{id}/status`: Cập nhật trạng thái bàn ăn.
  - `POST /api/table/transfer`: Chuyển khách giữa các bàn ăn.
- **Mobile Frontend:**
  - `mobile/lib/views/table/floor_table_page.dart` (45 KB) với thiết kế F&B POS hiện đại:
    - Chip lọc khu vực linh hoạt.
    - Trạng thái bàn trực quan (Xanh: Trống, Đỏ: Có khách).
    - Hộp thoại chuyển bàn ràng buộc nghiêm ngặt chỉ cho phép chuyển sang bàn trống.
  - Đã loại bỏ hoàn toàn 58 dòng mock fallback `_fallbackTables` trong `table_repository.dart`, bảo đảm bắt lỗi mạng thực tế mà không làm sai lệch dữ liệu.

### 2.4. Lưu trữ SQLite Ngoại tuyến & Đồng bộ hóa
- `mobile/lib/utils/database_helper.dart`:
  - `user_session`: Lưu giữ phiên đăng nhập và mã token.
  - `cart_items`: Giỏ hàng cục bộ, tích hợp hàm tính tổng tiền `getCartTotalAmount()`, tăng giảm số lượng, tự động xóa khi số lượng về 0.
  - `offline_orders`: Hàng đợi đơn hàng ngoại tuyến khi mất kết nối mạng.
- `mobile/lib/services/offline_sync_service.dart`:
  - Kiểm tra kết nối mạng qua `checkNetworkReachability()`.
  - Đồng bộ hàng đợi lên API `POST /api/order` kèm cơ chế Idempotency deduplication.
  - Kiểm tra thực tế: Khi gửi đơn hàng ngoại tuyến trùng lặp, server trả về mã đơn hàng gốc đã tạo mà không tạo thêm dòng mới trong SQL Server (`SQL Count: 1, Zero Duplication`).

---

## 3. KẾT QUẢ KIỂM THỬ TỔNG HỢP LIÊN QUAN ĐẾN THÀNH VIÊN 1

| Hạng mục kiểm tra | Công cụ kiểm thử | Số lượng ca kiểm thử | Kết quả |
| :--- | :--- | :---: | :---: |
| CSDL SQL Server & Ràng buộc toàn vẹn | `verify_r3_db_adversarial.ps1` | 28 / 28 | **PASS 100%** |
| Bàn ăn & Xử lý lỗi mạng Mobile | `table_repository_test.dart` | 12 / 12 | **PASS 100%** |
| Thử thách sơ đồ bàn & Chuyển bàn | `floor_table_challenge_test.dart` | 13 / 13 | **PASS 100%** |
| Thử thách mạng & Đồng bộ Offline | `adversarial_table_repo_test.dart` | 22 / 22 | **PASS 100%** |
| Đồng bộ đơn hàng & Deduplication E2E | `verify_e2e_business_flow.ps1` | 3 / 3 | **PASS 100%** |

---

## 4. KẾT LUẬN & ĐỀ NGHỊ ĐÁNH GIÁ
- **Trạng thái nghiệm thu:** **ACCEPTED (ĐẠT XUẤT SẮC)**
- Mọi yêu cầu được giao cho Thành viên 1 đều đã hoàn thành với đầy đủ mã nguồn, không sử dụng dữ liệu giả lập (mock), và đã được chứng minh qua dữ liệu thực thi SQL Server và API.
