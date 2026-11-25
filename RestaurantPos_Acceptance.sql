-- ======================================================================================
-- DỰ ÁN: HỆ THỐNG QUẢN LÝ NHÀ HÀNG & QUÁN CÀ PHÊ (RESTAURANT & CAFE POS SYSTEM)
-- CÔNG NGHỆ: C# ASP.NET Core 10 Web API + Microsoft SQL Server + Flutter Mobile (SQLite)
-- MỤC ĐÍCH: Khởi tạo CSDL 15 bảng chuẩn hóa 3NF, Index tối ưu, Ràng buộc toàn vẹn & Dữ liệu mẫu đồng bộ.
-- ======================================================================================

USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'RestaurantPos_Acceptance')
BEGIN
    CREATE DATABASE RestaurantPos_Acceptance;
END
GO

USE RestaurantPos_Acceptance;
GO

-- XÓA BẢNG CŨ THEO THỨ TỰ PHỤ THUỘC KHÓA NGOẠI (ĐẢM BẢO CHẠY LẠI AN TOÀN 100%)
IF OBJECT_ID('LoyaltyTransactions', 'U') IS NOT NULL DROP TABLE LoyaltyTransactions;
IF OBJECT_ID('Payments', 'U') IS NOT NULL DROP TABLE Payments;
IF OBJECT_ID('Shifts', 'U') IS NOT NULL DROP TABLE Shifts;
IF OBJECT_ID('Reservations', 'U') IS NOT NULL DROP TABLE Reservations;
IF OBJECT_ID('Discounts', 'U') IS NOT NULL DROP TABLE Discounts;
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
-- II. DDL: KHỞI TẠO CẤU TRÚC 15 BẢNG QUAN HỆ
-- ======================================================================================

-- 1. VAI TRÒ NGƯỜI DÙNG (ROLES)
CREATE TABLE Roles (
    RoleId INT IDENTITY(1,1) PRIMARY KEY,
    RoleName NVARCHAR(64) NOT NULL UNIQUE,
    RoleCode VARCHAR(32) NOT NULL UNIQUE,
    Description NVARCHAR(256) NULL,
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE()
);
GO

-- 2. TÀI KHOẢN NGƯỜI DÙNG & XÁC THỰC (ACCOUNTS)
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
    OAuthProvider VARCHAR(32) NULL,
    OAuthProviderId VARCHAR(128) NULL,
    LoyaltyPoints INT NOT NULL DEFAULT 0,
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),
    UpdatedAt DATETIME NULL
);
GO

-- 3. KHU VỰC PHỤC VỤ (AREAS)
CREATE TABLE Areas (
    AreaId INT IDENTITY(1,1) PRIMARY KEY,
    AreaName NVARCHAR(64) NOT NULL,
    Description NVARCHAR(256) NULL,
    SortOrder INT NOT NULL DEFAULT 0,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE()
);
GO

-- 4. BÀN ĂN & TRẠNG THÁI (DINING_TABLES)
CREATE TABLE DiningTables (
    TableId INT IDENTITY(1,1) PRIMARY KEY,
    AreaId INT NOT NULL CONSTRAINT FK_Tables_Areas REFERENCES Areas(AreaId),
    TableName NVARCHAR(64) NOT NULL,
    Capacity INT NOT NULL DEFAULT 4,
    Status INT NOT NULL DEFAULT 0, -- 0: Trống, 1: Có khách, 2: Chờ phục vụ, 3: Đặt trước
    CurrentOrderId INT NULL,
    UpdatedAt DATETIME NOT NULL DEFAULT GETDATE()
);
GO

-- 5. DANH MỤC SẢN PHẨM (CATEGORIES)
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

-- 6. SẢN PHẨM / THỰC ĐƠN (PRODUCTS)
CREATE TABLE Products (
    ProductId INT IDENTITY(1,1) PRIMARY KEY,
    CategoryId SMALLINT NOT NULL CONSTRAINT FK_Products_Categories REFERENCES Categories(CategoryId),
    ProductName NVARCHAR(128) NOT NULL,
    Price DECIMAL(18,0) NOT NULL,
    Unit NVARCHAR(32) NOT NULL DEFAULT N'Ly',
    Description NVARCHAR(1024) NULL,
    ImageUrl NVARCHAR(1500) NOT NULL,
    IsAvailable BIT NOT NULL DEFAULT 1,
    IsFeatured BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),
    UpdatedAt DATETIME NULL
);
GO

-- 7. THUỘC TÍNH SẢN PHẨM / TOPPING / SIZE (PRODUCT_ATTRIBUTES)
CREATE TABLE ProductAttributes (
    AttributeId INT IDENTITY(1,1) PRIMARY KEY,
    ProductId INT NOT NULL CONSTRAINT FK_Attributes_Products REFERENCES Products(ProductId) ON DELETE CASCADE,
    AttributeGroup NVARCHAR(64) NOT NULL,
    AttributeName NVARCHAR(64) NOT NULL,
    ExtraPrice DECIMAL(18,0) NOT NULL DEFAULT 0,
    IsRequired BIT NOT NULL DEFAULT 0
);
GO

-- 8. ĐƠN HÀNG / HÓA ĐƠN (ORDERS)
CREATE TABLE Orders (
    OrderId INT IDENTITY(1,1) PRIMARY KEY,
    OrderCode VARCHAR(32) NOT NULL UNIQUE,
    IdempotencyKey NVARCHAR(128) NULL,
    TableId INT NULL CONSTRAINT FK_Orders_Tables REFERENCES DiningTables(TableId),
    AccountId INT NULL CONSTRAINT FK_Orders_Accounts REFERENCES Accounts(AccountId),
    CustomerName NVARCHAR(128) NULL,
    PhoneNumber VARCHAR(20) NULL,
    OrderType INT NOT NULL DEFAULT 1, -- 1: Tại bàn, 2: Mang về, 3: Giao hàng
    Note NVARCHAR(512) NULL,
    DiscountCode NVARCHAR(50) NULL,
    TotalAmount DECIMAL(18,0) NOT NULL DEFAULT 0,
    DiscountAmount DECIMAL(18,0) NOT NULL DEFAULT 0,
    FinalAmount DECIMAL(18,0) NOT NULL DEFAULT 0,
    Status INT NOT NULL DEFAULT 0, -- 0: Mới, 1: Đang chế biến, 2: Đã phục vụ, 3: Hoàn thành, 4: Hủy
    PaymentStatus INT NOT NULL DEFAULT 0, -- 0: Chưa thanh toán, 1: Đã thanh toán
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),
    CompletedAt DATETIME NULL
);
GO

-- 9. CHI TIẾT ĐƠN HÀNG (ORDER_DETAILS - KDS READY)
CREATE TABLE OrderDetails (
    OrderDetailId INT IDENTITY(1,1) PRIMARY KEY,
    OrderId INT NOT NULL CONSTRAINT FK_OrderDetails_Orders REFERENCES Orders(OrderId) ON DELETE CASCADE,
    ProductId INT NOT NULL CONSTRAINT FK_OrderDetails_Products REFERENCES Products(ProductId),
    Quantity INT NOT NULL DEFAULT 1,
    UnitPrice DECIMAL(18,0) NOT NULL,
    SubTotal DECIMAL(18,0) NOT NULL,
    ItemNote NVARCHAR(256) NULL,
    CookingStatus INT NOT NULL DEFAULT 0, -- 0: Chờ nấu, 1: Đang nấu, 2: Đã xong, 3: Đã giao, 4: Đã hủy món
    StartedCookingAt DATETIME NULL,
    FinishedCookingAt DATETIME NULL
);
GO

-- 10. CHI TIẾT TÙY CHỌN MÓN (ORDER_DETAIL_MODIFIERS)
CREATE TABLE OrderDetailModifiers (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    OrderDetailId INT NOT NULL CONSTRAINT FK_OrderDetailModifiers_OrderDetails REFERENCES OrderDetails(OrderDetailId) ON DELETE CASCADE,
    ModifierName NVARCHAR(100) NOT NULL,
    ExtraPrice DECIMAL(18,0) NOT NULL DEFAULT 0
);
GO

-- 11. CA LÀM VIỆC & KÉT TIỀN (SHIFTS)
CREATE TABLE Shifts (
    ShiftId INT IDENTITY(1,1) PRIMARY KEY,
    AccountId INT NOT NULL CONSTRAINT FK_Shifts_Accounts REFERENCES Accounts(AccountId),
    StartTime DATETIME NOT NULL DEFAULT GETDATE(),
    EndTime DATETIME NULL,
    InitialCash DECIMAL(18,0) NOT NULL DEFAULT 0,
    TotalCash DECIMAL(18,0) NOT NULL DEFAULT 0,
    TotalCard DECIMAL(18,0) NOT NULL DEFAULT 0,
    TotalTransfer DECIMAL(18,0) NOT NULL DEFAULT 0,
    Discrepancy DECIMAL(18,0) NOT NULL DEFAULT 0,
    Status INT NOT NULL DEFAULT 1, -- 1: Open, 2: Closed
    Note NVARCHAR(255) NULL,
    ZReportJson NVARCHAR(MAX) NULL
);
GO

-- 12. GIAO DỊCH THANH TOÁN (PAYMENTS)
CREATE TABLE Payments (
    PaymentId INT IDENTITY(1,1) PRIMARY KEY,
    OrderId INT NOT NULL CONSTRAINT FK_Payments_Orders REFERENCES Orders(OrderId),
    ShiftId INT NULL CONSTRAINT FK_Payments_Shifts REFERENCES Shifts(ShiftId),
    ProcessedByAccountId INT NULL CONSTRAINT FK_Payments_Accounts REFERENCES Accounts(AccountId),
    PaymentMethod VARCHAR(32) NOT NULL, -- 'Cash', 'VietQR', 'VNPay'
    Amount DECIMAL(18,0) NOT NULL,
    TransactionRef VARCHAR(128) NULL,
    Status INT NOT NULL DEFAULT 1, -- 0: Pending, 1: Success, 2: Failed
    Note NVARCHAR(256) NULL,
    PaymentTime DATETIME NOT NULL DEFAULT GETDATE()
);
GO

-- 13. ĐẶT BÀN TRƯỚC (RESERVATIONS)
CREATE TABLE Reservations (
    ReservationId INT IDENTITY(1,1) PRIMARY KEY,
    TableId INT NOT NULL CONSTRAINT FK_Reservations_DiningTables REFERENCES DiningTables(TableId),
    CustomerName NVARCHAR(100) NOT NULL,
    PhoneNumber VARCHAR(20) NOT NULL,
    GuestCount INT NOT NULL DEFAULT 2,
    ArrivalTime DATETIME NOT NULL,
    DepositAmount DECIMAL(18,0) NOT NULL DEFAULT 0,
    Note NVARCHAR(255) NULL,
    Status INT NOT NULL DEFAULT 0, -- 0: Pending, 1: Confirmed, 2: CheckedIn, 3: Cancelled
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE()
);
GO

-- 14. KHUYẾN MÃI & VOUCHER (DISCOUNTS)
CREATE TABLE Discounts (
    DiscountId INT IDENTITY(1,1) PRIMARY KEY,
    Code VARCHAR(50) NOT NULL UNIQUE,
    Title NVARCHAR(100) NOT NULL,
    DiscountPercent DECIMAL(5,2) NOT NULL DEFAULT 0,
    DiscountAmount DECIMAL(18,0) NOT NULL DEFAULT 0,
    MinOrderAmount DECIMAL(18,0) NOT NULL DEFAULT 0,
    MaxDiscountAmount DECIMAL(18,0) NOT NULL DEFAULT 0,
    PointsCost INT NOT NULL DEFAULT 0,
    MaxUsageCount INT NULL,
    UsedCount INT NOT NULL DEFAULT 0,
    ExpiryDate DATETIME NULL,
    IsActive BIT NOT NULL DEFAULT 1
);
GO

-- 15. LỊCH SỬ TÍCH & ĐỔI ĐIỂM HỘI VIÊN (LOYALTY_TRANSACTIONS)
CREATE TABLE LoyaltyTransactions (
    TransactionId INT IDENTITY(1,1) PRIMARY KEY,
    AccountId INT NOT NULL CONSTRAINT FK_LoyaltyTransactions_Accounts REFERENCES Accounts(AccountId),
    OrderId INT NULL CONSTRAINT FK_LoyaltyTransactions_Orders REFERENCES Orders(OrderId),
    PointsDelta INT NOT NULL,
    Type NVARCHAR(30) NOT NULL, -- 'EARN' | 'REDEEM'
    VoucherCode NVARCHAR(50) NULL,
    Description NVARCHAR(255) NOT NULL,
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE()
);
GO

-- INDEXES HIỆU NĂNG
CREATE NONCLUSTERED INDEX IX_Products_CategoryId ON Products(CategoryId);
CREATE NONCLUSTERED INDEX IX_Products_ProductName ON Products(ProductName);
CREATE NONCLUSTERED INDEX IX_Orders_OrderCode ON Orders(OrderCode);
CREATE UNIQUE NONCLUSTERED INDEX UX_Orders_IdempotencyKey ON Orders(IdempotencyKey) WHERE IdempotencyKey IS NOT NULL;
CREATE NONCLUSTERED INDEX IX_Orders_CreatedAt ON Orders(CreatedAt);
CREATE NONCLUSTERED INDEX IX_OrderDetails_OrderId ON OrderDetails(OrderId);
CREATE NONCLUSTERED INDEX IX_DiningTables_AreaId ON DiningTables(AreaId);
CREATE NONCLUSTERED INDEX IX_OrderDetailModifiers_OrderDetailId ON OrderDetailModifiers(OrderDetailId);
CREATE NONCLUSTERED INDEX IX_Shifts_AccountId ON Shifts(AccountId);
CREATE NONCLUSTERED INDEX IX_Shifts_Status ON Shifts(Status);
CREATE NONCLUSTERED INDEX IX_Payments_ShiftId ON Payments(ShiftId);
CREATE NONCLUSTERED INDEX IX_Reservations_TableId ON Reservations(TableId);
CREATE NONCLUSTERED INDEX IX_Reservations_ArrivalTime ON Reservations(ArrivalTime);
CREATE NONCLUSTERED INDEX IX_Discounts_Code ON Discounts(Code);
CREATE NONCLUSTERED INDEX IX_LoyaltyTransactions_AccountId ON LoyaltyTransactions(AccountId);
GO

-- ======================================================================================
-- III. DML: DỮ LIỆU MẪU CHUẨN THỰC TẾ F&B (100% ẢNH LOCAL & TOÀN VẸN KHÓA NGOẠI)
-- ======================================================================================

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
(10, N'Tài khoản đối tác / Giao hàng', 'DELIVERY_PARTNER', N'Nhận thông tin đơn hàng mang về và giao tận nơi'),
(11, N'Bộ phận bếp & pha chế (KDS)', 'KITCHEN', N'Màn hình KDS nhận order và chế biến món ăn');
SET IDENTITY_INSERT Roles OFF;
GO

SET IDENTITY_INSERT Accounts ON;
INSERT INTO Accounts (AccountId, RoleId, Username, PasswordHash, FullName, Email, PhoneNumber, Avatar, IsActive, IsEmailVerified, OAuthProvider, LoyaltyPoints) VALUES
(1, 1, 'admin', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', N'Nguyễn Văn Quản Trị', 'admin@restaurantpos.vn', '0901234567', 'admin_avatar.png', 1, 1, 'Local', 0),
(2, 2, 'manager01', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', N'Trần Thị Thu Quản Lý', 'manager01@restaurantpos.vn', '0902345678', 'manager_avatar.png', 1, 1, 'Local', 0),
(3, 3, 'cashier_mai', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', N'Lê Tuyết Mai', 'mai.cashier@restaurantpos.vn', '0903456789', 'mai_avatar.png', 1, 1, 'Local', 0),
(4, 4, 'waiter_nam', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', N'Phạm Hoàng Nam', 'nam.waiter@restaurantpos.vn', '0904567890', 'nam_avatar.png', 1, 1, 'Local', 0),
(5, 4, 'waiter_lan', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', N'Đỗ Ngọc Lan', 'lan.waiter@restaurantpos.vn', '0905678901', 'lan_avatar.png', 1, 1, 'Local', 0),
(6, 5, 'barista_tuan', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', N'Vũ Anh Tuấn', 'tuan.barista@restaurantpos.vn', '0906789012', 'tuan_avatar.png', 1, 1, 'Local', 0),
(7, 6, 'chef_dung', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', N'Ngô Tiến Dũng', 'dung.chef@restaurantpos.vn', '0907890123', 'chef_avatar.png', 1, 1, 'Local', 0),
(8, 8, 'member_khang', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', N'Bùi Vĩnh Khang', 'khang.bui@gmail.com', '0908901234', 'khang_avatar.png', 1, 1, 'Google', 1250),
(9, 9, 'vip_huong', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', N'Đặng Thu Hương', 'huong.dang@fpt.com', '0909012345', 'huong_avatar.png', 1, 1, 'Zalo', 2800),
(10, 8, 'member_linh', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', N'Võ Diệu Linh', 'linh.vo@outlook.com', '0910123456', 'linh_avatar.png', 1, 0, 'Facebook', 450),
(11, 11, 'kitchen', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', N'Bếp Trưởng KDS', 'kitchen@restaurantpos.vn', '0907890124', 'chef_avatar.png', 1, 1, 'Local', 0);
SET IDENTITY_INSERT Accounts OFF;
GO

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

SET IDENTITY_INSERT DiningTables ON;
INSERT INTO DiningTables (TableId, AreaId, TableName, Capacity, Status, CurrentOrderId) VALUES
(1, 1, N'Bàn T1-01', 4, 1, 6),   -- Đang có khách (Đơn #6 - chưa thanh toán)
(2, 1, N'Bàn T1-02', 2, 0, NULL), -- Trống
(3, 1, N'Bàn T1-03', 4, 0, NULL), -- Trống
(4, 2, N'Bàn BC-01', 4, 1, 8),   -- Đang có khách (Đơn #8 - chưa thanh toán)
(5, 2, N'Bàn BC-02', 6, 2, 3),   -- Chờ phục vụ (Đơn #3 - chưa thanh toán)
(6, 3, N'Bàn GV-01', 8, 0, NULL), -- Trống
(7, 3, N'Bàn GV-02', 4, 0, NULL), -- Trống
(8, 4, N'Phòng VIP-01', 12, 1, 4), -- Đang có khách (Đơn #4 - chưa thanh toán)
(9, 5, N'Phòng VIP-02', 10, 3, NULL), -- Đã đặt trước (có Reservation #1)
(10, 7, N'Bàn RT-01', 4, 0, NULL); -- Trống
SET IDENTITY_INSERT DiningTables OFF;
GO

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

SET IDENTITY_INSERT Products ON;
INSERT INTO Products (ProductId, CategoryId, ProductName, Price, Unit, Description, ImageUrl, IsAvailable, IsFeatured) VALUES
(1, 1, N'Cà phê đen đá Đắk Lắk', 25000, N'Ly', N'Hạt Robusta nguyên chất Đắk Lắk rang mộc, pha phin truyền thống thơm nồng, đậm đà vị đắng thanh nguyên bản.', 'cafe_den_da.jpg;cafe_den_da_2.jpg', 1, 1),
(2, 1, N'Cà phê sữa đá Sài Gòn', 29000, N'Ly', N'Hòa quyện tinh tế giữa cà phê Robusta pha phin đậm đặc và sữa đặc béo ngậy chuẩn vị Sài Gòn xưa.', 'cafe_sua_da.jpg;cafe_sua_da_2.jpg', 1, 1),
(3, 1, N'Bạc xỉu 3 tầng bồng bềnh', 35000, N'Ly', N'Nhiều sữa đặc, sữa tươi thanh trùng và lớp bọt cà phê thơm dịu phía trên, ngọt ngào dễ uống.', 'bac_xiu_3tang.jpg;bac_xiu_3tang_2.jpg', 1, 1),
(4, 1, N'Cà phê trứng Hà Nội', 45000, N'Ly', N'Lòng đỏ trứng gà tươi đánh bông mịn như mây cùng mật ong và sữa, kết hợp cà phê phin nóng hổi béo ngậy.', 'cafe_trung.jpg;cafe_trung_2.jpg', 1, 1),
(5, 1, N'Cà phê dừa Bến Tre xay tuyết', 45000, N'Ly', N'Cốt dừa béo bùi từ dừa Bến Tre xay mịn cùng đá tuyết, rưới lớp cà phê đen nguyên chất thơm lừng.', 'cafe_dua.jpg', 1, 0),
(6, 2, N'Cà phê Muối Cố Đô', 39000, N'Ly', N'Lớp kem muối béo mặn nhẹ hòa quyện cà phê pha máy Arabica Cầu Đất đậm đà độc đáo.', 'cafe_muoi.jpg;cafe_muoi_2.jpg', 1, 1),
(7, 2, N'Espresso Doppio', 35000, N'Tách', N'Chiết xuất 2 shot Arabica hảo hạng áp suất cao, lớp crema vàng óng sánh đặc lưu luyến.', 'espresso.jpg', 1, 0),
(8, 2, N'Caffè Latte nghệ thuật', 45000, N'Ly', N'Hạt cà phê Arabica kết hợp lớp sữa nóng đánh bông vi bọt mềm mượt, tạo hình hoa lá nghệ thuật.', 'latte.jpg;latte_2.jpg', 1, 1),
(9, 2, N'Cappuccino chuẩn Ý', 45000, N'Tách', N'Tỷ lệ vàng 1:1:1 giữa Espresso, sữa nóng và lớp bọt sữa dày xốp rắc bột cacao thơm phức.', 'cappuccino.jpg', 1, 0),
(10, 2, N'Caramel Macchiato đá', 49000, N'Ly', N'Pha trộn nhiều tầng của vani ngọt ngào, sữa tươi thanh trùng, cà phê espresso và sốt caramel óng ánh.', 'caramel_macchiato.jpg', 1, 1),
(11, 3, N'Trà đào cam sả thanh nhiệt', 42000, N'Ly', N'Đào ngâm giòn ngọt, cam vàng tươi mọng và hương thơm thanh mát từ sả tươi giải nhiệt cơ thể.', 'tra_dao_cam_sa.jpg;tra_dao_cam_sa_2.jpg', 1, 1),
(12, 3, N'Trà vải hoa hồng hạt chia', 45000, N'Ly', N'Trà ô long ủ lạnh thơm ngát hương hoa hồng Pháp, vải thiều ngọt lịm mọng nước kèm hạt chia giàu dưỡng chất.', 'tra_vai.jpg;tra_vai_2.jpg', 1, 1),
(13, 3, N'Trà dâu tằm tuyết nhĩ', 45000, N'Ly', N'Dâu tằm Đà Lạt ngâm đường phèn chua ngọt mát lành, kèm nấm tuyết nhĩ giòn sần sật bồi bổ sức khỏe.', 'tra_dau_tam.jpg', 1, 0),
(14, 4, N'Trà sữa Ô long nướng Trân châu', 48000, N'Ly', N'Lá trà ô long sao nướng thơm đượm vị khói quyện sữa tươi thanh trùng và trân châu hoàng kim dẻo dai.', 'trasua_olong_nuong.jpg;trasua_olong_nuong_2.jpg', 1, 1),
(15, 4, N'Trà sữa trân châu đường đen cheese', 52000, N'Ly', N'Trân châu thủ công nấu đường đen dẻo thơm, sữa tươi béo ngậy phủ lớp kem cheese macchiato sánh mịn mặn mặn.', 'trasua_duongden.jpg;trasua_duongden_2.jpg', 1, 1),
(16, 4, N'Trà sữa Thái xanh thạch phô mai', 45000, N'Ly', N'Trà xanh Thái thơm ngát thảo mộc tự nhiên, kèm thạch phô mai béo ngậy tan chảy thơm lừng.', 'trasua_thai_xanh.jpg', 1, 0),
(17, 5, N'Matcha đá xay kem tuyết Uji', 52000, N'Ly', N'Bột trà xanh Uji Kyoto Nhật Bản xay mịn cùng sữa và đá tuyết, phủ ngọn kem tươi bông tuyết rắc bột matcha.', 'matcha_daxay.jpg;matcha_daxay_2.jpg', 1, 1),
(18, 5, N'Socola đá xay bánh Oreo giòn', 49000, N'Ly', N'Bột cacao nguyên chất xay cùng bánh quy socola Oreo giòn rụm, sốt chocolate sánh mịn và whipping cream.', 'socola_daxay.jpg', 1, 0),
(19, 5, N'Sinh tố bơ sáp Đắk Lắk sầu riêng', 55000, N'Ly', N'Bơ sáp chín cây Đắk Lắk dẻo quánh xay cùng cơm sầu riêng Ri6 thơm nức mũi và sữa đặc béo ngậy.', 'sinhto_bo.jpg', 1, 1),
(20, 6, N'Bánh Tiramisu phô mai Ý', 45000, N'Phần', N'Từng lớp bánh thấm đẫm cà phê rượu nhẹ xen kẽ phô mai Mascarpone béo mịn và cacao nguyên chất.', 'banh_tiramisu.jpg;banh_tiramisu_2.jpg', 1, 1),
(21, 6, N'Croissant bơ tỏi trứng muối', 38000, N'Cái', N'Bánh sừng bò ngàn lớp nướng bơ Pháp vàng rụm thơm lừng, nhân sốt kim sa trứng muối tan chảy béo mặn cuốn hút.', 'croissant_trungmuoi.jpg;croissant_trungmuoi_2.jpg', 1, 1),
(22, 6, N'Bánh bông lan trứng muối phô mai', 42000, N'Phần', N'Cốt bánh bông lan mềm tan như mây, phủ sốt bơ trứng vàng óng, trứng muối bùi béo và chà bông heo hảo hạng.', 'bonglan_trungmuoi.jpg', 1, 0),
(23, 7, N'Bánh mì chảo đặc biệt', 55000, N'Chảo', N'Pate gan thơm béo, 2 trứng ốp la lòng đào, xúc xích tiêu, thịt bò mềm ngọt phục vụ nóng hổi kèm bánh mì giòn rụm.', 'banhmi_chao.jpg;banhmi_chao_2.jpg', 1, 1),
(24, 7, N'Phở bò bắp hoa Wagyu đặc biệt', 68000, N'Tô', N'Nước dùng xương hầm 24 giờ thơm mùi hoa hồi thảo quả, bánh phở mềm mướt và những lát bắp bò hoa vân mỡ ngọt mềm.', 'pho_bo_wagyu.jpg;pho_bo_wagyu_2.jpg', 1, 1),
(25, 7, N'Bún bò Huế giò chả chả cua', 60000, N'Tô', N'Hương thơm nồng nàn từ sả và mắm ruốc Huế, khoanh giò heo mềm rục, chả cua dai ngọt tự nhiên cùng nước dùng cay the kích thích.', 'bun_bo_hue.jpg;bun_bo_hue_2.jpg', 1, 1),
(26, 7, N'Hủ tiếu Nam Vang tôm mực', 55000, N'Tô', N'Sợi hủ tiếu dai dai, nước súp tôm khô mực ngọt thanh, tôm sú tươi rói, mực tươi giòn sần sật, thịt băm và trứng cút.', 'hutieu_namvang.jpg', 1, 0),
(27, 8, N'Khoai tây chiên phô mai lắc', 35000, N'Đĩa', N'Khoai tây nguyên cọng nhập khẩu chiên giòn tan ráo dầu, lắc đều lớp bột phô mai Cheddar béo ngậy mặn ngọt ăn hoài không ngán.', 'khoaitay_phomai.jpg;khoaitay_phomai_2.jpg', 1, 1),
(28, 8, N'Gà rán sốt mật ong cay giòn', 59000, N'Đĩa', N'Cánh gà và đùi gà tươi chiên vàng giòn rụm kiểu Hàn, áo đều lớp sốt mật ong cay ngọt óng ả thơm mè rang.', 'garan_sotcay.jpg;garan_sotcay_2.jpg', 1, 1),
(29, 8, N'Nem chua rán Hà Nội giòn béo', 42000, N'Đĩa', N'Nem chua tẩm bột chiên xù nóng giòn rụm bên ngoài, mềm dẻo ngậy béo bên trong, chấm tương ớt cay nồng chuẩn vị.', 'nemchua_ran.jpg', 1, 0),
(30, 9, N'Nước ép cam sành mọng nước', 39000, N'Ly', N'100% cam sành Tiền Giang vắt tươi nguyên chất khi gọi món, dồi dào Vitamin C tăng đề kháng, vị chua ngọt tự nhiên.', 'nuoc_ep_cam.jpg;nuoc_ep_cam_2.jpg', 1, 1),
(31, 9, N'Nước ép dưa hấu thanh mát', 35000, N'Ly', N'Dưa hấu Long An đỏ au mọng nước ép tươi nguyên chất không pha nước, giải nhiệt tức thì trong ngày oi bức.', 'nuoc_ep_duahau.jpg', 1, 0),
(32, 9, N'Nước ép táo cần tây Detox', 49000, N'Ly', N'Công thức ép chậm thanh lọc cơ thể từ cần tây tươi, táo xanh chua giòn và dưa leo mát lành, hỗ trợ vóc dáng.', 'nuoc_ep_tao.jpg', 1, 0),
(33, 10, N'Mojito chanh bạc hà thanh khiết', 39000, N'Ly', N'Lá bạc hà tươi nghiền nhẹ giải phóng tinh dầu thơm ngát kết hợp chanh tươi, đường mía và soda sủi bọt mát lạnh.', 'mojito_bacha.jpg;mojito_bacha_2.jpg', 1, 1),
(34, 10, N'Soda Blue Ocean việt quất', 42000, N'Ly', N'Sắc xanh đại dương bắt mắt từ hoa đậu biếc và siro Curacao kết hợp soda có ga sảng khoái và lát chanh tươi mát rượi.', 'soda_blueocean.jpg', 1, 1);
SET IDENTITY_INSERT Products OFF;
GO

-- 7. THUỘC TÍNH MÓN ĂN / TOPPING / SIZE (KHỚP ĐÚNG PRODUCT_ID 1..34)
SET IDENTITY_INSERT ProductAttributes ON;
INSERT INTO ProductAttributes (AttributeId, ProductId, AttributeGroup, AttributeName, ExtraPrice, IsRequired) VALUES
(1, 2, 'Size', N'Size Vừa (M)', 0, 1),
(2, 2, 'Size', N'Size Lớn (L)', 8000, 1),
(3, 11, 'Topping', N'Thêm miếng đào giòn', 10000, 0),
(4, 11, N'Đường', N'Giảm 50% đường', 0, 0),
(5, 11, N'Đá', N'Ít đá (30% đá)', 0, 0),
(6, 14, 'Size', N'Size Vừa (M)', 0, 1),
(7, 14, 'Size', N'Size Lớn (L)', 8000, 1),
(8, 14, 'Topping', N'Thêm trân châu hoàng kim', 10000, 0),
(9, 14, 'Topping', N'Thêm lớp kem cheese macchiato', 12000, 0),
(10, 17, 'Topping', N'Thêm thạch dừa giòn', 8000, 0),
(11, 23, 'Topping', N'Thêm xúc xích nướng', 15000, 0),
(12, 23, 'Topping', N'Thêm viên pate gan lớn', 12000, 0);
SET IDENTITY_INSERT ProductAttributes OFF;
GO

-- 8. MÃ GIẢM GIÁ & VOUCHER HỘI VIÊN
SET IDENTITY_INSERT Discounts ON;
INSERT INTO Discounts (DiscountId, Code, Title, DiscountPercent, DiscountAmount, MinOrderAmount, MaxDiscountAmount, PointsCost, MaxUsageCount, UsedCount, ExpiryDate, IsActive) VALUES
(1, 'BANMOI10', N'Ưu đãi Khách Mới giảm 10%', 10.00, 0, 50000, 50000, 0, NULL, 1, DATEADD(YEAR, 1, GETDATE()), 1),
(2, 'GIAM20K', N'Voucher Giảm 20.000đ cho đơn từ 100k', 0.00, 20000, 100000, 20000, 300, NULL, 0, DATEADD(YEAR, 1, GETDATE()), 1),
(3, 'VIPMEMBER', N'Đặc quyền VIP giảm 15%', 15.00, 0, 0, 100000, 800, NULL, 1, DATEADD(YEAR, 1, GETDATE()), 1);
SET IDENTITY_INSERT Discounts OFF;
GO

-- 9. ĐƠN HÀNG MẪU (ĐỒNG BỘ CHÍNH XÁC VỚI ORDER_DETAILS & DINING_TABLES)
SET IDENTITY_INSERT Orders ON;
INSERT INTO Orders (OrderId, OrderCode, TableId, AccountId, CustomerName, PhoneNumber, OrderType, Note, DiscountCode, TotalAmount, DiscountAmount, FinalAmount, Status, PaymentStatus, CreatedAt, CompletedAt) VALUES
(1, 'ORD-20261004-001', 1, 4, N'Anh Tuấn', '0912345678', 1, N'Khách ngồi tầng trệt, không dùng đường', NULL, 64000, 0, 64000, 3, 1, DATEADD(MINUTE, -120, GETDATE()), DATEADD(MINUTE, -105, GETDATE())),
(2, 'ORD-20261004-002', 4, 4, N'Chị Mai', '0923456789', 1, N'Uống tại chỗ ngắm ban công', NULL, 90000, 0, 90000, 3, 1, DATEADD(MINUTE, -90, GETDATE()), DATEADD(MINUTE, -75, GETDATE())),
(3, 'ORD-20261004-003', 5, 5, N'Hội bạn thân', '0934567890', 1, N'Bàn ban công gọi thêm bánh ngọt', 'BANMOI10', 135000, 10000, 125000, 2, 0, DATEADD(MINUTE, -45, GETDATE()), NULL),
(4, 'ORD-20261004-004', 8, 4, N'Đoàn công tác TechCorp', '0945678901', 1, N'Phòng VIP 1 dùng bữa trưa và cà phê', 'VIPMEMBER', 431000, 43100, 387900, 1, 0, DATEADD(MINUTE, -30, GETDATE()), NULL),
(5, 'ORD-20261004-005', NULL, 3, N'Khách vãng lai A', '0956789012', 2, N'Mua mang về gấp, cho đá riêng', NULL, 58000, 0, 58000, 3, 1, DATEADD(MINUTE, -25, GETDATE()), DATEADD(MINUTE, -20, GETDATE())),
(6, 'ORD-20261004-006', 1, 5, N'Anh Khang', '0908901234', 1, N'Gọi 1 bạc xỉu và 1 tiramisu', NULL, 80000, 0, 80000, 1, 0, DATEADD(MINUTE, -15, GETDATE()), NULL),
(7, 'ORD-20261004-007', NULL, 8, N'Bùi Vĩnh Khang', '0908901234', 2, N'Mang về 2 ly trà đào cam sả', NULL, 84000, 0, 84000, 0, 0, DATEADD(MINUTE, -10, GETDATE()), NULL),
(8, 'ORD-20261004-008', 4, 4, N'Anh Long', '0978901234', 1, N'Bàn ban công làm việc', NULL, 45000, 0, 45000, 0, 0, DATEADD(MINUTE, -5, GETDATE()), NULL),
(9, 'ORD-20261004-009', 9, 9, N'Đoàn đối tác VIB', '0909012345', 1, N'Đặt cọc phòng VIP 2 chiều nay', NULL, 500000, 0, 500000, 3, 1, DATEADD(MINUTE, -3, GETDATE()), DATEADD(MINUTE, -2, GETDATE())),
(10, 'ORD-20261004-010', NULL, 3, N'Khách hủy', '0990123456', 2, N'Khách có việc bận gấp xin hủy đơn', NULL, 29000, 0, 29000, 4, 0, DATEADD(MINUTE, -1, GETDATE()), NULL);
SET IDENTITY_INSERT Orders OFF;
GO

-- 10. CHI TIẾT ĐƠN HÀNG (KHỚP 100% TỔNG TIỀN TỪNG ĐƠN)
SET IDENTITY_INSERT OrderDetails ON;
INSERT INTO OrderDetails (OrderDetailId, OrderId, ProductId, Quantity, UnitPrice, SubTotal, ItemNote, CookingStatus) VALUES
(1, 1, 1, 1, 25000, 25000, N'Đen đá không đường', 3),
(2, 1, 6, 1, 39000, 39000, N'Nhiều kem muối', 3),
(3, 2, 11, 1, 42000, 42000, N'Ít ngọt, nhiều đá', 3),
(4, 2, 14, 1, 48000, 48000, N'Thêm trân châu', 3),
(5, 3, 20, 2, 45000, 90000, N'Lấy bánh lạnh', 2),
(6, 3, 8, 1, 45000, 45000, N'Latte nóng tạo hình', 2),
(7, 4, 23, 5, 55000, 275000, N'Trứng ốp la lòng đào', 1),
(8, 4, 17, 3, 52000, 156000, N'Nhiều kem tươi', 1),
(9, 5, 2, 2, 29000, 58000, N'Cho đá riêng mang đi', 3),
(10, 6, 3, 1, 35000, 35000, N'Bạc xỉu 3 tầng', 1),
(11, 6, 20, 1, 45000, 45000, N'Kèm thìa gỗ', 0),
(12, 7, 11, 2, 42000, 84000, N'Đóng ly mang về', 0),
(13, 8, 9, 1, 45000, 45000, N'Cappuccino ít bọt', 0),
(14, 9, 24, 5, 68000, 340000, N'Phở bò Wagyu đoàn VIP', 3),
(15, 9, 19, 2, 55000, 110000, N'Sinh tố bơ sầu riêng', 3),
(16, 9, 1, 2, 25000, 50000, N'Cà phê đen đá', 3),
(17, 10, 2, 1, 29000, 29000, N'Đã hủy theo yêu cầu khách', 4);
SET IDENTITY_INSERT OrderDetails OFF;
GO

-- 11. GIAO DỊCH THANH TOÁN MẪU
SET IDENTITY_INSERT Payments ON;
INSERT INTO Payments (PaymentId, OrderId, ShiftId, ProcessedByAccountId, PaymentMethod, Amount, TransactionRef, Status, Note, PaymentTime) VALUES
(1, 1, NULL, 3, 'Cash', 64000, 'CASH-20261004-001', 1, N'Khách trả tiền mặt tại quầy thu ngân', DATEADD(MINUTE, -105, GETDATE())),
(2, 2, NULL, 3, 'VietQR', 90000, 'VTB-FT261004847291', 1, N'Thanh toán quét mã VietQR ngân hàng VietinBank', DATEADD(MINUTE, -75, GETDATE())),
(3, 5, NULL, 3, 'VietQR', 58000, 'VTB-261004992812', 1, N'Chuyển khoản VietQR tức thì', DATEADD(MINUTE, -20, GETDATE())),
(4, 9, NULL, 3, 'VNPay', 500000, 'VNPAY-TRANS-9847120', 1, N'Thanh toán cọc phòng VIP qua cổng VNPay Sandbox', DATEADD(MINUTE, -2, GETDATE()));
SET IDENTITY_INSERT Payments OFF;
GO

-- 12. ĐẶT BÀN TRƯỚC MẪU (KHỚP PHÒNG VIP-02 STATUS = 3)
SET IDENTITY_INSERT Reservations ON;
INSERT INTO Reservations (ReservationId, TableId, CustomerName, PhoneNumber, GuestCount, ArrivalTime, DepositAmount, Note, Status) VALUES
(1, 9, N'Đoàn đối tác VIB', '0909012345', 8, DATEADD(HOUR, 2, GETDATE()), 500000, N'Chuẩn bị máy chiếu phòng VIP 02', 1);
SET IDENTITY_INSERT Reservations OFF;
GO

-- 13. LỊCH SỬ ĐIỂM THƯỞNG MẪU
SET IDENTITY_INSERT LoyaltyTransactions ON;
INSERT INTO LoyaltyTransactions (TransactionId, AccountId, OrderId, PointsDelta, Type, VoucherCode, Description) VALUES
(1, 8, NULL, 1250, 'EARN', NULL, N'Điểm tích lũy hội viên Bùi Vĩnh Khang'),
(2, 9, 9, 500, 'EARN', NULL, N'Tích điểm đơn đặt tiệc phòng VIP-02'),
(3, 9, NULL, 2300, 'EARN', NULL, N'Điểm tích lũy hạng VIP Vàng');
SET IDENTITY_INSERT LoyaltyTransactions OFF;
GO

PRINT N'KHỞI TẠO CSDL RestaurantPos_Acceptance (15 BẢNG) THÀNH CÔNG!'
GO

