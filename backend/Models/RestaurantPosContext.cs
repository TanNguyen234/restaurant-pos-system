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
    public DbSet<OrderDetailModifier>? OrderDetailModifiers { get; set; }
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
    public string? ResetPasswordToken { get; set; }
    public DateTime? ResetPasswordExpiry { get; set; }
    public string? OAuthProvider { get; set; }
    public string? OAuthProviderId { get; set; }
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
    public int Status { get; set; } = 0; // 0: Empty, 1: Occupied, 2: Reserved
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
    public string Unit { get; set; } = "Phần";
    public string? Description { get; set; }
    public string ImageUrl { get; set; } = null!;
    public bool IsAvailable { get; set; } = true;
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
    public string AttributeGroup { get; set; } = null!; // 'Size', 'Đường', 'Đá', 'Topping'
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
    public int? TableId { get; set; }
    public int? AccountId { get; set; }
    public string? CustomerName { get; set; }
    public string? PhoneNumber { get; set; }
    public int OrderType { get; set; } = 1; // 1: DineIn, 2: Takeaway, 3: Delivery
    public string? Note { get; set; }
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
    public int CookingStatus { get; set; } = 0; // 0: Pending, 1: Cooking, 2: Ready
    public DateTime? StartedCookingAt { get; set; }
    public DateTime? FinishedCookingAt { get; set; }
}

[Table("Payments")]
public class Payment
{
    [Key]
    public int PaymentId { get; set; }
    public int OrderId { get; set; }
    public string PaymentMethod { get; set; } = null!; // 'Cash', 'VietQR', 'VNPay'
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
    public string ModifierName { get; set; } = null!;
    public decimal ExtraPrice { get; set; } = 0;
}
