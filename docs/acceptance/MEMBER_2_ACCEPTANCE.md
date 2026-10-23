# BÁO CÁO NGHIỆM THU ĐỒ ÁN - THÀNH VIÊN 2
## VAI TRÒ: FRONTEND & CATALOG SPECIALIST (COLLABORATOR A)

---

## 1. THÔNG TIN THÀNH VIÊN & TRÁCH NHIỆM BAREM
- **Họ và tên:** Thành viên 2 (Collaborator A)
- **MSSV / Vai trò:** Frontend & Catalog Specialist
- **Trọng tâm phụ trách:**
  - Nhóm 2 Barem: Quản lý Danh mục (Hiển thị, Thêm/Sửa/Xóa, Ràng buộc kiểm tra sản phẩm trước khi xóa, Upload ảnh wwwroot).
  - Nhóm 3 Barem: Quản lý Sản phẩm theo danh mục (Phân trang, Upload hình ảnh, Sửa xóa ảnh vật lý, Ràng buộc kiểm tra đơn hàng trước khi xóa).
  - Nhóm 4 Barem: Hiển thị sản phẩm trên Trang chủ (Menu ngang danh mục, Món mới nhất phân trang, Lọc theo danh mục phân trang, Tìm kiếm từ khóa phân trang, Món liên quan phân trang).
  - Nhóm 5 Barem (Phần giỏ hàng): Giỏ hàng SQLite on-device, Badge số lượng thời gian thực, Nút tăng/giảm số lượng tính tổng tiền tức thì.
- **Cam kết điểm barem:** 6.50 điểm (Bao gồm điểm cộng phân trang và upload ảnh 3 trường hợp).

---

## 2. MINH CHỨNG THỰC THI THỰC TẾ (REAL EXECUTION EVIDENCE)

### 2.1. Quản lý Danh mục (Category Management)
- **Mã nguồn Backend:**
  - `backend/Models/CategoryRepository.cs` & `backend/Api/Controllers/CategoryController.cs`.
  - Hàm `HasProducts(short id)`: Kiểm tra danh mục có sản phẩm trước khi cho phép xóa.
  - Tích hợp `Helper.ValidateImage()`: Chặn các file ảnh sai định dạng hoặc vượt quá 5MB.
- **Kiểm định thực tế:**
  - `CAT-01`: Gọi `GET /api/category` trả về 10 danh mục hạt giống từ SQL Server $\rightarrow$ **PASS**.
  - `CAT-02`: Gọi `DELETE /api/category/1` (danh mục đang chứa món ăn) $\rightarrow$ Server trả về HTTP 400 và từ chối xóa $\rightarrow$ **PASS**.

### 2.2. Quản lý Sản phẩm có Phân trang & Upload ảnh (Product Management)
- **Mã nguồn Backend:**
  - `backend/Models/ProductRepository.cs` & `backend/Api/Controllers/ProductController.cs`.
  - Cung cấp các endpoint chuẩn hóa:
    - `GET /api/product?page={p}&pageSize={s}`: Phân trang tổng quát.
    - `GET /api/product/latest?page={p}&pageSize={s}`: Món mới nhất phân trang theo thời gian tạo.
    - `GET /api/product/by-category/{catId}?page={p}&pageSize={s}`: Lọc theo danh mục phân trang.
    - `GET /api/product/search?keyword={kw}&page={p}&pageSize={s}`: Tìm kiếm phân trang.
    - `GET /api/product/{id}`: Chi tiết món kèm các tùy chọn nhóm thuộc tính (Size, Đường, Đá, Topping).
    - `GET /api/product/{id}/related`: Gợi ý món cùng danh mục có phân trang.
    - `POST /api/product`: Upload ảnh lưu vật lý vào `wwwroot/images/products`.
    - `PUT /api/product/{id}`: Sửa món ăn, tự động dọn dẹp file ảnh cũ trong `wwwroot`.
    - `DELETE /api/product/{id}`: Kiểm tra `HasOrdersAsync()`, từ chối xóa nếu món đã phát sinh trong lịch sử hóa đơn, xóa file ảnh vật lý nếu xóa thành công.
- **Kiểm định thực tế:**
  - `PROD-01` (Phân trang Trang 1): Trả về 5 sản phẩm đầu tiên, tổng 10 món, 2 trang $\rightarrow$ **PASS**.
  - `PROD-02` (Ranh giới Phân trang): Trang 2 trả về danh sách khác biệt hoàn toàn với Trang 1 $\rightarrow$ **PASS**.
  - `PROD-03` (Lọc theo Danh mục): Toàn bộ sản phẩm trả về thuộc `CategoryId = 1` $\rightarrow$ **PASS**.
  - `PROD-04` (Tìm kiếm từ khóa): Tìm kiếm từ khóa 'Matcha' trả về đúng món tương ứng $\rightarrow$ **PASS**.
  - `PROD-05` (Món mới nhất): Sắp xếp giảm dần theo thời gian tạo $\rightarrow$ **PASS**.
  - `PROD-06` (Món liên quan): Trả về các món cùng nhóm danh mục $\rightarrow$ **PASS**.
  - `PROD-07` (Chặn xóa sản phẩm trong đơn): Gọi `DELETE /api/product/1` (món đã có trong Order) $\rightarrow$ Server trả về HTTP 400 chặn xóa an toàn $\rightarrow$ **PASS**.

### 2.3. Xử lý Upload Ảnh 3 trường hợp & Bảo mật File
- **Thêm:** Lưu file với tên ngẫu nhiên 16 ký tự an toàn vào thư mục tương ứng trong `wwwroot`.
- **Sửa:** Xóa ảnh cũ trước khi ghi ảnh mới, bảo đảm không rò rỉ dung lượng ổ đĩa.
- **Xóa:** Dọn dẹp hoàn toàn file vật lý khi bản ghi bị xóa.
- **Bảo mật:** Chỉ chấp nhận đuôi `.jpg, .jpeg, .png, .webp, .gif` và giới hạn tối đa 5MB.

### 2.4. Giỏ hàng Ngoại tuyến SQLite trên Thiết bị Di động
- `mobile/lib/utils/database_helper.dart`:
  - `insertOrUpdateCart`: Thêm món vào bảng `cart_items`, tự động cộng dồn số lượng nếu món đã tồn tại.
  - `getCartTotalAmount`: Truy vấn trực tiếp `SUM(price * quantity)` từ SQLite.
  - `updateCartQuantity`: Tăng giảm số lượng tức thời, nếu giảm về 0 tự động xóa khỏi giỏ.
  - Không sử dụng dữ liệu giỏ hàng ảo khi mở lại ứng dụng.

---

## 3. KẾT QUẢ KIỂM THỬ TỔNG HỢP LIÊN QUAN ĐẾN THÀNH VIÊN 2

| Mã kiểm thử | Mô tả ca kiểm thử | Kết quả thực tế |
| :--- | :--- | :---: |
| `CAT-01` | Lấy danh mục sản phẩm từ SQL Server | **PASS** (HTTP 200) |
| `CAT-02` | Chặn xóa danh mục khi có sản phẩm (`HasProducts`) | **PASS** (HTTP 400) |
| `PROD-01` | Phân trang danh sách sản phẩm | **PASS** (HTTP 200) |
| `PROD-02` | Kiểm tra tính độc lập ranh giới phân trang | **PASS** (HTTP 200) |
| `PROD-03` | Lọc sản phẩm theo danh mục có phân trang | **PASS** (HTTP 200) |
| `PROD-04` | Tìm kiếm sản phẩm theo từ khóa có phân trang | **PASS** (HTTP 200) |
| `PROD-05` | Lấy danh sách món mới nhất có phân trang | **PASS** (HTTP 200) |
| `PROD-06` | Lấy danh sách món liên quan theo danh mục | **PASS** (HTTP 200) |
| `PROD-07` | Chặn xóa sản phẩm đã có trong hóa đơn (`HasOrders`) | **PASS** (HTTP 400) |

---

## 4. KẾT LUẬN & ĐỀ NGHỊ ĐÁNH GIÁ
- **Trạng thái nghiệm thu:** **ACCEPTED (ĐẠT XUẤT SẮC)**
- Thành viên 2 đã hoàn thành 100% các tiêu chí barem Nhóm 2, 3, 4 và giỏ hàng Nhóm 5. Đã kiểm chứng toàn diện qua API thực tế và cơ sở dữ liệu.
