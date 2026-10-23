using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using WebApi.Models;
using WebApi.Services;

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

// 3. Đăng ký HttpContextAccessor, SiteProvider và JwtTokenService
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<SiteProvider>();
builder.Services.AddSingleton<JwtTokenService>();

// 4. Cấu hình JWT Bearer Authentication & Authorization
var jwtSettings = builder.Configuration.GetSection("Jwt");
var secretKey = jwtSettings["Key"] ?? "RestaurantPosSecretKeyForJwtAuthentication2026!@#$%^&*()_+";
var keyBytes = Encoding.UTF8.GetBytes(secretKey);

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.RequireHttpsMetadata = false;
    options.SaveToken = true;
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(keyBytes),
        ValidateIssuer = true,
        ValidIssuer = jwtSettings["Issuer"] ?? "RestaurantPosApi",
        ValidateAudience = true,
        ValidAudience = jwtSettings["Audience"] ?? "RestaurantPosClients",
        ValidateLifetime = true,
        ClockSkew = TimeSpan.Zero
    };
});

builder.Services.AddAuthorization();

// 5. Thêm Controllers kèm cấu hình xử lý chu kỳ JSON an toàn
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.ReferenceHandler = System.Text.Json.Serialization.ReferenceHandler.IgnoreCycles;
    });

var app = builder.Build();

app.UseCors("AllowAll");
app.UseStaticFiles();

// Middleware xác thực & phân quyền
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
