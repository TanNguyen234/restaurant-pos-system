-- ======================================================================================
-- MIGRATION IDEMPOTENT (2026-11-26): Nâng cấp BOM/Kho, Thời hạn Đặt bàn, Ví Voucher & Bảo mật Đơn
-- Chạy an toàn nhiều lần trên CSDL đã có dữ liệu mà không làm mất dữ liệu hiện tại.
-- ======================================================================================

IF COL_LENGTH('Accounts', 'EmailVerificationExpiry') IS NULL
BEGIN
    ALTER TABLE Accounts ADD EmailVerificationExpiry DATETIME NULL;
END
GO

IF COL_LENGTH('Products', 'AutoDisabledByStock') IS NULL
BEGIN
    ALTER TABLE Products ADD AutoDisabledByStock BIT NOT NULL CONSTRAINT DF_Products_AutoDisabledByStock DEFAULT 0;
END
GO

IF COL_LENGTH('Orders', 'GuestAccessToken') IS NULL
BEGIN
    ALTER TABLE Orders ADD GuestAccessToken NVARCHAR(64) NULL;
END
GO

IF COL_LENGTH('OrderDetailModifiers', 'AttributeId') IS NULL
BEGIN
    ALTER TABLE OrderDetailModifiers ADD AttributeId INT NULL;
END
GO

IF COL_LENGTH('Reservations', 'AccountId') IS NULL
BEGIN
    ALTER TABLE Reservations ADD AccountId INT NULL CONSTRAINT FK_Reservations_Accounts REFERENCES Accounts(AccountId);
END
GO

IF COL_LENGTH('Reservations', 'DurationMinutes') IS NULL
BEGIN
    ALTER TABLE Reservations ADD DurationMinutes INT NOT NULL CONSTRAINT DF_Reservations_DurationMinutes DEFAULT 120;
END
GO

IF COL_LENGTH('Reservations', 'HoldGraceMinutes') IS NULL
BEGIN
    ALTER TABLE Reservations ADD HoldGraceMinutes INT NOT NULL CONSTRAINT DF_Reservations_HoldGraceMinutes DEFAULT 30;
END
GO

IF COL_LENGTH('Reservations', 'ExpiresAt') IS NULL
BEGIN
    ALTER TABLE Reservations ADD ExpiresAt DATETIME NULL;
END
GO

IF COL_LENGTH('Reservations', 'CheckedInOrderId') IS NULL
BEGIN
    ALTER TABLE Reservations ADD CheckedInOrderId INT NULL;
END
GO

IF COL_LENGTH('Reservations', 'DepositApplied') IS NULL
BEGIN
    ALTER TABLE Reservations ADD DepositApplied BIT NOT NULL CONSTRAINT DF_Reservations_DepositApplied DEFAULT 0;
END
GO

UPDATE Reservations
SET ExpiresAt = DATEADD(MINUTE, ISNULL(HoldGraceMinutes, 30), ArrivalTime)
WHERE ExpiresAt IS NULL;
GO

IF OBJECT_ID('ProductAttributeRecipes', 'U') IS NULL
BEGIN
    CREATE TABLE ProductAttributeRecipes (
        AttributeRecipeId INT IDENTITY(1,1) PRIMARY KEY,
        AttributeId INT NOT NULL CONSTRAINT FK_ProductAttributeRecipes_Attributes REFERENCES ProductAttributes(AttributeId) ON DELETE CASCADE,
        IngredientId INT NOT NULL CONSTRAINT FK_ProductAttributeRecipes_Ingredients REFERENCES Ingredients(IngredientId),
        QuantityRequired DECIMAL(18,2) NOT NULL,
        CONSTRAINT UQ_ProductAttributeRecipes_Attr_Ingredient UNIQUE (AttributeId, IngredientId)
    );
    CREATE NONCLUSTERED INDEX IX_ProductAttributeRecipes_AttributeId ON ProductAttributeRecipes(AttributeId);
END
GO

IF OBJECT_ID('AccountVouchers', 'U') IS NULL
BEGIN
    CREATE TABLE AccountVouchers (
        AccountVoucherId INT IDENTITY(1,1) PRIMARY KEY,
        AccountId INT NOT NULL CONSTRAINT FK_AccountVouchers_Accounts REFERENCES Accounts(AccountId),
        DiscountId INT NOT NULL CONSTRAINT FK_AccountVouchers_Discounts REFERENCES Discounts(DiscountId),
        VoucherCode NVARCHAR(50) NOT NULL,
        Status INT NOT NULL DEFAULT 0, -- 0: Available, 1: Used, 2: Expired
        RedeemedAt DATETIME NOT NULL DEFAULT GETDATE(),
        UsedAt DATETIME NULL,
        UsedOrderId INT NULL CONSTRAINT FK_AccountVouchers_Orders REFERENCES Orders(OrderId)
    );
    CREATE NONCLUSTERED INDEX IX_AccountVouchers_Account_Code ON AccountVouchers(AccountId, VoucherCode, Status);
END
GO

IF OBJECT_ID('OrderIdempotencyKeys', 'U') IS NULL
BEGIN
    CREATE TABLE OrderIdempotencyKeys (
        IdempotencyKey NVARCHAR(100) PRIMARY KEY,
        OrderId INT NOT NULL CONSTRAINT FK_OrderIdempotencyKeys_Orders REFERENCES Orders(OrderId) ON DELETE CASCADE,
        CreatedAt DATETIME NOT NULL DEFAULT GETDATE()
    );
END
GO

-- Backfill ví voucher từ lịch sử REDEEM cũ (nếu chưa có bản ghi AccountVouchers)
INSERT INTO AccountVouchers (AccountId, DiscountId, VoucherCode, Status, RedeemedAt)
SELECT lt.AccountId, d.DiscountId, d.Code, 0, lt.CreatedAt
FROM LoyaltyTransactions lt
JOIN Discounts d ON UPPER(d.Code) = UPPER(lt.VoucherCode)
WHERE lt.Type = 'REDEEM'
  AND lt.VoucherCode IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM AccountVouchers av
      WHERE av.AccountId = lt.AccountId AND UPPER(av.VoucherCode) = UPPER(d.Code)
  );
GO
