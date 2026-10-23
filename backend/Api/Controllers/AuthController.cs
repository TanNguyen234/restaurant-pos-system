using Microsoft.AspNetCore.Mvc;
using WebApi.Models;
using WebApi.Services;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : BaseController
{
    private readonly JwtTokenService _jwtTokenService;

    public AuthController(JwtTokenService jwtTokenService)
    {
        _jwtTokenService = jwtTokenService;
    }

    /// <summary>
    /// POST /api/auth/register
    /// Registers a new user account with SHA-256 + salt password hashing.
    /// </summary>
    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterDto dto)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(new
            {
                statusCode = 400,
                success = false,
                message = "Dữ liệu đăng ký không hợp lệ",
                errors = ModelState
            });
        }

        var result = await Provider.Account.RegisterAsync(dto);
        if (!result.Success)
        {
            return BadRequest(new
            {
                statusCode = 400,
                success = false,
                message = result.Message,
                error = result.Message
            });
        }

        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = result.Message,
            accountId = result.Account!.AccountId,
            username = result.Account.Username
        });
    }

    /// <summary>
    /// POST /api/auth/login
    /// Authenticates user and generates signed JWT Bearer token with RBAC role claims.
    /// </summary>
    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginDto dto)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(new
            {
                statusCode = 400,
                success = false,
                message = "Vui lòng nhập tên đăng nhập và mật khẩu",
                errors = ModelState
            });
        }

        var result = await Provider.Account.LoginAsync(dto);
        if (!result.Success)
        {
            return Unauthorized(new
            {
                statusCode = 401,
                success = false,
                message = result.Message,
                error = result.Message
            });
        }

        var account = result.Account!;
        var roleCode = result.Role?.RoleCode ?? "MEMBER";
        var roleName = result.Role?.RoleName ?? "Khách hàng thân thiết";

        string token = _jwtTokenService.GenerateToken(account, roleCode, roleName);

        return Ok(new LoginResponseDto
        {
            Token = token,
            AccountId = account.AccountId,
            Username = account.Username,
            FullName = account.FullName,
            Role = roleCode,
            RoleName = roleName,
            Email = account.Email,
            PhoneNumber = account.PhoneNumber,
            Avatar = account.Avatar
        });
    }

    /// <summary>
    /// POST /api/auth/change-password
    /// Verifies existing password and updates to newly salted password.
    /// Accepts authenticated JWT claims or explicit username.
    /// </summary>
    [HttpPost("change-password")]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordDto dto)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(new
            {
                statusCode = 400,
                success = false,
                message = "Dữ liệu đổi mật khẩu không hợp lệ",
                errors = ModelState
            });
        }

        string? username = User.Identity?.IsAuthenticated == true
            ? User.Identity.Name
            : dto.Username;

        if (string.IsNullOrWhiteSpace(username))
        {
            return BadRequest(new
            {
                statusCode = 400,
                success = false,
                message = "Vui lòng cung cấp tên đăng nhập hoặc đăng nhập trước khi đổi mật khẩu"
            });
        }

        var result = await Provider.Account.ChangePasswordAsync(username, dto.OldPassword, dto.NewPassword);
        if (!result.Success)
        {
            return BadRequest(new
            {
                statusCode = 400,
                success = false,
                message = result.Message,
                error = result.Message
            });
        }

        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = result.Message
        });
    }
}
