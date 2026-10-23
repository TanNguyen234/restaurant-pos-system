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

    public string GenerateToken(Account account, string roleCode, string? roleName = null)
    {
        var jwtSettings = _config.GetSection("Jwt");
        var secretKey = jwtSettings["Key"] ?? "RestaurantPosSecretKeyForJwtAuthentication2026!@#$%^&*()_+";
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

        // Support KITCHEN role alias: HEAD_CHEF, BARISTA_LEAD, and COOK_ASSISTANT also emit KITCHEN claim
        if (roleCode is "HEAD_CHEF" or "BARISTA_LEAD" or "COOK_ASSISTANT")
        {
            claims.Add(new Claim(ClaimTypes.Role, "KITCHEN"));
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
