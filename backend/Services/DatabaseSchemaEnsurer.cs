using Microsoft.EntityFrameworkCore;
using WebApi.Models;

namespace WebApi.Services;

/// <summary>
/// Tự động bổ sung cột/bảng mới an toàn (idempotent) khi Backend khởi động trên SQL Server đã có dữ liệu.
/// </summary>
public static class DatabaseSchemaEnsurer
{
    public static async Task EnsureAsync(RestaurantPosContext db, ILogger? logger = null)
    {
        if (!db.Database.IsSqlServer())
        {
            await db.Database.EnsureCreatedAsync();
            return;
        }

        const string ddl = @"
IF COL_LENGTH('Accounts', 'EmailVerificationExpiry') IS NULL
    ALTER TABLE Accounts ADD EmailVerificationExpiry DATETIME NULL;

IF COL_LENGTH('Products', 'AutoDisabledByStock') IS NULL
    ALTER TABLE Products ADD AutoDisabledByStock BIT NOT NULL CONSTRAINT DF_Products_AutoDisabledByStock DEFAULT 0;

IF COL_LENGTH('Orders', 'DeliveryAddress') IS NULL
    ALTER TABLE Orders ADD DeliveryAddress NVARCHAR(500) NULL;

IF COL_LENGTH('Orders', 'GuestAccessToken') IS NULL
    ALTER TABLE Orders ADD GuestAccessToken NVARCHAR(64) NULL;

IF COL_LENGTH('OrderDetailModifiers', 'AttributeId') IS NULL
    ALTER TABLE OrderDetailModifiers ADD AttributeId INT NULL;

IF COL_LENGTH('Reservations', 'AccountId') IS NULL
    ALTER TABLE Reservations ADD AccountId INT NULL CONSTRAINT FK_Reservations_Accounts REFERENCES Accounts(AccountId);

IF COL_LENGTH('Reservations', 'DurationMinutes') IS NULL
    ALTER TABLE Reservations ADD DurationMinutes INT NOT NULL CONSTRAINT DF_Reservations_DurationMinutes DEFAULT 120;

IF COL_LENGTH('Reservations', 'HoldGraceMinutes') IS NULL
    ALTER TABLE Reservations ADD HoldGraceMinutes INT NOT NULL CONSTRAINT DF_Reservations_HoldGraceMinutes DEFAULT 30;

IF COL_LENGTH('Reservations', 'ExpiresAt') IS NULL
    ALTER TABLE Reservations ADD ExpiresAt DATETIME NULL;

IF COL_LENGTH('Reservations', 'CheckedInOrderId') IS NULL
    ALTER TABLE Reservations ADD CheckedInOrderId INT NULL;

IF COL_LENGTH('Reservations', 'DepositApplied') IS NULL
    ALTER TABLE Reservations ADD DepositApplied BIT NOT NULL CONSTRAINT DF_Reservations_DepositApplied DEFAULT 0;

UPDATE Reservations
SET ExpiresAt = DATEADD(MINUTE, ISNULL(HoldGraceMinutes, 30), ArrivalTime)
WHERE ExpiresAt IS NULL;

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
END;

IF OBJECT_ID('AccountVouchers', 'U') IS NULL
BEGIN
    CREATE TABLE AccountVouchers (
        AccountVoucherId INT IDENTITY(1,1) PRIMARY KEY,
        AccountId INT NOT NULL CONSTRAINT FK_AccountVouchers_Accounts REFERENCES Accounts(AccountId),
        DiscountId INT NOT NULL CONSTRAINT FK_AccountVouchers_Discounts REFERENCES Discounts(DiscountId),
        VoucherCode NVARCHAR(50) NOT NULL,
        Status INT NOT NULL DEFAULT 0,
        RedeemedAt DATETIME NOT NULL DEFAULT GETDATE(),
        UsedAt DATETIME NULL,
        UsedOrderId INT NULL CONSTRAINT FK_AccountVouchers_Orders REFERENCES Orders(OrderId)
    );
    CREATE NONCLUSTERED INDEX IX_AccountVouchers_Account_Code ON AccountVouchers(AccountId, VoucherCode, Status);
END;

IF OBJECT_ID('OrderIdempotencyKeys', 'U') IS NULL
BEGIN
    CREATE TABLE OrderIdempotencyKeys (
        IdempotencyKey NVARCHAR(100) PRIMARY KEY,
        OrderId INT NOT NULL CONSTRAINT FK_OrderIdempotencyKeys_Orders REFERENCES Orders(OrderId) ON DELETE CASCADE,
        CreatedAt DATETIME NOT NULL DEFAULT GETDATE()
    );
END;

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
";

        try
        {
            await db.Database.ExecuteSqlRawAsync(ddl);
        }
        catch (Exception ex)
        {
            logger?.LogWarning(ex, "DatabaseSchemaEnsurer skipped or partially failed (verify SQL Server connectivity/permissions).");
        }
    }
}
