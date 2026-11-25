using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Models;
using WebApi.Services;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : BaseController
{
    private readonly JwtTokenService _jwtTokenService;
    private readonly EmailService _emailService;

    public AuthController(JwtTokenService jwtTokenService, EmailService emailService)
    {
        _jwtTokenService = jwtTokenService;
        _emailService = emailService;
    }

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
        if (!result.Success || result.Account == null)
        {
            return BadRequest(new
            {
                statusCode = 400,
                success = false,
                message = result.Message,
                error = result.Message
            });
        }

        bool emailSent = false;
        string emailNotice = "";
        if (!string.IsNullOrWhiteSpace(result.Account.Email) && !string.IsNullOrWhiteSpace(result.EmailOtp))
        {
            var sendResult = await _emailService.SendOtpEmailAsync(
                result.Account.Email,
                "[Bistro POS] Mã OTP xác thực Email tài khoản",
                result.Account.FullName,
                result.EmailOtp,
                "Xác thực địa chỉ Email");
            emailSent = sendResult.Sent;
            emailNotice = sendResult.Message;
        }

        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = result.Message,
            accountId = result.Account.AccountId,
            username = result.Account.Username,
            requiresEmailVerification = !string.IsNullOrWhiteSpace(result.Account.Email),
            emailSent,
            emailNotice
        });
    }

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
            token,
            accountId = result.Account.AccountId,
            roleId = result.Account.RoleId,
            username = result.Account.Username,
            fullName = result.Account.FullName,
            role = roleCode,
            roleName,
            email = result.Account.Email,
            phoneNumber = result.Account.PhoneNumber,
            avatar = result.Account.Avatar,
            isEmailVerified = result.Account.IsEmailVerified,
            loyaltyPoints = result.Account.LoyaltyPoints
        });
    }

    [HttpPost("logout")]
    [Authorize]
    public IActionResult Logout()
    {
        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = "Đăng xuất phiên làm việc thành công"
        });
    }

    [HttpPost("change-password")]
    [Authorize]
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

        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("accountId");
        if (!int.TryParse(idClaim, out int actorAccountId) || actorAccountId <= 0)
        {
            return Unauthorized(new { statusCode = 401, success = false, message = "Phiên đăng nhập không hợp lệ" });
        }

        var result = await Provider.Account.ChangePasswordAsync(actorAccountId, dto.OldPassword, dto.NewPassword);
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

    [HttpGet("profile/{id:int}")]
    [Authorize]
    public async Task<IActionResult> GetProfile(int id)
    {
        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("accountId");
        int.TryParse(idClaim, out int actorId);
        bool isPrivileged = User.IsInRole("ADMIN") || User.IsInRole("MANAGER");
        if (!isPrivileged && actorId != id)
        {
            return Forbid();
        }

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
            loyaltyPoints = account.LoyaltyPoints,
            createdAt = account.CreatedAt
        });
    }

    [HttpGet("roles")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public async Task<IActionResult> GetRoles()
    {
        var roles = await Provider.Account.GetRolesAsync();
        return Ok(roles);
    }

    /// <summary>
    /// POST /api/auth/request-email-verification (Barem 1.8)
    /// </summary>
    [HttpPost("request-email-verification")]
    public async Task<IActionResult> RequestEmailVerification([FromBody] RequestOtpDto dto)
    {
        string? identity = !string.IsNullOrWhiteSpace(dto?.Email) ? dto.Email : dto?.Username;
        if (string.IsNullOrWhiteSpace(identity))
        {
            return BadRequest(new { success = false, message = "Vui lòng cung cấp email hoặc tên đăng nhập" });
        }

        var issued = await Provider.Account.IssueEmailVerificationOtpAsync(identity);
        if (!issued.Success || issued.Account == null || string.IsNullOrWhiteSpace(issued.Otp))
        {
            return BadRequest(new { success = false, message = issued.Message });
        }

        var sendRes = await _emailService.SendOtpEmailAsync(
            issued.Account.Email!,
            "[Bistro POS] Mã OTP xác thực Email",
            issued.Account.FullName,
            issued.Otp,
            "Xác thực địa chỉ Email");

        return Ok(new
        {
            success = true,
            emailSent = sendRes.Sent,
            message = sendRes.Sent
                ? sendRes.Message
                : $"Mã xác thực đã được tạo cho {EmailService.MaskEmail(issued.Account.Email!)}. {sendRes.Message}"
        });
    }

    /// <summary>
    /// POST /api/auth/verify-email (Barem 1.8)
    /// </summary>
    [HttpPost("verify-email")]
    public async Task<IActionResult> VerifyEmail([FromBody] VerifyEmailDto dto)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(new { success = false, message = "Vui lòng nhập đầy đủ tài khoản và mã OTP" });
        }

        var res = await Provider.Account.VerifyEmailOtpAsync(dto.Identity, dto.Otp);
        if (!res.Success)
        {
            return BadRequest(new { success = false, message = res.Message });
        }

        return Ok(new { success = true, message = res.Message });
    }

    /// <summary>
    /// POST /api/auth/request-otp (Barem 1.9 - Gửi qua SMTP thật & lưu DB, KHÔNG trả OTP ra HTTP)
    /// </summary>
    [HttpPost("request-otp")]
    public async Task<IActionResult> RequestOtp([FromBody] RequestOtpDto dto)
    {
        string? identity = !string.IsNullOrWhiteSpace(dto?.Email) ? dto.Email : dto?.Username;
        if (string.IsNullOrWhiteSpace(identity))
        {
            return BadRequest(new { success = false, message = "Vui lòng cung cấp email hoặc tên đăng nhập" });
        }

        var issued = await Provider.Account.IssuePasswordResetOtpAsync(identity);
        if (!issued.Success || issued.Account == null || string.IsNullOrWhiteSpace(issued.Otp))
        {
            return BadRequest(new { success = false, message = issued.Message });
        }

        var sendRes = await _emailService.SendOtpEmailAsync(
            issued.Account.Email!,
            "[Bistro POS] Mã OTP khôi phục mật khẩu",
            issued.Account.FullName,
            issued.Otp,
            "Khôi phục mật khẩu");

        return Ok(new
        {
            success = true,
            emailSent = sendRes.Sent,
            maskedEmail = EmailService.MaskEmail(issued.Account.Email!),
            message = sendRes.Sent
                ? $"Mã OTP 6 chữ số đã được gửi tới email {EmailService.MaskEmail(issued.Account.Email!)} (hiệu lực 5 phút)."
                : $"Không gửi được email SMTP ({sendRes.Message}). Vui lòng kiểm tra cấu hình SMTP."
        });
    }

    /// <summary>
    /// POST /api/auth/reset-password-otp (Barem 1.9)
    /// </summary>
    [HttpPost("reset-password-otp")]
    public async Task<IActionResult> ResetPasswordOtp([FromBody] ResetPasswordOtpDto dto)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(new { success = false, message = "Vui lòng nhập đầy đủ thông tin, mã OTP và mật khẩu mới (tối thiểu 6 ký tự)" });
        }

        var result = await Provider.Account.ResetPasswordWithOtpAsync(dto.Identity, dto.Otp, dto.NewPassword);
        if (!result.Success)
        {
            return BadRequest(new { success = false, message = result.Message });
        }

        return Ok(new { success = true, message = result.Message });
    }

    /// <summary>
    /// POST /api/auth/oauth-login (Google / Facebook / Zalo - Barem 1.10)
    /// </summary>
    [HttpPost("oauth-login")]
    public async Task<IActionResult> OAuthLogin([FromBody] OAuthLoginDto dto)
    {
        if (!ModelState.IsValid)
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
            roleId = result.Account.RoleId,
            username = result.Account.Username,
            fullName = result.Account.FullName,
            role = roleCode,
            roleName,
            email = result.Account.Email,
            phoneNumber = result.Account.PhoneNumber,
            avatar = result.Account.Avatar,
            isEmailVerified = result.Account.IsEmailVerified,
            loyaltyPoints = result.Account.LoyaltyPoints,
            oauthProvider = result.Account.OAuthProvider
        });
    }
}
