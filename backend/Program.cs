using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using WebApi.Hubs;
using WebApi.Models;
using WebApi.Services;

var builder = WebApplication.CreateBuilder(args);

// 0. Nạp cấu hình từ .env nếu tồn tại (không ghi đè biến môi trường đã đặt sẵn, bỏ dấu ngoặc kép)
var envCandidates = new[]
{
    ".env",
    "../.env",
    Path.Combine(Directory.GetCurrentDirectory(), ".env"),
    Path.Combine(AppContext.BaseDirectory, ".env")
};
foreach (var envPath in envCandidates)
{
    if (!File.Exists(envPath)) continue;
    foreach (var line in File.ReadAllLines(envPath))
    {
        var trimmed = line.Trim();
        if (string.IsNullOrWhiteSpace(trimmed) || trimmed.StartsWith('#')) continue;
        var parts = trimmed.Split('=', 2);
        if (parts.Length != 2) continue;
        var key = parts[0].Trim();
        var val = parts[1].Trim().Trim('"').Trim('\'');
        if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable(key)))
        {
            Environment.SetEnvironmentVariable(key, val);
            builder.Configuration[key] = val;
            builder.Configuration[key.Replace("__", ":")] = val;
        }
    }
    break;
}

// 1. Cấu hình CORS dựa trên ALLOWED_ORIGINS (+ localhost dev ports cho Flutter Web)
var allowedOriginsRaw = builder.Configuration["ALLOWED_ORIGINS"];
var allowedOriginSet = string.IsNullOrWhiteSpace(allowedOriginsRaw)
    ? new HashSet<string>(StringComparer.OrdinalIgnoreCase)
    : allowedOriginsRaw
        .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
        .ToHashSet(StringComparer.OrdinalIgnoreCase);

builder.Services.AddCors(options =>
{
    options.AddPolicy("PosCorsPolicy", policy =>
    {
        policy.SetIsOriginAllowed(origin =>
        {
            if (allowedOriginSet.Contains(origin)) return true;
            if ((builder.Environment.IsDevelopment() || allowedOriginSet.Count == 0) &&
                Uri.TryCreate(origin, UriKind.Absolute, out var uri))
            {
                return uri.Host.Equals("localhost", StringComparison.OrdinalIgnoreCase) ||
                       uri.Host.Equals("127.0.0.1", StringComparison.OrdinalIgnoreCase) ||
                       uri.Host.Equals("10.0.2.2", StringComparison.OrdinalIgnoreCase);
            }
            return false;
        })
        .AllowAnyMethod()
        .AllowAnyHeader()
        .AllowCredentials();
    });
});

// 2. Thêm DbContext SQL Server
builder.Services.AddDbContext<RestaurantPosContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("RestaurantPosDb")));

// 3. Đăng ký HttpContextAccessor, SiteProvider, JwtTokenService, EmailService và SignalR
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<SiteProvider>();
builder.Services.AddSingleton<JwtTokenService>();
builder.Services.AddScoped<EmailService>();
builder.Services.AddSignalR();
builder.Services.AddSingleton<PosRealtimeNotifier>();

// 4. Cấu hình JWT Bearer Authentication & Authorization (Fail-fast nếu thiếu Jwt:Key)
var jwtSettings = builder.Configuration.GetSection("Jwt");
var secretKey = JwtTokenService.ResolveSigningKey(builder.Configuration);
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

Helper.ConfigureWebRoot(app.Environment.WebRootPath ?? Path.Combine(app.Environment.ContentRootPath, "wwwroot"));

// Global exception handler: không rò rỉ stack trace hoặc ex.Message
app.UseExceptionHandler(errorApp =>
{
    errorApp.Run(async context =>
    {
        context.Response.StatusCode = StatusCodes.Status500InternalServerError;
        context.Response.ContentType = "application/json; charset=utf-8";
        var payload = JsonSerializer.Serialize(new
        {
            statusCode = 500,
            success = false,
            message = "Đã xảy ra lỗi hệ thống nội bộ. Vui lòng thử lại sau."
        });
        await context.Response.WriteAsync(payload);
    });
});

app.UseCors("PosCorsPolicy");
app.UseStaticFiles();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHub<PosHub>("/hubs/pos");

app.Run();
