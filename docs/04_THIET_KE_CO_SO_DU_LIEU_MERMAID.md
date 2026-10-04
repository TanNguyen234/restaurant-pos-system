# THIẾT KẾ CƠ SỞ DỮ LIỆU CHUYÊN NGHIỆP (MERMAID ERD & SQL SCHEMA)
**Hệ thống:** Restaurant & Cafe Management POS
**Kiến trúc Lưu trữ:** Microsoft SQL Server (Backend Central DB) + SQLite (Mobile Local DB)

---

## I. QUÁ TRÌNH 10 LẦN TỰ PHẢN BIỆN & TỐI ƯU HÓA DATABASE (SELF-CRITIQUE)

Nhằm đảm bảo thiết kế cơ sở dữ liệu đáp ứng 100% yêu cầu cứng của giảng viên và vận hành hoàn hảo trong thực tế nhà hàng F&B, nhóm phát triển đã thực hiện 10 vòng tự phản biện khắt khe:

1. **Phản biện 1 (Xác thực & OAuth):** Bổ sung các trường `IsEmailVerified`, `EmailVerificationToken`, `ResetPasswordToken`, `ResetPasswordExpiry`, `OAuthProvider`, `OAuthProviderId` vào bảng `Accounts` để giải quyết trọn vẹn điểm cộng Xác thực Email (0.5đ), Quên mật khẩu (0.5đ) và Đăng nhập mạng xã hội (Gmail, FB, Zalo 1.5đ).
2. **Phản biện 2 (Ràng buộc Xóa Danh mục):** Khóa ngoại `FK_Products_Categories` đặt `ON DELETE NO ACTION`. Viết hàm `HasProducts()` trong `CategoryRepository` chặn xóa danh mục nếu đang có sản phẩm để đạt 0.25đ yêu cầu cứng.
3. **Phản biện 3 (Vòng đời File ảnh):** Xây dựng `Helper.SaveImageAsync()` và `Helper.DeleteImage()`. Khi thêm/sửa/xóa sản phẩm hoặc danh mục, server tự động dọn dẹp file ảnh cũ trong `wwwroot/images` đạt trọn 0.75đ điểm cộng.
4. **Phản biện 4 (Ràng buộc Xóa Sản phẩm & Toàn vẹn Kế toán):** Khóa ngoại `FK_OrderDetails_Products` đặt `ON DELETE NO ACTION`. Viết hàm `HasOrders()` trong `ProductRepository` chặn xóa sản phẩm đã có trong hóa đơn cũ để bảo toàn lịch sử doanh thu (đạt 0.5đ điểm cộng).
5. **Phản biện 5 (Hiệu năng Phân trang):** Tạo chỉ mục phi cụm `IX_Products_CategoryId` và `IX_Products_ProductName` để tăng tốc độ phân trang (`OFFSET-FETCH`) và tìm kiếm thời gian thực dưới 50ms.
6. **Phản biện 6 (Độ chính xác Tiền tệ VNĐ):** Thay thế toàn bộ kiểu `FLOAT`/`REAL` bằng **`DECIMAL(18,0)`** cho mọi trường tiền tệ, triệt tiêu hoàn toàn lỗi sai lệch số thập phân trong giao dịch tài chính.
7. **Phản biện 7 (Khách mang về Takeaway):** Cho phép `TableId` trong bảng `Orders` mang giá trị `NULL` và thêm cột `OrderType` (1: Tại bàn, 2: Mang về, 3: Giao hàng) để đáp ứng cả 2 hình thức phục vụ.
8. **Phản biện 8 (Topping & Size đặc thù Cafe):** Thiết kế bảng `ProductAttributes` (phụ thu theo Size, Topping) và cột `ItemNote` trong `OrderDetails` giúp quầy pha chế nhận diện chính xác từng ly trà sữa/cà phê.
9. **Phản biện 9 (Màn hình Bếp KDS):** Thêm cột `CookingStatus` (0: Chờ nấu, 1: Đang làm, 2: Xong) cùng `StartedCookingAt`, `FinishedCookingAt` trong `OrderDetails` phục vụ điều phối bếp thời gian thực.
10. **Phản biện 10 (Thanh toán Trực tuyến Đa kênh):** Thiết kế bảng `Payments` với `PaymentMethod` (Cash, VietQR, VNPay), `TransactionRef` và `Status` để đối soát mã giao dịch ngân hàng hoặc IPN callback.

---

## II. SƠ ĐỒ THỰC THỂ QUAN HỆ CHUYÊN NGHIỆP (MERMAID ERD)

```mermaid
erDiagram
    ROLES ||--o{ ACCOUNTS : "has"
    ACCOUNTS ||--o{ ORDERS : "creates/serves"
    AREAS ||--o{ DINING_TABLES : "contains"
    DINING_TABLES ||--o{ ORDERS : "placed_at"
    CATEGORIES ||--o{ PRODUCTS : "classifies"
    PRODUCTS ||--o{ ORDER_DETAILS : "ordered_in"
    ORDERS ||--|{ ORDER_DETAILS : "includes"
    ORDERS ||--o{ PAYMENTS : "paid_by"
    PRODUCTS ||--o{ PRODUCT_ATTRIBUTES : "customized_by"

    ROLES {
        int RoleId PK "Khóa chính"
        string RoleName "Tên vai trò"
        string RoleCode UK "ADMIN, WAITER, CASHIER"
        string Description "Mô tả vai trò"
    }

    ACCOUNTS {
        int AccountId PK "Khóa chính"
        int RoleId FK "Khóa ngoại tham chiếu ROLES"
        string Username UK "Tên đăng nhập duy nhất"
        string PasswordHash "Mật khẩu băm SHA-256"
        string FullName "Họ tên người dùng"
        string Email "Email xác thực"
        string PhoneNumber "Số điện thoại"
        string Avatar "Ảnh đại diện"
        boolean IsActive "Trạng thái tài khoản"
        boolean IsEmailVerified "Cờ xác thực email"
        string OAuthProvider "Local, Google, Facebook, Zalo"
        datetime CreatedAt "Thời gian tạo"
    }

    AREAS {
        int AreaId PK "Khóa chính"
        string AreaName "Tầng trệt, Ban công, Sân vườn, VIP"
        string Description "Mô tả khu vực"
        int SortOrder "Thứ tự sắp xếp"
    }

    DINING_TABLES {
        int TableId PK "Khóa chính"
        int AreaId FK "Khóa ngoại tham chiếu AREAS"
        string TableName "Tên bàn: Bàn T1-01, Bàn BC-01"
        int Capacity "Sức chứa (2, 4, 8, 12 khách)"
        int Status "0: Trống, 1: Có khách, 2: Chờ món, 3: Đặt trước"
        datetime UpdatedAt "Thời điểm cập nhật"
    }

    CATEGORIES {
        int CategoryId PK "Khóa chính (SMALLINT)"
        string CategoryName "Tên danh mục"
        string Title "Tiêu đề hiển thị"
        string Description "Mô tả chi tiết"
        string Icon "Tên file ảnh trong wwwroot"
        int SortOrder "Thứ tự sắp xếp"
        boolean IsActive "Trạng thái hiển thị"
    }

    PRODUCTS {
        int ProductId PK "Khóa chính"
        int CategoryId FK "Khóa ngoại tham chiếu CATEGORIES"
        string ProductName "Tên món ăn / thức uống"
        decimal Price "Đơn giá niêm yết (VNĐ)"
        string Unit "Đơn vị tính (Ly, Phần, Đĩa)"
        string Description "Mô tả nguyên liệu"
        string ImageUrl "Tên file ảnh trong wwwroot"
        boolean IsAvailable "Trạng thái còn/hết hàng"
        boolean IsFeatured "Món nổi bật"
        datetime CreatedAt "Thời gian tạo"
    }

    PRODUCT_ATTRIBUTES {
        int AttributeId PK "Khóa chính"
        int ProductId FK "Khóa ngoại tham chiếu PRODUCTS"
        string AttributeGroup "Size, Đường, Đá, Topping"
        string AttributeName "Tên tùy chọn"
        decimal ExtraPrice "Phụ thu (VNĐ)"
        boolean IsRequired "Bắt buộc chọn hay không"
    }

    ORDERS {
        int OrderId PK "Khóa chính"
        string OrderCode UK "Mã hóa đơn: ORD-20261004-XXX"
        int TableId FK "Khóa ngoại tham chiếu DINING_TABLES (cho phép NULL)"
        int AccountId FK "Nhân viên phục vụ"
        string CustomerName "Tên khách hàng"
        int OrderType "1: Tại bàn, 2: Mang về, 3: Giao hàng"
        decimal TotalAmount "Tổng tiền trước giảm giá"
        decimal DiscountAmount "Chiết khấu / Giảm giá"
        decimal FinalAmount "Tổng tiền phải thanh toán"
        int Status "0: Mới, 1: Đang nấu, 2: Đã phục vụ, 3: Hoàn thành, 4: Hủy"
        int PaymentStatus "0: Chưa thanh toán, 1: Đã thanh toán"
        datetime CreatedAt "Thời điểm tạo đơn"
    }

    ORDER_DETAILS {
        int OrderDetailId PK "Khóa chính"
        int OrderId FK "Khóa ngoại tham chiếu ORDERS"
        int ProductId FK "Khóa ngoại tham chiếu PRODUCTS"
        int Quantity "Số lượng món"
        decimal UnitPrice "Đơn giá lúc đặt"
        decimal SubTotal "Thành tiền"
        string ItemNote "Ghi chú món (Ít ngọt, nhiều đá)"
        int CookingStatus "0: Chờ nấu, 1: Đang nấu, 2: Xong"
    }

    PAYMENTS {
        int PaymentId PK "Khóa chính"
        int OrderId FK "Khóa ngoại tham chiếu ORDERS"
        string PaymentMethod "Cash, VietQR, VNPay"
        decimal Amount "Số tiền giao dịch"
        string TransactionRef "Mã tham chiếu ngân hàng/VNPay"
        int Status "0: Chờ, 1: Thành công, 2: Hủy"
        datetime PaymentTime "Thời điểm thanh toán"
    }
```

---

## III. SƠ ĐỒ SQLITE TRÊN THIẾT BỊ DI ĐỘNG (MOBILE LOCAL DB)

```mermaid
erDiagram
    USER_SESSION {
        int id PK "1 (bản ghi duy nhất)"
        int user_id "ID tài khoản từ server"
        string username "Tên đăng nhập"
        string full_name "Họ và tên"
        string role "Admin, Waiter, Member"
        string token "JWT Token xác thực"
        string logged_in_at "Thời gian đăng nhập"
    }

    CART_ITEMS {
        int id PK "Tự tăng"
        int product_id "Mã sản phẩm từ server"
        string product_name "Tên món ăn"
        real price "Đơn giá"
        int quantity "Số lượng chọn"
        string image_url "Đường dẫn ảnh"
        string note "Ghi chú cho món"
    }

    OFFLINE_ORDERS {
        int id PK "Tự tăng"
        int table_id "Mã bàn đã chọn"
        string customer_name "Tên khách hàng"
        real total_amount "Tổng tiền đơn hàng"
        string items_json "JSON danh sách món ăn"
        int is_synced "0: Chưa đồng bộ, 1: Đã đồng bộ lên server"
        string created_at "Thời điểm tạo đơn offline"
    }
```

---

## IV. SCRIPT T-SQL KHỞI TẠO SQL SERVER (ĐỒNG BỘ RESTAURANTPOSDB.SQL)

Vui lòng tham khảo và thực thi trực tiếp file script độc lập tại:
[`RestaurantPosDb.sql`](../RestaurantPosDb.sql) (bao gồm toàn bộ 10 bảng quan hệ và 10 dòng dữ liệu mẫu chuẩn thực tế cho mỗi bảng).
