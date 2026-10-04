-- ======================================================================================
-- DỰ ÁN: HỆ THỐNG QUẢN LÝ NHÀ HÀNG & QUÁN CÀ PHÊ (RESTAURANT & CAFE POS SYSTEM)
-- CÔNG NGHỆ: C# ASP.NET Core 10 Web API + Microsoft SQL Server + Flutter Mobile (SQLite)
-- TÁC GIẢ: Nhóm Phát Triển Restaurant POS
-- MỤC ĐÍCH: Khởi tạo Database hoàn chỉnh, chuẩn hóa quan hệ PK/FK, Index và nạp 10 dòng/bảng.
-- ======================================================================================

USE master;
GO

-- 1. TẠO CƠ SỞ DỮ LIỆU
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'RestaurantPosDb')
BEGIN
    CREATE DATABASE RestaurantPosDb;
END
GO

USE RestaurantPosDb;
GO

-- XÓA BẢNG CŨ THEO THỨ TỰ PHỤ THUỘC (NẾU ĐÃ TỒN TẠI)
IF OBJECT_ID('Payments', 'U') IS NOT NULL DROP TABLE Payments;
IF OBJECT_ID('OrderDetailModifiers', 'U') IS NOT NULL DROP TABLE OrderDetailModifiers;
IF OBJECT_ID('OrderDetails', 'U') IS NOT NULL DROP TABLE OrderDetails;
IF OBJECT_ID('Orders', 'U') IS NOT NULL DROP TABLE Orders;
IF OBJECT_ID('ProductAttributes', 'U') IS NOT NULL DROP TABLE ProductAttributes;
IF OBJECT_ID('Products', 'U') IS NOT NULL DROP TABLE Products;
IF OBJECT_ID('Categories', 'U') IS NOT NULL DROP TABLE Categories;
IF OBJECT_ID('DiningTables', 'U') IS NOT NULL DROP TABLE DiningTables;
IF OBJECT_ID('Areas', 'U') IS NOT NULL DROP TABLE Areas;
IF OBJECT_ID('Accounts', 'U') IS NOT NULL DROP TABLE Accounts;
IF OBJECT_ID('Roles', 'U') IS NOT NULL DROP TABLE Roles;
GO

-- ======================================================================================
-- II. DDL: KHỞI TẠO CẤU TRÚC 10 BẢNG QUAN HỆ CHUYÊN NGHIỆP
-- ======================================================================================

-- 1. BẢNG VAI TRÒ NGƯỜI DÙNG (ROLES)
CREATE TABLE Roles (
    RoleId INT IDENTITY(1,1) PRIMARY KEY,
    RoleName NVARCHAR(64) NOT NULL UNIQUE,
    RoleCode VARCHAR(32) NOT NULL UNIQUE,
    Description NVARCHAR(256) NULL,
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE()
);
GO

-- 2. BẢNG TÀI KHOẢN NGƯỜI DÙNG & XÁC THỰC (ACCOUNTS)
CREATE TABLE Accounts (
    AccountId INT IDENTITY(1,1) PRIMARY KEY,
    RoleId INT NOT NULL CONSTRAINT FK_Accounts_Roles REFERENCES Roles(RoleId),
    Username VARCHAR(64) NOT NULL UNIQUE,
    PasswordHash VARCHAR(256) NOT NULL,
    FullName NVARCHAR(128) NOT NULL,
    Email VARCHAR(128) NULL,
    PhoneNumber VARCHAR(20) NULL,
    Avatar NVARCHAR(256) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    IsEmailVerified BIT NOT NULL DEFAULT 0,
    EmailVerificationToken VARCHAR(128) NULL,
    ResetPasswordToken VARCHAR(128) NULL,
    ResetPasswordExpiry DATETIME NULL,
    OAuthProvider VARCHAR(32) NULL, -- Local, Google, Facebook, Zalo
    OAuthProviderId VARCHAR(128) NULL,
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),
    UpdatedAt DATETIME NULL
);
GO

-- 3. BẢNG KHU VỰC TRONG NHÀ HÀNG / QUÁN (AREAS)
CREATE TABLE Areas (
    AreaId INT IDENTITY(1,1) PRIMARY KEY,
    AreaName NVARCHAR(64) NOT NULL,
    Description NVARCHAR(256) NULL,
    SortOrder INT NOT NULL DEFAULT 0,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE()
);
GO

-- 4. BẢNG BÀN ĂN & TRẠNG THÁI (DINING_TABLES)
CREATE TABLE DiningTables (
    TableId INT IDENTITY(1,1) PRIMARY KEY,
    AreaId INT NOT NULL CONSTRAINT FK_Tables_Areas REFERENCES Areas(AreaId),
    TableName NVARCHAR(64) NOT NULL,
    Capacity INT NOT NULL DEFAULT 4,
    Status INT NOT NULL DEFAULT 0, -- 0: Trống (Green), 1: Có khách (Red), 2: Chờ phục vụ (Orange), 3: Đặt trước (Blue)
    CurrentOrderId INT NULL,
    UpdatedAt DATETIME NOT NULL DEFAULT GETDATE()
);
GO

-- 5. BẢNG DANH MỤC SẢN PHẨM (CATEGORIES)
CREATE TABLE Categories (
    CategoryId SMALLINT IDENTITY(1,1) PRIMARY KEY,
    CategoryName NVARCHAR(64) NOT NULL,
    Title NVARCHAR(128) NOT NULL,
    Description NVARCHAR(512) NOT NULL,
    Icon NVARCHAR(256) NOT NULL,
    SortOrder INT NOT NULL DEFAULT 0,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),
    UpdatedAt DATETIME NULL
);
GO

-- 6. BẢNG SẢN PHẨM / THỰC ĐƠN (PRODUCTS)
CREATE TABLE Products (
    ProductId INT IDENTITY(1,1) PRIMARY KEY,
    CategoryId SMALLINT NOT NULL CONSTRAINT FK_Products_Categories REFERENCES Categories(CategoryId),
    ProductName NVARCHAR(128) NOT NULL,
    Price DECIMAL(18,0) NOT NULL, -- Giá tiền VNĐ
    Unit NVARCHAR(32) NOT NULL DEFAULT N'Ly',
    Description NVARCHAR(1024) NULL,
    ImageUrl NVARCHAR(256) NOT NULL,
    IsAvailable BIT NOT NULL DEFAULT 1,
    IsFeatured BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),
    UpdatedAt DATETIME NULL
);
GO

-- 7. BẢNG THUỘC TÍNH SẢN PHẨM / TOPPING / SIZE (PRODUCT_ATTRIBUTES)
CREATE TABLE ProductAttributes (
    AttributeId INT IDENTITY(1,1) PRIMARY KEY,
    ProductId INT NOT NULL CONSTRAINT FK_Attributes_Products REFERENCES Products(ProductId) ON DELETE CASCADE,
    AttributeGroup NVARCHAR(64) NOT NULL, -- 'Size', 'Đường', 'Đá', 'Topping'
    AttributeName NVARCHAR(64) NOT NULL,
    ExtraPrice DECIMAL(18,0) NOT NULL DEFAULT 0,
    IsRequired BIT NOT NULL DEFAULT 0
);
GO

-- 8. BẢNG ĐƠN HÀNG / HÓA ĐƠN (ORDERS)
CREATE TABLE Orders (
    OrderId INT IDENTITY(1,1) PRIMARY KEY,
    OrderCode VARCHAR(32) NOT NULL UNIQUE,
    TableId INT NULL CONSTRAINT FK_Orders_Tables REFERENCES DiningTables(TableId),
    AccountId INT NULL CONSTRAINT FK_Orders_Accounts REFERENCES Accounts(AccountId),
    CustomerName NVARCHAR(128) NULL,
    PhoneNumber VARCHAR(20) NULL,
    OrderType INT NOT NULL DEFAULT 1, -- 1: Tại bàn (DineIn), 2: Mang về (Takeaway), 3: Giao hàng (Delivery)
    Note NVARCHAR(512) NULL,
    TotalAmount DECIMAL(18,0) NOT NULL DEFAULT 0,
    DiscountAmount DECIMAL(18,0) NOT NULL DEFAULT 0,
    FinalAmount DECIMAL(18,0) NOT NULL DEFAULT 0,
    Status INT NOT NULL DEFAULT 0, -- 0: Mới, 1: Đang chế biến, 2: Đã phục vụ, 3: Hoàn thành & Thu tiền, 4: Hủy
    PaymentStatus INT NOT NULL DEFAULT 0, -- 0: Chưa thanh toán, 1: Đã thanh toán
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),
    CompletedAt DATETIME NULL
);
GO

-- 9. BẢNG CHI TIẾT ĐƠN HÀNG (ORDER_DETAILS - KITCHEN DISPLAY KDS READY)
CREATE TABLE OrderDetails (
    OrderDetailId INT IDENTITY(1,1) PRIMARY KEY,
    OrderId INT NOT NULL CONSTRAINT FK_OrderDetails_Orders REFERENCES Orders(OrderId) ON DELETE CASCADE,
    ProductId INT NOT NULL CONSTRAINT FK_OrderDetails_Products REFERENCES Products(ProductId),
    Quantity INT NOT NULL DEFAULT 1,
    UnitPrice DECIMAL(18,0) NOT NULL,
    SubTotal DECIMAL(18,0) NOT NULL,
    ItemNote NVARCHAR(256) NULL, -- Ví dụ: "50% đường, không đá, nhiều thạch"
    CookingStatus INT NOT NULL DEFAULT 0, -- 0: Chờ nấu (Pending), 1: Đang làm (Cooking), 2: Đã nấu xong (Ready)
    StartedCookingAt DATETIME NULL,
    FinishedCookingAt DATETIME NULL
);
GO

-- 10. BẢNG GIAO DỊCH THANH TOÁN (PAYMENTS - TIỀN MẶT, VIETQR, VNPAY)
CREATE TABLE Payments (
    PaymentId INT IDENTITY(1,1) PRIMARY KEY,
    OrderId INT NOT NULL CONSTRAINT FK_Payments_Orders REFERENCES Orders(OrderId),
    PaymentMethod VARCHAR(32) NOT NULL, -- 'Cash', 'VietQR', 'VNPay'
    Amount DECIMAL(18,0) NOT NULL,
    TransactionRef VARCHAR(128) NULL, -- Mã giao dịch ngân hàng / vnp_TxnRef
    Status INT NOT NULL DEFAULT 1, -- 0: Đang chờ, 1: Thành công, 2: Thất bại / Hủy
    Note NVARCHAR(256) NULL,
    PaymentTime DATETIME NOT NULL DEFAULT GETDATE()
);
GO

-- TẠO CHỈ MỤC TỐI ƯU HIỆU NĂNG TÌM KIẾM VÀ PHÂN TRANG (INDEXES)
CREATE NONCLUSTERED INDEX IX_Products_CategoryId ON Products(CategoryId);
CREATE NONCLUSTERED INDEX IX_Products_ProductName ON Products(ProductName);
CREATE NONCLUSTERED INDEX IX_Orders_OrderCode ON Orders(OrderCode);
CREATE NONCLUSTERED INDEX IX_Orders_CreatedAt ON Orders(CreatedAt);
CREATE NONCLUSTERED INDEX IX_OrderDetails_OrderId ON OrderDetails(OrderId);
CREATE NONCLUSTERED INDEX IX_DiningTables_AreaId ON DiningTables(AreaId);
GO

-- ======================================================================================
-- III. DML: CHÈN DỮ LIỆU MẪU CHUẨN THỰC TẾ (MỖI BẢNG ĐÚNG 10 DÒNG)
-- ======================================================================================

-- 1. CHÈN 10 VAI TRÒ (ROLES)
SET IDENTITY_INSERT Roles ON;
INSERT INTO Roles (RoleId, RoleName, RoleCode, Description) VALUES
(1, N'Quản trị viên hệ thống', 'ADMIN', N'Toàn quyền quản trị danh mục, sản phẩm, nhân sự và báo cáo doanh thu'),
(2, N'Quản lý chi nhánh', 'MANAGER', N'Quản lý hoạt động nhà hàng, phân ca và xử lý sự cố'),
(3, N'Thu ngân', 'CASHIER', N'Tính tiền, in hóa đơn, xác nhận thanh toán VietQR và VNPay'),
(4, N'Nhân viên phục vụ', 'WAITER', N'Mở bàn, chọn món trên điện thoại di động, chuyển order vào bếp'),
(5, N'Trưởng quầy pha chế', 'BARISTA_LEAD', N'Quản lý nguyên liệu và phụ trách các món cà phê, trà'),
(6, N'Đầu bếp chính', 'HEAD_CHEF', N'Nhận order từ màn hình KDS, nấu món ăn chính và điểm tâm'),
(7, N'Phụ bếp', 'COOK_ASSISTANT', N'Sơ chế nguyên liệu và hỗ trợ ra món'),
(8, N'Khách hàng thân thiết', 'MEMBER', N'Khách hàng tích điểm thưởng khi mua sắm'),
(9, N'Khách hàng VIP', 'VIP_MEMBER', N'Khách hàng hạng vàng với mức ưu đãi chiết khấu 10%'),
(10, N'Tài khoản đối tác / Giao hàng', 'DELIVERY_PARTNER', N'Nhận thông tin đơn hàng mang về và giao tận nơi');
SET IDENTITY_INSERT Roles OFF;
GO

-- 2. CHÈN 10 TÀI KHOẢN (ACCOUNTS)
SET IDENTITY_INSERT Accounts ON;
INSERT INTO Accounts (AccountId, RoleId, Username, PasswordHash, FullName, Email, PhoneNumber, Avatar, IsActive, IsEmailVerified, OAuthProvider) VALUES
(1, 1, 'admin', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', N'Nguyễn Văn Quản Trị', 'admin@restaurantpos.vn', '0901234567', 'admin_avatar.png', 1, 1, 'Local'),
(2, 2, 'manager01', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', N'Trần Thị Thu Quản Lý', 'manager01@restaurantpos.vn', '0902345678', 'manager_avatar.png', 1, 1, 'Local'),
(3, 3, 'cashier_mai', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', N'Lê Tuyết Mai', 'mai.cashier@restaurantpos.vn', '0903456789', 'mai_avatar.png', 1, 1, 'Local'),
(4, 4, 'waiter_nam', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', N'Phạm Hoàng Nam', 'nam.waiter@restaurantpos.vn', '0904567890', 'nam_avatar.png', 1, 1, 'Local'),
(5, 4, 'waiter_lan', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', N'Đỗ Ngọc Lan', 'lan.waiter@restaurantpos.vn', '0905678901', 'lan_avatar.png', 1, 1, 'Local'),
(6, 5, 'barista_tuan', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', N'Vũ Anh Tuấn', 'tuan.barista@restaurantpos.vn', '0906789012', 'tuan_avatar.png', 1, 1, 'Local'),
(7, 6, 'chef_dung', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', N'Ngô Tiến Dũng', 'dung.chef@restaurantpos.vn', '0907890123', 'chef_avatar.png', 1, 1, 'Local'),
(8, 8, 'member_khang', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', N'Bùi Vĩnh Khang', 'khang.bui@gmail.com', '0908901234', 'khang_avatar.png', 1, 1, 'Google'),
(9, 9, 'vip_huong', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', N'Đặng Thu Hương', 'huong.dang@fpt.com', '0909012345', 'huong_avatar.png', 1, 1, 'Zalo'),
(10, 8, 'member_linh', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', N'Võ Diệu Linh', 'linh.vo@outlook.com', '0910123456', 'linh_avatar.png', 1, 0, 'Facebook');
SET IDENTITY_INSERT Accounts OFF;
GO

-- 3. CHÈN 10 KHU VỰC (AREAS)
SET IDENTITY_INSERT Areas ON;
INSERT INTO Areas (AreaId, AreaName, Description, SortOrder, IsActive) VALUES
(1, N'Tầng trệt - Máy lạnh trong nhà', N'Không gian mát mẻ, yên tĩnh phù hợp làm việc và gặp gỡ bạn bè', 1, 1),
(2, N'Tầng 1 - Ban công ngắm phố', N'Khu vực ngoài trời thoáng đãng nhìn ra mặt tiền đường chính', 2, 1),
(3, N'Khu vườn nhiệt đới (Garden)', N'Không gian xanh nhiều cây cảnh, giếng trời mát mẻ tự nhiên', 3, 1),
(4, N'Phòng VIP 01 - Hoàng Gia', N'Phòng máy lạnh riêng biệt cách âm, sức chứa 10-12 người cho họp gia đình', 4, 1),
(5, N'Phòng VIP 02 - Doanh nhân', N'Trang bị màn hình TV trình chiếu, bàn dài họp nhóm và ký kết', 5, 1),
(6, N'Quầy Bar trung tâm', N'Ghế cao quầy bar dành cho khách thưởng thức pha chế trực tiếp', 6, 1),
(7, N'Sân thượng Rooftop', N'Gió mát buổi tối, tầm nhìn toàn cảnh thành phố lung linh ánh đèn', 7, 1),
(8, N'Khu vực đọc sách & Làm việc', N'Trang bị nhiều ổ cắm điện, ánh sáng vàng dịu nhẹ, yên tĩnh tuyệt đối', 8, 1),
(9, N'Hiên trước quán (Pavement)', N'Bàn ghế nhỏ ngồi ngắm bình minh buổi sáng nhâm nhi cà phê phin', 9, 1),
(10, N'Khu vực đón tiếp & Chờ món', N'Sảnh chờ ghế nệm êm ái cho khách mua mang về hoặc đợi xếp bàn', 10, 1);
SET IDENTITY_INSERT Areas OFF;
GO

-- 4. CHÈN 10 BÀN ĂN (DINING_TABLES)
SET IDENTITY_INSERT DiningTables ON;
INSERT INTO DiningTables (TableId, AreaId, TableName, Capacity, Status) VALUES
(1, 1, N'Bàn T1-01', 4, 1), -- Đang có khách
(2, 1, N'Bàn T1-02', 2, 0), -- Trống
(3, 1, N'Bàn T1-03', 4, 0), -- Trống
(4, 2, N'Bàn BC-01', 4, 1), -- Đang có khách
(5, 2, N'Bàn BC-02', 6, 2), -- Chờ phục vụ
(6, 3, N'Bàn GV-01', 8, 0), -- Trống
(7, 3, N'Bàn GV-02', 4, 0), -- Trống
(8, 4, N'Phòng VIP-01', 12, 1), -- Đang có khách
(9, 5, N'Phòng VIP-02', 10, 3), -- Đã đặt trước
(10, 7, N'Bàn RT-01', 4, 0); -- Trống
SET IDENTITY_INSERT DiningTables OFF;
GO

-- 5. CHÈN 10 DANH MỤC SẢN PHẨM (CATEGORIES)
SET IDENTITY_INSERT Categories ON;
INSERT INTO Categories (CategoryId, CategoryName, Title, Description, Icon, SortOrder, IsActive) VALUES
(1, N'Cà phê truyền thống', N'Cà phê phin Robusta Đắk Lắk', N'Đậm đà hương vị nguyên bản cà phê rang mộc Tây Nguyên', 'traditional_coffee.png', 1, 1),
(2, N'Cà phê pha máy (Espresso)', N'Espresso, Latte, Cappuccino & Americano', N'Hạt Arabica Cầu Đất phối trộn chuẩn vị Ý thơm ngát', 'espresso_coffee.png', 2, 1),
(3, N'Trà trái cây tươi', N'Trà đào, trà vải, trà dâu nhiệt đới', N'Trà tươi ủ mộc kết hợp cùng trái cây tươi thanh mát bổ dưỡng', 'fruit_tea.png', 3, 1),
(4, N'Trà sữa đặc biệt', N'Trà sữa ô long nướng & hồng trà trân châu', N'Trà ô long thơm đậm kết hợp sữa tươi thanh trùng và trân châu thủ công', 'milk_tea.png', 4, 1),
(5, N'Đá xay & Sinh tố (Ice Blended)', N'Matcha, socola & sinh tố trái cây nhiệt đới', N'Mát lạnh sảng khoái với lớp whipping cream béo ngậy', 'ice_blended.png', 5, 1),
(6, N'Bánh ngọt & Tráng miệng', N'Tiramisu, Cheesecake, Mousse & Croissant', N'Bánh nướng thủ công thơm lừng mỗi sáng từ bơ Pháp cao cấp', 'bakery_dessert.png', 6, 1),
(7, N'Điểm tâm sáng', N'Bánh mì chảo, phở bò, hủ tiếu & xôi mặn', N'Bữa sáng tràn đầy năng lượng nóng hổi và thơm ngon', 'breakfast.png', 7, 1),
(8, N'Món ăn vặt', N'Khoai tây chiên, gà rán giòn & xúc xích nướng', N'Món nhâm nhi giòn rụm cho các buổi trò chuyện xôm tụ', 'snacks.png', 8, 1),
(9, N'Nước ép tươi nguyên chất', N'Nước ép cam, cà rốt, táo & dưa hấu', N'100% nguyên chất không thêm đường, dồi dào vitamin', 'fresh_juice.png', 9, 1),
(10, N'Mocktail & Soda sủi bọt', N'Mojito chanh bạc hà, soda việt quất', N'Thức uống giải nhiệt có ga sảng khoái, màu sắc bắt mắt', 'mocktail_soda.png', 10, 1);
SET IDENTITY_INSERT Categories OFF;
GO

-- 6. CHÈN 10 SẢN PHẨM TIÊU BIỂU (PRODUCTS)
SET IDENTITY_INSERT Products ON;
INSERT INTO Products (ProductId, CategoryId, ProductName, Price, Unit, Description, ImageUrl, IsAvailable, IsFeatured) VALUES
(1, 1, N'Cà phê đen đá Đắk Lắk', 25000, N'Ly', N'Hạt Robusta nguyên chất pha phin truyền thống đậm vị đắng thanh', 'cafe_den_da.jpg', 1, 1),
(2, 1, N'Cà phê sữa đá Sài Gòn', 29000, N'Ly', N'Hòa quyện đắng đậm và sữa đặc béo ngậy chuẩn vị Sài Gòn xưa', 'cafe_sua_da.jpg', 1, 1),
(3, 1, N'Bạc xỉu 3 tầng bồng bềnh', 35000, N'Ly', N'Nhiều sữa đặc, sữa tươi thanh trùng và lớp bọt cà phê thơm dịu', 'bac_xiu_3tang.jpg', 1, 1),
(4, 2, N'Cà phê Muối Cố Đô', 39000, N'Ly', N'Lớp kem muối béo mặn nhẹ hòa quyện cà phê phin đậm đà', 'cafe_muoi.jpg', 1, 1),
(5, 3, N'Trà đào cam sả thanh nhiệt', 42000, N'Ly', N'Đào ngâm giòn ngọt, cam vàng tươi mọng và hương thơm từ sả tươi', 'tra_dao_cam_sa.jpg', 1, 1),
(6, 4, N'Trà sữa Ô long nướng Trân châu', 48000, N'Ly', N'Vị trà nướng đậm đà đặc trưng kèm trân châu hoàng kim dẻo dai', 'trasua_olong_nuong.jpg', 1, 1),
(7, 5, N'Matcha đá xay kem tuyết', 52000, N'Ly', N'Bột trà xanh Uji Nhật Bản xay cùng sữa và kem béo ngậy', 'matcha_daxay.jpg', 1, 0),
(8, 6, N'Bánh Tiramisu phô mai Ý', 45000, N'Phần', N'Lớp bánh xốp ngấm đẫm cà phê rượu nhẹ và phô mai Mascarpone', 'banh_tiramisu.jpg', 1, 1),
(9, 7, N'Bánh mì chảo đặc biệt', 55000, N'Chảo', N'Pate gan thơm béo, trứng ốp la lòng đào, xúc xích và thịt bò mềm', 'banhmi_chao.jpg', 1, 1),
(10, 8, N'Khoai tây chiên phô mai lắc', 35000, N'Đĩa', N'Khoai tây sợi vàng ươm giòn rụm phủ lớp bột phô mai béo mặn', 'khoaitay_phomai.jpg', 1, 0);
SET IDENTITY_INSERT Products OFF;
GO

-- 7. CHÈN 10 THUỘC TÍNH SẢN PHẨM / TOPPING / SIZE (PRODUCT_ATTRIBUTES)
SET IDENTITY_INSERT ProductAttributes ON;
INSERT INTO ProductAttributes (AttributeId, ProductId, AttributeGroup, AttributeName, ExtraPrice, IsRequired) VALUES
(1, 2, 'Size', N'Size Vừa (Medium)', 0, 1),
(2, 2, 'Size', N'Size Lớn (Large)', 8000, 1),
(3, 5, 'Topping', N'Thêm miếng đào giòn', 10000, 0),
(4, 5, 'Đường', N'Giảm 50% đường', 0, 0),
(5, 5, 'Đá', N'Ít đá (30% đá)', 0, 0),
(6, 6, 'Topping', N'Thêm trân châu hoàng kim', 10000, 0),
(7, 6, 'Topping', N'Thêm lớp kem cheese macchiato', 12000, 0),
(8, 7, 'Topping', N'Thêm thạch dừa giòn', 8000, 0),
(9, 9, 'Topping', N'Thêm xúc xích nướng', 15000, 0),
(10, 9, 'Topping', N'Thêm viên pate gan lớn', 12000, 0);
SET IDENTITY_INSERT ProductAttributes OFF;
GO

-- 8. CHÈN 10 ĐƠN HÀNG MẪU (ORDERS)
SET IDENTITY_INSERT Orders ON;
INSERT INTO Orders (OrderId, OrderCode, TableId, AccountId, CustomerName, PhoneNumber, OrderType, Note, TotalAmount, DiscountAmount, FinalAmount, Status, PaymentStatus, CreatedAt) VALUES
(1, 'ORD-20261004-001', 1, 4, N'Anh Tuấn', '0912345678', 1, N'Khách ngồi tầng trệt, không dùng đường', 64000, 0, 64000, 3, 1, DATEADD(MINUTE, -120, GETDATE())),
(2, 'ORD-20261004-002', 4, 4, N'Chị Mai', '0923456789', 1, N'Uống tại chỗ ngắm ban công', 90000, 0, 90000, 3, 1, DATEADD(MINUTE, -90, GETDATE())),
(3, 'ORD-20261004-003', 5, 5, N'Hội bạn thân', '0934567890', 1, N'Bàn ban công gọi thêm bánh ngọt', 135000, 10000, 125000, 2, 0, DATEADD(MINUTE, -45, GETDATE())),
(4, 'ORD-20261004-004', 8, 4, N'Đoàn công tác TechCorp', '0945678901', 1, N'Phòng VIP 1 dùng bữa trưa và cà phê', 485000, 48500, 436500, 1, 0, DATEADD(MINUTE, -30, GETDATE())),
(5, 'ORD-20261004-005', NULL, 3, N'Khách vãng lai A', '0956789012', 2, N'Mua mang về gấp, cho đá riêng', 58000, 0, 58000, 3, 1, DATEADD(MINUTE, -25, GETDATE())),
(6, 'ORD-20261004-006', 1, 5, N'Khách gọi thêm ly', '0912345678', 1, N'Gọi thêm 1 ly bạc xỉu', 35000, 0, 35000, 1, 0, DATEADD(MINUTE, -15, GETDATE())),
(7, 'ORD-20261004-007', NULL, 3, N'Chị Hoàng Anh', '0967890123', 2, N'Mang về 2 ly trà đào cam sả', 84000, 0, 84000, 0, 0, DATEADD(MINUTE, -10, GETDATE())),
(8, 'ORD-20261004-008', 2, 4, N'Anh Long', '0978901234', 1, N'Bàn đơn làm việc', 25000, 0, 25000, 0, 0, DATEADD(MINUTE, -5, GETDATE())),
(9, 'ORD-20261004-009', 9, 2, N'Đoàn đối tác VIB', '0989012345', 1, N'Đặt cọc phòng VIP 2 chiều nay', 500000, 0, 500000, 0, 1, DATEADD(MINUTE, -3, GETDATE())),
(10, 'ORD-20261004-010', NULL, 3, N'Khách hủy', '0990123456', 2, N'Khách có việc bận gấp xin hủy đơn', 29000, 0, 29000, 4, 0, DATEADD(MINUTE, -1, GETDATE()));
SET IDENTITY_INSERT Orders OFF;
GO

-- 9. CHÈN 10 CHI TIẾT ĐƠN HÀNG (ORDER_DETAILS - LIÊN KẾT ĐƠN VÀ MÓN)
SET IDENTITY_INSERT OrderDetails ON;
INSERT INTO OrderDetails (OrderDetailId, OrderId, ProductId, Quantity, UnitPrice, SubTotal, ItemNote, CookingStatus) VALUES
(1, 1, 1, 1, 25000, 25000, N'Đen đá không đường', 2),
(2, 1, 4, 1, 39000, 39000, N'Nhiều kem muối', 2),
(3, 2, 5, 1, 42000, 42000, N'Ít ngọt, nhiều đá', 2),
(4, 2, 6, 1, 48000, 48000, N'Thêm trân châu', 2),
(5, 3, 8, 2, 45000, 90000, N'Lấy bánh lạnh', 2),
(6, 3, 3, 1, 35000, 35000, N'Nhiều sữa', 2),
(7, 4, 9, 5, 55000, 275000, N'Trứng ốp la lòng đào', 1),
(8, 4, 7, 3, 52000, 156000, N'Nhiều kem tươi', 1),
(9, 5, 2, 2, 29000, 58000, N'Cho đá riêng mang đi', 2),
(10, 6, 3, 1, 35000, 35000, N'Bạc xỉu nóng', 0);
SET IDENTITY_INSERT OrderDetails OFF;
GO

-- 10. CHÈN 10 GIAO DỊCH THANH TOÁN (PAYMENTS)
SET IDENTITY_INSERT Payments ON;
INSERT INTO Payments (PaymentId, OrderId, PaymentMethod, Amount, TransactionRef, Status, Note, PaymentTime) VALUES
(1, 1, 'Cash', 64000, 'CASH-20261004-001', 1, N'Khách trả tiền mặt tại quầy thu ngân', DATEADD(MINUTE, -110, GETDATE())),
(2, 2, 'VietQR', 90000, 'MB-FT261004847291', 1, N'Thanh toán quét mã VietQR ngân hàng MB Bank', DATEADD(MINUTE, -85, GETDATE())),
(3, 5, 'VietQR', 58000, 'VCB-261004992812', 1, N'Chuyển khoản VietQR Vietcombank tức thì', DATEADD(MINUTE, -20, GETDATE())),
(4, 9, 'VNPay', 500000, 'VNPAY-TRANS-9847120', 1, N'Thanh toán cọc phòng VIP qua cổng VNPayment', DATEADD(MINUTE, -2, GETDATE())),
(5, 3, 'VietQR', 125000, 'TCB-FT8847291039', 0, N'Đang chờ khách quét mã VietQR tại bàn', DATEADD(MINUTE, -10, GETDATE())),
(6, 4, 'Cash', 436500, 'CASH-PENDING-004', 0, N'Đoàn khách đang dùng món, thanh toán sau', DATEADD(MINUTE, -5, GETDATE())),
(7, 7, 'Cash', 84000, 'CASH-WAITING-007', 0, N'Chờ thu tiền khi giao đồ uống mang về', DATEADD(MINUTE, -8, GETDATE())),
(8, 8, 'VietQR', 25000, 'VIETQR-GEN-008', 0, N'Đã xuất mã QR động 25.000đ cho bàn T1-02', DATEADD(MINUTE, -4, GETDATE())),
(9, 6, 'Cash', 35000, 'CASH-ADD-006', 0, N'Đơn gọi thêm tính gộp vào bàn T1-01', DATEADD(MINUTE, -3, GETDATE())),
(10, 10, 'VNPay', 29000, 'VNPAY-REFUND-010', 2, N'Giao dịch hủy do khách xin hủy đơn', DATEADD(MINUTE, -1, GETDATE()));
SET IDENTITY_INSERT Payments OFF;
GO

PRINT N'========================================================================'
PRINT N'== KHỞI TẠO CSDL RESTAURANTPOSDB VÀ CHÈN DỮ LIỆU THÀNH CÔNG RỰC RỠ! =='
PRINT N'== 10 BẢNG TOÀN VẸN - MỖI BẢNG CHỨA ĐÚNG 10 DÒNG DỮ LIỆU CHUẨN F&B.  =='
PRINT N'========================================================================'
GO
