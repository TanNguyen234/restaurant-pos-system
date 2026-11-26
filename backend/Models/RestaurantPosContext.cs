using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace WebApi.Models;

public class RestaurantPosContext : DbContext
{
    public RestaurantPosContext(DbContextOptions<RestaurantPosContext> options) : base(options) { }

    public DbSet<Role> Roles { get; set; } = null!;
    public DbSet<Account> Accounts { get; set; } = null!;
    public DbSet<Area> Areas { get; set; } = null!;
    public DbSet<DiningTable> DiningTables { get; set; } = null!;
    public DbSet<Category> Categories { get; set; } = null!;
    public DbSet<Product> Products { get; set; } = null!;
    public DbSet<ProductAttribute> ProductAttributes { get; set; } = null!;
    public DbSet<Order> Orders { get; set; } = null!;
    public DbSet<OrderDetail> OrderDetails { get; set; } = null!;
    public DbSet<Payment> Payments { get; set; } = null!;
    public DbSet<OrderDetailModifier> OrderDetailModifiers { get; set; } = null!;
    public DbSet<Shift> Shifts { get; set; } = null!;
    public DbSet<Reservation> Reservations { get; set; } = null!;
    public DbSet<Discount> Discounts { get; set; } = null!;
    public DbSet<LoyaltyTransaction> LoyaltyTransactions { get; set; } = null!;
    public DbSet<Ingredient> Ingredients { get; set; } = null!;
    public DbSet<ProductRecipe> ProductRecipes { get; set; } = null!;
    public DbSet<ProductAttributeRecipe> ProductAttributeRecipes { get; set; } = null!;
    public DbSet<StockTransaction> StockTransactions { get; set; } = null!;
    public DbSet<AccountVoucher> AccountVouchers { get; set; } = null!;
    public DbSet<OrderIdempotencyKey> OrderIdempotencyKeys { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<Product>().Property(p => p.Price).HasColumnType("decimal(18,0)");
        modelBuilder.Entity<ProductAttribute>().Property(p => p.ExtraPrice).HasColumnType("decimal(18,0)");

        modelBuilder.Entity<Order>().Property(p => p.TotalAmount).HasColumnType("decimal(18,0)");
        modelBuilder.Entity<Order>().Property(p => p.DiscountAmount).HasColumnType("decimal(18,0)");
        modelBuilder.Entity<Order>().Property(p => p.FinalAmount).HasColumnType("decimal(18,0)");

        modelBuilder.Entity<OrderDetail>().Property(p => p.UnitPrice).HasColumnType("decimal(18,0)");
        modelBuilder.Entity<OrderDetail>().Property(p => p.SubTotal).HasColumnType("decimal(18,0)");
        modelBuilder.Entity<OrderDetailModifier>().Property(p => p.ExtraPrice).HasColumnType("decimal(18,0)");

        modelBuilder.Entity<Payment>().Property(p => p.Amount).HasColumnType("decimal(18,0)");

        modelBuilder.Entity<Shift>().Property(p => p.InitialCash).HasColumnType("decimal(18,0)");
        modelBuilder.Entity<Shift>().Property(p => p.TotalCash).HasColumnType("decimal(18,0)");
        modelBuilder.Entity<Shift>().Property(p => p.TotalCard).HasColumnType("decimal(18,0)");
        modelBuilder.Entity<Shift>().Property(p => p.TotalTransfer).HasColumnType("decimal(18,0)");
        modelBuilder.Entity<Shift>().Property(p => p.Discrepancy).HasColumnType("decimal(18,0)");

        modelBuilder.Entity<Reservation>().Property(p => p.DepositAmount).HasColumnType("decimal(18,0)");

        modelBuilder.Entity<Discount>().Property(p => p.DiscountPercent).HasColumnType("decimal(5,2)");
        modelBuilder.Entity<Discount>().Property(p => p.DiscountAmount).HasColumnType("decimal(18,0)");
        modelBuilder.Entity<Discount>().Property(p => p.MinOrderAmount).HasColumnType("decimal(18,0)");
        modelBuilder.Entity<Discount>().Property(p => p.MaxDiscountAmount).HasColumnType("decimal(18,0)");

        modelBuilder.Entity<Ingredient>().Property(p => p.CurrentStock).HasColumnType("decimal(18,2)");
        modelBuilder.Entity<Ingredient>().Property(p => p.MinThreshold).HasColumnType("decimal(18,2)");
        modelBuilder.Entity<Ingredient>().Property(p => p.CostPerUnit).HasColumnType("decimal(18,0)");
        modelBuilder.Entity<ProductRecipe>().Property(p => p.QuantityRequired).HasColumnType("decimal(18,2)");
        modelBuilder.Entity<ProductAttributeRecipe>().Property(p => p.QuantityRequired).HasColumnType("decimal(18,2)");
        modelBuilder.Entity<StockTransaction>().Property(p => p.ChangeAmount).HasColumnType("decimal(18,2)");
    }
}

[Table("Roles")]
public class Role
{
    [Key]
    public int RoleId { get; set; }
    public string RoleName { get; set; } = null!;
    public string RoleCode { get; set; } = null!;
    public string? Description { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.Now;
}

[Table("Accounts")]
public class Account
{
    [Key]
    public int AccountId { get; set; }
    public int RoleId { get; set; }
    public string Username { get; set; } = null!;
    public string PasswordHash { get; set; } = null!;
    public string FullName { get; set; } = null!;
    public string? Email { get; set; }
    public string? PhoneNumber { get; set; }
    public string? Avatar { get; set; }
    public bool IsActive { get; set; } = true;
    public bool IsEmailVerified { get; set; } = false;
    public string? EmailVerificationToken { get; set; }
    public DateTime? EmailVerificationExpiry { get; set; }
    public string? ResetPasswordToken { get; set; }
    public DateTime? ResetPasswordExpiry { get; set; }
    public string? OAuthProvider { get; set; }
    public string? OAuthProviderId { get; set; }
    public int LoyaltyPoints { get; set; } = 0;
    public DateTime CreatedAt { get; set; } = DateTime.Now;
    public DateTime? UpdatedAt { get; set; }
}

[Table("Areas")]
public class Area
{
    [Key]
    public int AreaId { get; set; }
    public string AreaName { get; set; } = null!;
    public string? Description { get; set; }
    public int SortOrder { get; set; } = 0;
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.Now;
}

[Table("DiningTables")]
public class DiningTable
{
    [Key]
    public int TableId { get; set; }
    public int AreaId { get; set; }
    public string TableName { get; set; } = null!;
    public int Capacity { get; set; } = 4;
    public int Status { get; set; } = 0; // 0: Empty, 1: Occupied, 2: Waiting, 3: Reserved
    public int? CurrentOrderId { get; set; }
    public DateTime UpdatedAt { get; set; } = DateTime.Now;
}

[Table("Categories")]
public class Category
{
    [Key]
    [Column("CategoryId")]
    public short Id { get; set; }

    [Column("CategoryName")]
    public string Name { get; set; } = null!;

    public string Title { get; set; } = null!;
    public string Description { get; set; } = null!;
    public string Icon { get; set; } = null!;
    public int SortOrder { get; set; } = 0;
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.Now;
    public DateTime? UpdatedAt { get; set; }
}

[Table("Products")]
public class Product
{
    [Key]
    public int ProductId { get; set; }
    public short CategoryId { get; set; }
    public string ProductName { get; set; } = null!;
    public decimal Price { get; set; }
    public string Unit { get; set; } = "Ly";
    public string? Description { get; set; }
    public string ImageUrl { get; set; } = null!;
    public bool IsAvailable { get; set; } = true;
    public bool AutoDisabledByStock { get; set; } = false;
    public bool IsFeatured { get; set; } = false;
    public DateTime CreatedAt { get; set; } = DateTime.Now;
    public DateTime? UpdatedAt { get; set; }
}

[Table("ProductAttributes")]
public class ProductAttribute
{
    [Key]
    public int AttributeId { get; set; }
    public int ProductId { get; set; }
    public string AttributeGroup { get; set; } = null!;
    public string AttributeName { get; set; } = null!;
    public decimal ExtraPrice { get; set; } = 0;
    public bool IsRequired { get; set; } = false;
}

[Table("Orders")]
public class Order
{
    [Key]
    public int OrderId { get; set; }
    public string OrderCode { get; set; } = null!;
    public string? IdempotencyKey { get; set; }
    public string? GuestAccessToken { get; set; }
    public int? TableId { get; set; }
    public int? AccountId { get; set; }
    public string? CustomerName { get; set; }
    public string? PhoneNumber { get; set; }
    public int OrderType { get; set; } = 1; // 1: DineIn, 2: Takeaway, 3: Delivery
    public string? Note { get; set; }
    public string? DiscountCode { get; set; }
    public decimal TotalAmount { get; set; }
    public decimal DiscountAmount { get; set; }
    public decimal FinalAmount { get; set; }
    public int Status { get; set; } = 0; // 0: New, 1: Cooking, 2: Served, 3: Completed, 4: Cancelled
    public int PaymentStatus { get; set; } = 0; // 0: Unpaid, 1: Paid
    public DateTime CreatedAt { get; set; } = DateTime.Now;
    public DateTime? CompletedAt { get; set; }
}

[Table("OrderDetails")]
public class OrderDetail
{
    [Key]
    public int OrderDetailId { get; set; }
    public int OrderId { get; set; }
    public int ProductId { get; set; }
    public int Quantity { get; set; } = 1;
    public decimal UnitPrice { get; set; }
    public decimal SubTotal { get; set; }
    public string? ItemNote { get; set; }
    public int CookingStatus { get; set; } = 0; // 0: Pending, 1: Cooking, 2: Ready, 3: Served, 4: Voided
    public DateTime? StartedCookingAt { get; set; }
    public DateTime? FinishedCookingAt { get; set; }
}

[Table("Payments")]
public class Payment
{
    [Key]
    public int PaymentId { get; set; }
    public int OrderId { get; set; }
    public int? ShiftId { get; set; }
    public int? ProcessedByAccountId { get; set; }
    public string PaymentMethod { get; set; } = null!;
    public decimal Amount { get; set; }
    public string? TransactionRef { get; set; }
    public int Status { get; set; } = 1; // 0: Pending, 1: Success, 2: Failed
    public string? Note { get; set; }
    public DateTime PaymentTime { get; set; } = DateTime.Now;
}

[Table("OrderDetailModifiers")]
public class OrderDetailModifier
{
    [Key]
    public int Id { get; set; }
    public int OrderDetailId { get; set; }
    public int? AttributeId { get; set; }
    public string ModifierName { get; set; } = null!;
    public decimal ExtraPrice { get; set; } = 0;
}

[Table("Shifts")]
public class Shift
{
    [Key]
    public int ShiftId { get; set; }
    public int AccountId { get; set; }
    public DateTime StartTime { get; set; } = DateTime.Now;
    public DateTime? EndTime { get; set; }
    public decimal InitialCash { get; set; } = 0;
    public decimal TotalCash { get; set; } = 0;
    public decimal TotalCard { get; set; } = 0;
    public decimal TotalTransfer { get; set; } = 0;
    public decimal Discrepancy { get; set; } = 0;
    public int Status { get; set; } = 1; // 1: Open, 2: Closed
    public string? Note { get; set; }
    public string? ZReportJson { get; set; }
}

[Table("Reservations")]
public class Reservation
{
    [Key]
    public int ReservationId { get; set; }
    public int TableId { get; set; }
    public int? AccountId { get; set; }
    public string CustomerName { get; set; } = null!;
    public string PhoneNumber { get; set; } = null!;
    public int GuestCount { get; set; } = 2;
    public DateTime ArrivalTime { get; set; }
    public int DurationMinutes { get; set; } = 120;
    public int HoldGraceMinutes { get; set; } = 30;
    public DateTime? ExpiresAt { get; set; }
    public decimal DepositAmount { get; set; } = 0;
    public bool DepositApplied { get; set; } = false;
    public int? CheckedInOrderId { get; set; }
    public string? Note { get; set; }
    public int Status { get; set; } = 0; // 0: Pending, 1: Confirmed, 2: CheckedIn, 3: Cancelled, 4: NoShow
    public DateTime CreatedAt { get; set; } = DateTime.Now;
}

[Table("Discounts")]
public class Discount
{
    [Key]
    public int DiscountId { get; set; }
    public string Code { get; set; } = null!;
    public string Title { get; set; } = null!;
    public decimal DiscountPercent { get; set; } = 0;
    public decimal DiscountAmount { get; set; } = 0;
    public decimal MinOrderAmount { get; set; } = 0;
    public decimal MaxDiscountAmount { get; set; } = 0;
    public int PointsCost { get; set; } = 0;
    public int? MaxUsageCount { get; set; }
    public int UsedCount { get; set; } = 0;
    public DateTime? ExpiryDate { get; set; }
    public bool IsActive { get; set; } = true;
}

[Table("LoyaltyTransactions")]
public class LoyaltyTransaction
{
    [Key]
    public int TransactionId { get; set; }
    public int AccountId { get; set; }
    public int? OrderId { get; set; }
    public int PointsDelta { get; set; }
    public string Type { get; set; } = "EARN"; // EARN | REDEEM
    public string? VoucherCode { get; set; }
    public string Description { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.Now;
}

[Table("Ingredients")]
public class Ingredient
{
    [Key]
    public int IngredientId { get; set; }
    public string IngredientName { get; set; } = null!;
    public string Unit { get; set; } = "gram";
    public decimal CurrentStock { get; set; } = 0;
    public decimal MinThreshold { get; set; } = 10;
    public decimal CostPerUnit { get; set; } = 0;
    public bool IsActive { get; set; } = true;
    public DateTime UpdatedAt { get; set; } = DateTime.Now;
}

[Table("ProductRecipes")]
public class ProductRecipe
{
    [Key]
    public int RecipeId { get; set; }
    public int ProductId { get; set; }
    public int IngredientId { get; set; }
    public decimal QuantityRequired { get; set; }
}

[Table("StockTransactions")]
public class StockTransaction
{
    [Key]
    public int StockTxId { get; set; }
    public int IngredientId { get; set; }
    public int? OrderId { get; set; }
    public int? AccountId { get; set; }
    public decimal ChangeAmount { get; set; }
    public string Type { get; set; } = "IMPORT"; // IMPORT | ADJUST | DEDUCT | REFUND
    public string? Note { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.Now;
}

[Table("ProductAttributeRecipes")]
public class ProductAttributeRecipe
{
    [Key]
    public int AttributeRecipeId { get; set; }
    public int AttributeId { get; set; }
    public int IngredientId { get; set; }
    public decimal QuantityRequired { get; set; }
}

[Table("AccountVouchers")]
public class AccountVoucher
{
    [Key]
    public int AccountVoucherId { get; set; }
    public int AccountId { get; set; }
    public int DiscountId { get; set; }
    public string VoucherCode { get; set; } = string.Empty;
    public int Status { get; set; } = 0; // 0: Available, 1: Used, 2: Expired
    public DateTime RedeemedAt { get; set; } = DateTime.Now;
    public DateTime? UsedAt { get; set; }
    public int? UsedOrderId { get; set; }
}

[Table("OrderIdempotencyKeys")]
public class OrderIdempotencyKey
{
    [Key]
    public string IdempotencyKey { get; set; } = string.Empty;
    public int OrderId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.Now;
}
