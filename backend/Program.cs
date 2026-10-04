using Microsoft.EntityFrameworkCore;
using WebApi.Models;

var builder = WebApplication.CreateBuilder(args);

// 1. Thêm cấu hình CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

// 2. Thêm DbContext SQL Server
builder.Services.AddDbContext<RestaurantPosContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("RestaurantPosDb")));

// 3. Đăng ký HttpContextAccessor và SiteProvider
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<SiteProvider>();

// 4. Thêm Controllers
builder.Services.AddControllers();

var app = builder.Build();

app.UseCors("AllowAll");
app.UseStaticFiles();
app.MapControllers();

app.Run();
