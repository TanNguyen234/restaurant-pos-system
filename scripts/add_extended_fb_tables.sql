-- EXTENDED F&B TABLES: OrderDetailModifiers, Shifts, Reservations, Discounts
USE RestaurantPos_Acceptance;
GO

IF OBJECT_ID('OrderDetailModifiers', 'U') IS NULL
BEGIN
    CREATE TABLE OrderDetailModifiers (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        OrderDetailId INT NOT NULL CONSTRAINT FK_OrderDetailModifiers_OrderDetails REFERENCES OrderDetails(OrderDetailId) ON DELETE CASCADE,
        ModifierName NVARCHAR(100) NOT NULL,
        ExtraPrice DECIMAL(18,0) NOT NULL DEFAULT 0
    );
    CREATE NONCLUSTERED INDEX IX_OrderDetailModifiers_OrderDetailId ON OrderDetailModifiers(OrderDetailId);
    PRINT 'Created OrderDetailModifiers table.';
END;
GO

IF OBJECT_ID('Shifts', 'U') IS NULL
BEGIN
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
    CREATE NONCLUSTERED INDEX IX_Shifts_AccountId ON Shifts(AccountId);
    CREATE NONCLUSTERED INDEX IX_Shifts_Status ON Shifts(Status);
    PRINT 'Created Shifts table.';
END;
GO

IF OBJECT_ID('Reservations', 'U') IS NULL
BEGIN
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
    CREATE NONCLUSTERED INDEX IX_Reservations_TableId ON Reservations(TableId);
    CREATE NONCLUSTERED INDEX IX_Reservations_ArrivalTime ON Reservations(ArrivalTime);
    PRINT 'Created Reservations table.';
END;
GO

IF OBJECT_ID('Discounts', 'U') IS NULL
BEGIN
    CREATE TABLE Discounts (
        DiscountId INT IDENTITY(1,1) PRIMARY KEY,
        Code VARCHAR(50) NOT NULL UNIQUE,
        Title NVARCHAR(100) NOT NULL,
        DiscountPercent DECIMAL(5,2) NOT NULL DEFAULT 0,
        DiscountAmount DECIMAL(18,0) NOT NULL DEFAULT 0,
        MinOrderAmount DECIMAL(18,0) NOT NULL DEFAULT 0,
        MaxDiscountAmount DECIMAL(18,0) NOT NULL DEFAULT 0,
        ExpiryDate DATETIME NULL,
        IsActive BIT NOT NULL DEFAULT 1
    );
    CREATE NONCLUSTERED INDEX IX_Discounts_Code ON Discounts(Code);
    PRINT 'Created Discounts table.';
END;
GO

-- Seed discount codes if empty
IF NOT EXISTS (SELECT 1 FROM Discounts WHERE Code = 'BANMOI10')
BEGIN
    INSERT INTO Discounts (Code, Title, DiscountPercent, DiscountAmount, MinOrderAmount, MaxDiscountAmount, ExpiryDate, IsActive)
    VALUES ('BANMOI10', N'Giảm 10% khách hàng mới', 10.0, 0, 50000, 50000, DATEADD(YEAR, 1, GETDATE()), 1);
END;

IF NOT EXISTS (SELECT 1 FROM Discounts WHERE Code = 'GIAM20K')
BEGIN
    INSERT INTO Discounts (Code, Title, DiscountPercent, DiscountAmount, MinOrderAmount, MaxDiscountAmount, ExpiryDate, IsActive)
    VALUES ('GIAM20K', N'Giảm 20.000đ cho đơn từ 100k', 0, 20000, 100000, 20000, DATEADD(YEAR, 1, GETDATE()), 1);
END;

IF NOT EXISTS (SELECT 1 FROM Discounts WHERE Code = 'VIPMEMBER')
BEGIN
    INSERT INTO Discounts (Code, Title, DiscountPercent, DiscountAmount, MinOrderAmount, MaxDiscountAmount, ExpiryDate, IsActive)
    VALUES ('VIPMEMBER', N'Đặc quyền VIP giảm 15%', 15.0, 0, 0, 100000, DATEADD(YEAR, 1, GETDATE()), 1);
END;
GO
