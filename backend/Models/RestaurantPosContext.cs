using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations.Schema;

namespace WebApi.Models;

public class RestaurantPosContext : DbContext
{
    public RestaurantPosContext(DbContextOptions<RestaurantPosContext> options) : base(options) { }

    public DbSet<Role> Roles { get; set; } = null!;
    public DbSet<Account> Accounts { get; set; } = null!;
    public DbSet<Category> Categories { get; set; } = null!;
    public DbSet<Product> Products { get; set; } = null!;
    public DbSet<DiningTable> DiningTables { get; set; } = null!;
    public DbSet<Order> Orders { get; set; } = null!;
    public DbSet<OrderDetail> OrderDetails { get; set; } = null!;
}

[Table("Roles")]
public class Role
{
    public int RoleId { get; set; }
    public string RoleName { get; set; } = null!;
    public string? Description { get; set; }
}

[Table("Accounts")]
public class Account
{
    public int AccountId { get; set; }
    public int RoleId { get; set; }
    public string Username { get; set; } = null!;
    public string PasswordHash { get; set; } = null!;
    public string FullName { get; set; } = null!;
    public string? Email { get; set; }
    public string? PhoneNumber { get; set; }
    public string? Avatar { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.Now;
}

[Table("Categories")]
public class Category
{
    [Column("CategoryId")]
    public short Id { get; set; }

    [Column("CategoryName")]
    public string Name { get; set; } = null!;

    public string Title { get; set; } = null!;
    public string Description { get; set; } = null!;
    public string Icon { get; set; } = null!;
    public int SortOrder { get; set; } = 0;
    public bool IsActive { get; set; } = true;
}

[Table("Products")]
public class Product
{
    public int ProductId { get; set; }
    public short CategoryId { get; set; }
    public string ProductName { get; set; } = null!;
    public decimal Price { get; set; }
    public string Unit { get; set; } = "Phần";
    public string? Description { get; set; }
    public string ImageUrl { get; set; } = null!;
    public bool IsAvailable { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.Now;
}

[Table("DiningTables")]
public class DiningTable
{
    public int TableId { get; set; }
    public int AreaId { get; set; }
    public string TableName { get; set; } = null!;
    public int Capacity { get; set; } = 4;
    public int Status { get; set; } = 0; // 0: Empty, 1: Occupied, 2: Reserved
    public DateTime UpdatedAt { get; set; } = DateTime.Now;
}

[Table("Orders")]
public class Order
{
    public int OrderId { get; set; }
    public string OrderCode { get; set; } = null!;
    public int? TableId { get; set; }
    public int? AccountId { get; set; }
    public string? CustomerName { get; set; }
    public string? Note { get; set; }
    public decimal TotalAmount { get; set; }
    public decimal DiscountAmount { get; set; }
    public decimal FinalAmount { get; set; }
    public int Status { get; set; } = 0; // 0: New, 1: Cooking, 2: Served, 3: Completed, 4: Cancelled
    public DateTime CreatedAt { get; set; } = DateTime.Now;
    public DateTime? CompletedAt { get; set; }
}

[Table("OrderDetails")]
public class OrderDetail
{
    public int OrderDetailId { get; set; }
    public int OrderId { get; set; }
    public int ProductId { get; set; }
    public int Quantity { get; set; } = 1;
    public decimal UnitPrice { get; set; }
    public decimal SubTotal { get; set; }
    public string? ItemNote { get; set; }
    public int CookingStatus { get; set; } = 0;
}
