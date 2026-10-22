using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using WebApi.Models;

var builder = WebApplication.CreateBuilder(args);

// Configuration must be provided by the deployment environment.
builder.Services.AddSingleton<PosTokenService>();
builder.Services.AddDbContext<RestaurantPosContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("RestaurantPosDb")
        ?? throw new InvalidOperationException("ConnectionStrings:RestaurantPosDb is required.")));
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<SiteProvider>();
builder.Services.AddControllers().AddJsonOptions(options =>
    options.JsonSerializerOptions.ReferenceHandler = System.Text.Json.Serialization.ReferenceHandler.IgnoreCycles);
builder.Services.AddCors(options => options.AddPolicy("PosClients", policy =>
    policy.WithOrigins(builder.Configuration.GetSection("AllowedOrigins").Get<string[]>() ?? Array.Empty<string>())
          .AllowAnyHeader().AllowAnyMethod()));

var app = builder.Build();
// Validate signing configuration at startup (fail closed).
_ = app.Services.GetRequiredService<PosTokenService>();

app.UseCors("PosClients");
app.UseStaticFiles();

app.Use(async (ctx, next) =>
{
    var path = ctx.Request.Path.Value ?? string.Empty;
    if (!path.StartsWith("/api/", StringComparison.OrdinalIgnoreCase))
    {
        await next();
        return;
    }
    var login = path.Equals("/api/auth/login", StringComparison.OrdinalIgnoreCase);
    var register = path.Equals("/api/auth/register", StringComparison.OrdinalIgnoreCase);
    var gatewayCallback = path.Equals("/api/payment/vnpay-return", StringComparison.OrdinalIgnoreCase);
    if (login || register || gatewayCallback)
    {
        await next();
        return;
    }

    var bearer = ctx.Request.Headers.Authorization.ToString();
    var token = bearer.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase)
        ? bearer["Bearer ".Length..].Trim() : string.Empty;
    var db = ctx.RequestServices.GetRequiredService<RestaurantPosContext>();
    var account = ctx.RequestServices.GetRequiredService<PosTokenService>().Validate(token, db);
    if (account == null)
    {
        ctx.Response.StatusCode = StatusCodes.Status401Unauthorized;
        await ctx.Response.WriteAsJsonAsync(new { success = false, message = "Phiên đăng nhập không hợp lệ hoặc đã hết hạn" });
        return;
    }
    var role = db.Roles.Find(account.RoleId)?.RoleCode ?? string.Empty;
    ctx.User = new ClaimsPrincipal(new ClaimsIdentity(new[]
    {
        new Claim(ClaimTypes.NameIdentifier, account.AccountId.ToString()),
        new Claim(ClaimTypes.Name, account.Username),
        new Claim(ClaimTypes.Role, role)
    }, "POS-Bearer"));

    var isAdmin = role == "ADMIN" || role == "MANAGER";
    var isCashier = isAdmin || role == "CASHIER";
    var isKitchen = isAdmin || role == "BARISTA_LEAD" || role == "HEAD_CHEF" || role == "COOK_ASSISTANT";
    var isWrite = !HttpMethods.IsGet(ctx.Request.Method) && !HttpMethods.IsHead(ctx.Request.Method);
    var denied =
        (path.StartsWith("/api/account", StringComparison.OrdinalIgnoreCase) && !isAdmin) ||
        (path.StartsWith("/api/payment", StringComparison.OrdinalIgnoreCase) && !isCashier) ||
        (path.StartsWith("/api/kds", StringComparison.OrdinalIgnoreCase) && !isKitchen) ||
        (path.StartsWith("/api/order/admin", StringComparison.OrdinalIgnoreCase) && !isCashier) ||
        (path.StartsWith("/api/order/", StringComparison.OrdinalIgnoreCase) && isWrite && !isCashier && role != "WAITER") ||
        (path.StartsWith("/api/product", StringComparison.OrdinalIgnoreCase) && isWrite && !isAdmin) ||
        (path.StartsWith("/api/category", StringComparison.OrdinalIgnoreCase) && isWrite && !isAdmin) ||
        (path.StartsWith("/api/table", StringComparison.OrdinalIgnoreCase) && isWrite && role != "WAITER" && !isAdmin);
    if (denied)
    {
        ctx.Response.StatusCode = StatusCodes.Status403Forbidden;
        await ctx.Response.WriteAsJsonAsync(new { success = false, message = "Bạn không có quyền thực hiện thao tác này" });
        return;
    }
    await next();
});
app.MapControllers();
app.Run();
