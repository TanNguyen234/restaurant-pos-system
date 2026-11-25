using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;
using WebApi.Models;

namespace WebApi.Services;

public class JwtTokenService
{
    private readonly IConfiguration _config;

    public JwtTokenService(IConfiguration config)
    {
        _config = config;
    }

    public static string ResolveSigningKey(IConfiguration config)
    {
        var key = config["Jwt:Key"] ?? config["APP_JWT_SECRET"];
        if (string.IsNullOrWhiteSpace(key) || Encoding.UTF8.GetByteCount(key) < 32)
        {
            throw new InvalidOperationException("Jwt:Key (hoặc APP_JWT_SECRET) phải được cấu hình tối thiểu 32 bytes trong .env hoặc biến môi trường.");
        }
        return key;
    }

    public string GenerateToken(Account account, string roleCode, string? roleName = null)
    {
        var jwtSettings = _config.GetSection("Jwt");
        var secretKey = ResolveSigningKey(_config);
        var issuer = jwtSettings["Issuer"] ?? "RestaurantPosApi";
        var audience = jwtSettings["Audience"] ?? "RestaurantPosClients";
        var expireMinutes = int.TryParse(jwtSettings["ExpireMinutes"], out var m) ? m : 1440;

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, account.AccountId.ToString()),
            new(ClaimTypes.Name, account.Username),
            new("accountId", account.AccountId.ToString()),
            new("username", account.Username),
            new("fullName", account.FullName),
            new(ClaimTypes.Role, roleCode),
            new("role", roleCode),
            new("roleId", account.RoleId.ToString())
        };

        if (!string.IsNullOrEmpty(account.Email))
        {
            claims.Add(new Claim(ClaimTypes.Email, account.Email));
        }

        if (!string.IsNullOrEmpty(roleName))
        {
            claims.Add(new Claim("roleName", roleName));
        }

        // Canonical role aliases for RBAC attributes
        if (roleCode is "HEAD_CHEF" or "BARISTA_LEAD" or "COOK_ASSISTANT")
        {
            claims.Add(new Claim(ClaimTypes.Role, "KITCHEN"));
        }
        else if (roleCode == "VIP_MEMBER")
        {
            claims.Add(new Claim(ClaimTypes.Role, "MEMBER"));
        }

        var token = new JwtSecurityToken(
            issuer: issuer,
            audience: audience,
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(expireMinutes),
            signingCredentials: creds
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
