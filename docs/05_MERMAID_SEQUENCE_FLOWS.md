# HỆ THỐNG MERMAID SEQUENCE FLOWS CHI TIẾT TỪNG CHỨC NĂNG
**Toàn bộ sơ đồ luồng hoạt động tuần tự (Sequence Diagrams) từ Giao diện Mobile $\rightarrow$ SQLite $\rightarrow$ REST API $\rightarrow$ SQL Server**

---

## 1. LUỒNG ĐĂNG KÝ VÀ ĐĂNG NHẬP (AUTH FLOW & SESSION)

```mermaid
sequenceDiagram
    autonumber
    actor User as Người dùng
    participant App as Flutter Mobile
    participant SQLite as SQLite Local DB
    participant API as C# Web API (AuthController)
    participant DB as SQL Server (Accounts)

    Note over User, DB: QUY TRÌNH ĐĂNG KÝ (REGISTER)
    User->>App: Nhập Họ tên, Username, Email, Mật khẩu
    App->>API: POST /api/auth/register (RegisterDto)
    API->>DB: SELECT Id FROM Accounts WHERE Username = @u OR Email = @e
    alt Tài khoản đã tồn tại
        DB-->>API: Trả về bản ghi trùng
        API-->>App: 400 Bad Request ("Tài khoản đã tồn tại")
        App-->>User: Hiển thị thông báo lỗi
    else Tài khoản hợp lệ
        API->>API: Hash mật khẩu (BCrypt / SHA256 + Salt)
        API->>DB: INSERT INTO Accounts (Username, PasswordHash, RoleId=2...)
        DB-->>API: Thành công (New AccountId)
        API-->>App: 200 OK ("Đăng ký thành công")
        App-->>User: Thông báo đăng ký thành công, chuyển sang màn Login
    end

    Note over User, DB: QUY TRÌNH ĐĂNG NHẬP (LOGIN)
    User->>App: Nhập Username & Password
    App->>API: POST /api/auth/login
    API->>DB: SELECT a.*, r.RoleName FROM Accounts a JOIN Roles r ON a.RoleId=r.RoleId WHERE Username=@u
    alt Sai mật khẩu / không tìm thấy
        API-->>App: 401 Unauthorized ("Sai thông tin đăng nhập")
        App-->>User: Báo lỗi trên màn hình
    else Đăng nhập đúng
        API->>API: Tạo Token phiên làm việc
        API-->>App: 200 OK { token, userId, username, fullName, role: "Admin"|"Member" }
        App->>SQLite: INSERT OR REPLACE INTO LocalUserSession (token, userId, role...)
        alt Role == "Admin"
            App-->>User: Điều hướng vào AdminDashboardPage
        else Role == "Member" / "Staff"
            App-->>User: Điều hướng vào PosHomePage (Menu bán hàng)
        end
    end
```

---

## 2. LUỒNG QUẢN LÝ DANH MỤC ADMIN (CATEGORY CRUD & IMAGE HANDLING)

```mermaid
sequenceDiagram
    autonumber
    actor Admin as Quản trị viên
    participant UI as Flutter (CategoryPage)
    participant API as Web API (CategoryController)
    participant FS as Server FileSystem (wwwroot)
    participant DB as SQL Server (Categories & Products)

    Note over Admin, DB: THÊM DANH MỤC CÓ UPLOAD ẢNH
    Admin->>UI: Nhập Tên, Tiêu đề, Mô tả & Chọn file ảnh
    UI->>API: POST /api/category (Multipart FormData: File + Info)
    API->>FS: Helper.SaveImageAsync(file, "categories")
    FS-->>API: Trả về tên file: "cat_48291.png"
    API->>DB: INSERT INTO Categories (CategoryName, Icon="cat_48291.png"...)
    DB-->>API: Thành công
    API-->>UI: 200 OK (New Category)
    UI-->>Admin: Thêm thành công, reload danh sách

    Note over Admin, DB: SỬA DANH MỤC (XỬ LÝ ẢNH MỚI XÓA ẢNH CŨ)
    Admin->>UI: Chọn Danh mục, chọn ảnh mới thay thế
    UI->>API: PUT /api/category/{id} (Thông tin + Ảnh mới)
    API->>DB: SELECT Icon FROM Categories WHERE CategoryId = @id
    DB-->>API: Trả về ảnh cũ: "cat_old.png"
    API->>FS: File.Delete("wwwroot/images/categories/cat_old.png")
    API->>FS: Lưu file mới: "cat_new.png"
    API->>DB: UPDATE Categories SET CategoryName=..., Icon="cat_new.png" WHERE CategoryId=@id
    DB-->>API: Cập nhật thành công
    API-->>UI: 200 OK
    UI-->>Admin: Báo cập nhật thành công

    Note over Admin, DB: XÓA DANH MỤC (KIỂM TRA SẢN PHẨM TỒN TẠI)
    Admin->>UI: Bấm Xóa Danh mục {id}
    UI->>API: DELETE /api/category/{id}
    API->>DB: SELECT COUNT(1) FROM Products WHERE CategoryId = @id
    DB-->>API: Trả về số lượng sản phẩm
    alt Còn sản phẩm trong danh mục
        API-->>UI: 400 Bad Request ("Danh mục đang có sản phẩm, không thể xóa!")
        UI-->>Admin: Hiển thị cảnh báo màu đỏ
    else Không còn sản phẩm
        API->>DB: SELECT Icon FROM Categories WHERE CategoryId = @id
        API->>FS: File.Delete(Icon)
        API->>DB: DELETE FROM Categories WHERE CategoryId = @id
        DB-->>API: Xóa thành công
        API-->>UI: 200 OK ("Đã xóa danh mục và file ảnh")
        UI-->>Admin: Cập nhật giao diện xóa khỏi danh sách
    end
```

---

## 3. LUỒNG QUẢN LÝ SẢN PHẨM & PHÂN TRANG (PRODUCT PAGINATION & CRUD)

```mermaid
sequenceDiagram
    autonumber
    actor Admin as Quản trị viên
    participant UI as Flutter (ProductListPage)
    participant API as Web API (ProductController)
    participant FS as FileSystem (wwwroot/products)
    participant DB as SQL Server (Products & OrderDetails)

    Note over Admin, DB: XEM SẢN PHẨM PHÂN TRANG (PAGINATION)
    UI->>API: GET /api/product?page=1&pageSize=10&categoryId=1
    API->>DB: COUNT(*) & SELECT ... OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY
    DB-->>API: 10 sản phẩm + Tổng số 45 món
    API-->>UI: { totalItems: 45, page: 1, pageSize: 10, totalPages: 5, data: [...] }
    UI-->>Admin: Hiển thị 10 món đầu tiên
    Admin->>UI: Cuộn xuống đáy màn hình (Scroll to bottom)
    UI->>API: GET /api/product?page=2&pageSize=10&categoryId=1
    API->>DB: OFFSET 10 ROWS FETCH NEXT 10 ROWS ONLY
    DB-->>API: 10 sản phẩm tiếp theo
    API-->>UI: Dữ liệu page 2
    UI-->>Admin: Nối tiếp 10 món vào ListView không bị giật lag

    Note over Admin, DB: XÓA SẢN PHẨM (RÀNG BUỘC ĐƠN HÀNG)
    Admin->>UI: Bấm nút Xóa sản phẩm {id}
    UI->>API: DELETE /api/product/{id}
    API->>DB: SELECT TOP 1 1 FROM OrderDetails WHERE ProductId = @id
    DB-->>API: Có tồn tại trong đơn hàng cũ
    alt Đã có trong đơn hàng
        API-->>UI: 400 Bad Request ("Sản phẩm đã có trong hóa đơn, không được xóa!")
        UI-->>Admin: Thông báo từ chối xóa để giữ toàn vẹn dữ liệu kế toán
    else Chưa từng có trong đơn hàng
        API->>FS: File.Delete("wwwroot/images/products/" + ImageUrl)
        API->>DB: DELETE FROM Products WHERE ProductId = @id
        API-->>UI: 200 OK ("Xóa thành công")
        UI-->>Admin: Xóa item khỏi danh sách
    end
```

---

## 4. LUỒNG GIỎ HÀNG OFFLINE VỚI SQLITE & ĐẶT HÀNG (CART & CHECKOUT)

```mermaid
sequenceDiagram
    autonumber
    actor Staff as Nhân viên / Khách
    participant UI as Flutter (Menu & Cart)
    participant SQLite as SQLite Local DB (CartItems)
    participant API as Web API (OrderController)
    participant DB as SQL Server (Orders & Tables)

    Staff->>UI: Bấm "Thêm vào giỏ" trên món Cà phê sữa
    UI->>SQLite: SELECT quantity FROM CartItems WHERE product_id = 2
    alt Đã có trong giỏ
        SQLite->>SQLite: UPDATE CartItems SET quantity = quantity + 1 WHERE product_id = 2
    else Chưa có trong giỏ
        SQLite->>SQLite: INSERT INTO CartItems (product_id, name, price, quantity=1...)
    end
    SQLite-->>UI: Thành công
    UI->>SQLite: SELECT SUM(quantity) FROM CartItems
    SQLite-->>UI: Tổng 3 món
    UI-->>Staff: Cập nhật Badge số 3 đỏ trên icon Giỏ hàng

    Note over Staff, DB: MÀN HÌNH GIỎ HÀNG & CẬP NHẬT
    Staff->>UI: Mở Giỏ hàng
    UI->>SQLite: SELECT * FROM CartItems
    SQLite-->>UI: Danh sách món
    UI-->>Staff: Hiển thị danh sách, nút (+), (-), Xóa
    Staff->>UI: Bấm (+) tăng số lượng món
    UI->>SQLite: UPDATE CartItems SET quantity = quantity + 1 WHERE id = ?
    UI->>UI: Tự động tính lại Tổng tiền giỏ hàng tức thì

    Note over Staff, DB: ĐẶT HÀNG (CHECKOUT)
    Staff->>UI: Chọn Bàn 03, ghi chú "Ít ngọt", bấm "Đặt hàng"
    UI->>SQLite: Đọc toàn bộ CartItems
    UI->>API: POST /api/order { tableId: 3, items: [...], total: 75000 }
    API->>DB: BEGIN TRANSACTION
    API->>DB: INSERT INTO Orders (OrderCode, TableId, TotalAmount, Status=0)
    API->>DB: INSERT INTO OrderDetails (OrderId, ProductId, Quantity, UnitPrice...)
    API->>DB: UPDATE DiningTables SET Status = 1 WHERE TableId = 3 (Có khách)
    API->>DB: COMMIT TRANSACTION
    DB-->>API: Hoàn tất OrderId = 105
    API-->>UI: 200 OK { orderId: 105, orderCode: "ORD-20261004-105" }
    UI->>SQLite: DELETE FROM CartItems (Xóa sạch giỏ hàng)
    UI-->>Staff: Thông báo đặt hàng thành công, hiển thị Chi tiết đơn hàng
```

---

## 5. LUỒNG THANH TOÁN VIETQR VÀ VNPAY (ONLINE PAYMENT FLOW)

```mermaid
sequenceDiagram
    autonumber
    actor Customer as Khách hàng
    actor Staff as Thu ngân
    participant App as Flutter Mobile
    participant API as Web API (PaymentController)
    participant VietQR as Cổng VietQR NAPAS 247
    participant VNPay as Cổng VNPayment Gateway
    participant DB as SQL Server (Payments & Orders)

    Note over Customer, DB: PHƯƠNG THỨC 1: THANH TOÁN QUA MÃ VIETQR ĐỘNG
    Staff->>App: Chọn đơn hàng ORD-105 -> Bấm "Thanh toán VietQR"
    App->>App: Tạo URL VietQR: https://img.vietqr.io/image/MB-0987654321-compact2.png?amount=75000&addInfo=THANH TOAN ORD-105
    App-->>Customer: Hiển thị Dialog mã QR động kèm số tiền 75.000đ
    Customer->>Customer: Mở app ngân hàng (VIB, Vietcombank, Techcombank...) quét mã QR
    Customer->>VietQR: Chuyển tiền thành công
    Staff->>App: Xác nhận "Đã nhận tiền"
    App->>API: POST /api/payment/confirm { orderId: 105, method: "VietQR", amount: 75000 }
    API->>DB: INSERT INTO Payments (OrderId, PaymentMethod, Amount, Status=1)
    API->>DB: UPDATE Orders SET Status = 3 (Hoàn thành) WHERE OrderId = 105
    API->>DB: UPDATE DiningTables SET Status = 0 (Bàn trống) WHERE TableId = 3
    API-->>App: 200 OK
    App-->>Staff: Đơn hàng hoàn tất, bàn đã chuyển sang trạng thái trống

    Note over Customer, DB: PHƯƠNG THỨC 2: THANH TOÁN QUA VNPAY GATEWAY
    Customer->>App: Chọn thanh toán trực tuyến qua VNPay
    App->>API: POST /api/payment/create-vnpay-url { orderId: 105, amount: 75000 }
    API->>API: Ký chữ ký số HMAC-SHA512 với VNPay SecretKey
    API-->>App: Trả về paymentUrl (https://sandbox.vnpayment.vn/paymentv2/...)
    App->>VNPay: Mở Webview chuyển hướng sang cổng VNPay
    Customer->>VNPay: Nhập thẻ ATM / Quét VNPAY-QR
    VNPay->>API: IPN Webhook callback (vnp_ResponseCode = "00" - Thành công)
    API->>DB: Cập nhật Payment và chuyển trạng thái Order = 3
    VNPay-->>App: Redirect returnUrl kèm kết quả thành công
    App-->>Customer: Hiển thị màn hình "Thanh toán thành công"
```

---

## 6. LUỒNG QUẢN LÝ ĐƠN HÀNG DÀNH CHO ADMIN (ADMIN ORDER STATUS & FILTER)

```mermaid
sequenceDiagram
    autonumber
    actor Admin as Admin / Thu ngân
    participant UI as Flutter (AdminOrderListPage)
    participant API as Web API (OrderController)
    participant DB as SQL Server (Orders & Tables)

    Note over Admin, DB: LỌC ĐƠN HÀNG THEO KHOẢNG NGÀY & TÌM KIẾM
    Admin->>UI: Chọn khoảng ngày (01/10/2026 - 04/10/2026) & Nhập "Bàn 03"
    UI->>API: GET /api/order/admin?fromDate=2026-10-01&toDate=2026-10-04&search=Bàn 03
    API->>DB: SELECT o.*, t.TableName FROM Orders o JOIN DiningTables t ON o.TableId=t.TableId WHERE CreatedAt BETWEEN @from AND @to AND (t.TableName LIKE '%Bàn 03%' OR o.OrderCode LIKE '%Bàn 03%')
    DB-->>API: Danh sách đơn hàng + Tổng doanh thu theo bộ lọc
    API-->>UI: { orders: [...], totalRevenue: 15400000 }
    UI-->>Admin: Hiển thị danh sách card đơn hàng và banner doanh thu

    Note over Admin, DB: CẬP NHẬT TRẠNG THÁI ĐƠN HÀNG
    Admin->>UI: Bấm chuyển trạng thái đơn ORD-105: "Đang chế biến" -> "Đã phục vụ"
    UI->>API: PUT /api/order/105/status { status: 2 }
    API->>DB: UPDATE Orders SET Status = 2 WHERE OrderId = 105
    DB-->>API: 1 row affected
    API-->>UI: 200 OK
    UI-->>Admin: Cập nhật màu Badge sang xanh lá ("Đã phục vụ")
```

---

## 7. LUỒNG MÀN HÌNH BẾP (KITCHEN DISPLAY SYSTEM - KDS) & ĐỒNG BỘ OFFLINE

```mermaid
sequenceDiagram
    autonumber
    actor Chef as Đầu bếp / Barista
    actor Staff as Nhân viên phục vụ
    participant WaiterApp as App Nhân viên (Mobile)
    participant KDS as App Bếp (Tablet/Web)
    participant API as Web API (KdsController)
    participant DB as SQL Server (OrderDetails)

    Staff->>WaiterApp: Bấm gửi Order cho Bàn 01 (2 Bạc xỉu, 1 Trà đào)
    WaiterApp->>API: POST /api/order
    API->>DB: Lưu đơn hàng, OrderDetails.CookingStatus = 0 (Chờ chế biến)
    
    KDS->>API: GET /api/kds/active-orders (hoặc SignalR realtime)
    API-->>KDS: Danh sách món mới gửi vào bếp
    KDS-->>Chef: Chuông thông báo "Ting ting" + Thẻ món Bàn 01 màu đỏ (Chờ nấu)
    
    Chef->>KDS: Chạm vào món "Bạc xỉu" -> Bấm "Bắt đầu pha chế"
    KDS->>API: PUT /api/kds/order-detail/201/status { cookingStatus: 1 }
    API->>DB: UPDATE OrderDetails SET CookingStatus = 1
    KDS-->>Chef: Thẻ đổi sang màu cam (Đang pha chế) kèm đồng hồ đếm phút

    Chef->>KDS: Pha chế xong -> Bấm "Hoàn thành món"
    KDS->>API: PUT /api/kds/order-detail/201/status { cookingStatus: 2 }
    API->>DB: UPDATE OrderDetails SET CookingStatus = 2 (Đã xong)
    API-->>WaiterApp: Push Notification: "Món Bàn 01 đã sẵn sàng phục vụ!"
    WaiterApp-->>Staff: Rung chuông báo nhân viên đến quầy bar lấy món mang ra bàn
```
