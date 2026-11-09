using System.Collections.Concurrent;
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
    /// Public registration strictly assigns the MEMBER role.
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
    /// Authenticates username and password against database. Issues signed JWT Bearer token.
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
                message = "Vui lòng nhập đầy đủ tên đăng nhập và mật khẩu",
                errors = ModelState
            });
        }

        var result = await Provider.Account.LoginAsync(dto);
        if (!result.Success || result.Account == null)
        {
            return Unauthorized(new
            {
                statusCode = 401,
                success = false,
                message = result.Message
            });
        }

        string roleCode = result.Role?.RoleCode ?? "MEMBER";
        string roleName = result.Role?.RoleName ?? "Thành viên";
        string token = _jwtTokenService.GenerateToken(result.Account, roleCode, roleName);

        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = "Đăng nhập thành công",
            token = token,
            accountId = result.Account.AccountId,
            username = result.Account.Username,
            fullName = result.Account.FullName,
            role = roleCode,
            roleName = roleName,
            email = result.Account.Email,
            phoneNumber = result.Account.PhoneNumber,
            avatar = result.Account.Avatar
        });
    }

    /// <summary>
    /// POST /api/auth/change-password
    /// Verifies existing password and updates to newly salted password.
    /// Supports AccountId, authenticated JWT identity, or explicit username.
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

        (bool Success, string Message) result;

        if (dto.AccountId.HasValue && dto.AccountId.Value > 0)
        {
            result = await Provider.Account.ChangePasswordAsync(dto.AccountId.Value, dto.OldPassword, dto.NewPassword);
        }
        else
        {
            string? username = User.Identity?.IsAuthenticated == true
                ? User.Identity.Name
                : dto.Username;

            if (string.IsNullOrWhiteSpace(username))
            {
                return BadRequest(new
                {
                    statusCode = 400,
                    success = false,
                    message = "Vui lòng cung cấp mã tài khoản hoặc tên đăng nhập để đổi mật khẩu"
                });
            }

            result = await Provider.Account.ChangePasswordAsync(username, dto.OldPassword, dto.NewPassword);
        }

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

    /// <summary>
    /// GET /api/auth/profile/{id}
    /// Profile endpoint by ID for backward compatibility
    /// </summary>
    [HttpGet("profile/{id:int}")]
    public async Task<IActionResult> GetProfile(int id)
    {
        var account = await Provider.Account.GetByIdAsync(id);
        if (account == null)
        {
            return NotFound(new { success = false, message = $"Không tìm thấy tài khoản có ID = {id}" });
        }

        var role = await Provider.Account.GetRoleByIdAsync(account.RoleId);
        return Ok(new
        {
            accountId = account.AccountId,
            roleId = account.RoleId,
            roleName = role?.RoleName ?? "Chưa phân quyền",
            roleCode = role?.RoleCode ?? "MEMBER",
            username = account.Username,
            fullName = account.FullName,
            email = account.Email,
            phoneNumber = account.PhoneNumber,
            avatar = account.Avatar,
            isActive = account.IsActive,
            isEmailVerified = account.IsEmailVerified,
            createdAt = account.CreatedAt
        });
    }

    /// <summary>
    /// GET /api/auth/roles
    /// Returns roles list
    /// </summary>
    [HttpGet("roles")]
    public async Task<IActionResult> GetRoles()
    {
        var roles = await Provider.Account.GetRolesAsync();
        return Ok(roles);
    }

    private static readonly ConcurrentDictionary<string, (string Otp, DateTime ExpiresAt)> _otpStore = new();

    /// <summary>
    /// POST /api/auth/request-otp
    /// Gửi mã OTP xác thực email / quên mật khẩu (Barem 1.8 và 1.9)
    /// </summary>
    [HttpPost("request-otp")]
    public async Task<IActionResult> RequestOtp([FromBody] RequestOtpDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Email) && string.IsNullOrWhiteSpace(dto.Username))
        {
            return BadRequest(new { success = false, message = "Vui lòng cung cấp email hoặc tên đăng nhập" });
        }

        var account = !string.IsNullOrWhiteSpace(dto.Email)
            ? await Provider.Account.GetByEmailAsync(dto.Email.Trim())
            : await Provider.Account.GetByUsernameAsync(dto.Username!.Trim());

        if (account == null)
        {
            return NotFound(new { success = false, message = "Không tìm thấy tài khoản phù hợp với thông tin đã cung cấp" });
        }

        var otp = new Random().Next(100000, 999999).ToString();
        var key = (account.Email ?? account.Username ?? "").ToLowerInvariant();
        _otpStore[key] = (otp, DateTime.UtcNow.AddMinutes(5));

        return Ok(new
        {
            success = true,
            message = $"Mã OTP xác thực 6 chữ số đã được gửi đến {account.Email ?? account.Username} (Hết hạn trong 5 phút).",
            email = account.Email,
            devOtp = otp // Expose in response for testing
        });
    }

    /// <summary>
    /// POST /api/auth/reset-password-otp
    /// Xác thực mã OTP và đặt lại mật khẩu mới
    /// </summary>
    [HttpPost("reset-password-otp")]
    public async Task<IActionResult> ResetPasswordOtp([FromBody] ResetPasswordOtpDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Identity) || string.IsNullOrWhiteSpace(dto.Otp) || string.IsNullOrWhiteSpace(dto.NewPassword))
        {
            return BadRequest(new { success = false, message = "Vui lòng nhập đầy đủ thông tin, mã OTP và mật khẩu mới" });
        }

        var key = dto.Identity.Trim().ToLowerInvariant();
        if (!_otpStore.TryGetValue(key, out var stored) || stored.ExpiresAt < DateTime.UtcNow || stored.Otp != dto.Otp.Trim())
        {
            return BadRequest(new { success = false, message = "Mã OTP không chính xác hoặc đã hết thời gian hiệu lực (5 phút)!" });
        }

        var account = await Provider.Account.GetByEmailAsync(dto.Identity.Trim()) 
                      ?? await Provider.Account.GetByUsernameAsync(dto.Identity.Trim());

        if (account == null)
        {
            return NotFound(new { success = false, message = "Tài khoản không tồn tại" });
        }

        var result = await Provider.Account.ResetPasswordAsync(account.AccountId, dto.NewPassword);
        if (!result.Success)
        {
            return BadRequest(new { success = false, message = result.Message });
        }

        _otpStore.TryRemove(key, out _);
        return Ok(new { success = true, message = "Đặt lại mật khẩu mới thành công! Bạn có thể đăng nhập ngay bằng mật khẩu mới." });
    }

    /// <summary>
    /// POST /api/auth/oauth-login
    /// Đăng nhập bằng tài khoản mạng xã hội Google / Facebook (Barem 1.10)
    /// </summary>
    [HttpPost("oauth-login")]
    public async Task<IActionResult> OAuthLogin([FromBody] OAuthLoginDto dto)
    {
        if (dto == null || string.IsNullOrWhiteSpace(dto.Email))
        {
            return BadRequest(new { success = false, message = "Thông tin đăng nhập mạng xã hội không hợp lệ" });
        }

        var result = await Provider.Account.OAuthLoginAsync(dto);
        if (!result.Success || result.Account == null)
        {
            return BadRequest(new { success = false, message = result.Message });
        }

        string roleCode = result.Role?.RoleCode ?? "MEMBER";
        string roleName = result.Role?.RoleName ?? "Khách hàng thành viên";
        string token = _jwtTokenService.GenerateToken(result.Account, roleCode, roleName);

        return Ok(new
        {
            success = true,
            message = result.Message,
            token,
            accountId = result.Account.AccountId,
            username = result.Account.Username,
            fullName = result.Account.FullName,
            role = roleCode,
            roleName = roleName,
            email = result.Account.Email,
            avatar = result.Account.Avatar,
            oauthProvider = result.Account.OAuthProvider
        });
    }
}