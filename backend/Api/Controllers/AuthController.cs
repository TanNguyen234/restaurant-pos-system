using System.Net;
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
    private readonly OAuthProviderService _oauthService;

    public AuthController(
        JwtTokenService jwtTokenService,
        EmailService emailService,
        OAuthProviderService oauthService)
    {
        _jwtTokenService = jwtTokenService;
        _emailService = emailService;
        _oauthService = oauthService;
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

    public record OAuthExchangeDto(string? Ticket);

    /// <summary>
    /// GET /api/auth/oauth/providers - Kiểm tra trạng thái cấu hình OAuth 2.0 (Google / Facebook / Zalo)
    /// </summary>
    [HttpGet("oauth/providers")]
    [AllowAnonymous]
    public IActionResult GetOAuthProviders()
    {
        return Ok(new
        {
            success = true,
            providers = _oauthService.GetConfiguredProviders()
        });
    }

    /// <summary>
    /// GET /api/auth/oauth/{provider}/start - Khởi tạo luồng OAuth 2.0 Authorization Code + PKCE
    /// </summary>
    [HttpGet("oauth/{provider}/start")]
    [AllowAnonymous]
    public IActionResult StartOAuth(
        string provider,
        [FromQuery] string? clientRedirect = null,
        [FromQuery] string? pollKey = null)
    {
        var (isValidRedirect, validatedRedirect) = _oauthService.ValidateClientRedirect(clientRedirect);
        if (!isValidRedirect)
        {
            return BadRequest(new
            {
                statusCode = 400,
                success = false,
                message = "clientRedirect không hợp lệ hoặc không thuộc danh sách origin cho phép."
            });
        }

        var result = _oauthService.CreateAuthorizationUrl(provider, validatedRedirect, pollKey);
        if (!result.Success || string.IsNullOrWhiteSpace(result.AuthUrl))
        {
            _oauthService.StorePollError(pollKey, result.ErrorMessage ?? "OAuth chưa được cấu hình.");

            var accept = Request.Headers.Accept.ToString();
            if (accept.Contains("text/html", StringComparison.OrdinalIgnoreCase))
            {
                var missingBadges = result.MissingKeys.Count > 0
                    ? string.Join("", result.MissingKeys.Select(k => $"<li><code>{WebUtility.HtmlEncode(k)}</code></li>"))
                    : "<li><code>GOOGLE_CLIENT_ID / FACEBOOK_APP_ID / ZALO_APP_ID</code></li>";

                var backLink = validatedRedirect != null
                    ? $"<p style=\"margin-top:20px;\"><a href=\"{WebUtility.HtmlEncode(validatedRedirect)}\" style=\"color:#2563eb;text-decoration:none;font-weight:600;\">&larr; Quay lại ứng dụng POS</a></p>"
                    : "";

                var html = $"""
                    <!DOCTYPE html>
                    <html lang="vi">
                    <head><meta charset="utf-8" /><title>OAuth chưa cấu hình</title></head>
                    <body style="font-family:Segoe UI,Arial,sans-serif;background:#f8fafc;color:#0f172a;padding:32px;">
                      <div style="max-width:560px;margin:0 auto;background:#fff;border:1px solid #e2e8f0;border-radius:12px;padding:28px;">
                        <h2 style="margin-top:0;color:#b91c1c;">Nhà cung cấp OAuth chưa được cấu hình</h2>
                        <p>{WebUtility.HtmlEncode(result.ErrorMessage ?? "Thiếu biến môi trường OAuth.")}</p>
                        <p>Các biến môi trường cần thiết trong <code>.env</code>:</p>
                        <ul style="background:#f1f5f9;padding:12px 28px;border-radius:8px;">{missingBadges}</ul>
                        <p style="font-size:13px;color:#475569;">Callback URI: <code>{WebUtility.HtmlEncode(result.CallbackUrl)}</code></p>
                        {backLink}
                      </div>
                    </body>
                    </html>
                    """;

                return new ContentResult
                {
                    Content = html,
                    ContentType = "text/html; charset=utf-8",
                    StatusCode = StatusCodes.Status503ServiceUnavailable
                };
            }

            return StatusCode(StatusCodes.Status503ServiceUnavailable, new
            {
                statusCode = 503,
                success = false,
                message = result.ErrorMessage,
                missingEnvKeys = result.MissingKeys,
                callbackUrl = result.CallbackUrl
            });
        }

        return Redirect(result.AuthUrl);
    }

    /// <summary>
    /// GET /api/auth/oauth/{provider}/callback - Xử lý callback OAuth 2.0 từ Google / Facebook / Zalo
    /// </summary>
    [HttpGet("oauth/{provider}/callback")]
    [AllowAnonymous]
    public async Task<IActionResult> OAuthCallback(
        string provider,
        [FromQuery] string? code = null,
        [FromQuery] string? state = null,
        [FromQuery] string? error = null)
    {
        var cbResult = await _oauthService.HandleCallbackAsync(provider, code, state, error);
        var (_, safeRedirect) = _oauthService.ValidateClientRedirect(cbResult.ClientRedirect);

        if (!cbResult.Success || cbResult.Profile == null)
        {
            var errMsg = cbResult.ErrorMessage ?? "Xác thực OAuth thất bại.";
            _oauthService.StorePollError(cbResult.PollKey, errMsg);
            return BuildOAuthHtmlResult(StatusCodes.Status400BadRequest, "Đăng nhập OAuth thất bại", errMsg, safeRedirect);
        }

        var loginResult = await Provider.Account.OAuthLoginAsync(cbResult.Profile);
        if (!loginResult.Success || loginResult.Account == null)
        {
            _oauthService.StorePollError(cbResult.PollKey, loginResult.Message);
            return BuildOAuthHtmlResult(StatusCodes.Status403Forbidden, "Không thể hoàn tất đăng nhập", loginResult.Message, safeRedirect);
        }

        string roleCode = loginResult.Role?.RoleCode ?? "MEMBER";
        string roleName = loginResult.Role?.RoleName ?? "Khách hàng thành viên";
        string token = _jwtTokenService.GenerateToken(loginResult.Account, roleCode, roleName);

        var authPayload = new
        {
            statusCode = 200,
            success = true,
            message = loginResult.Message,
            token,
            accountId = loginResult.Account.AccountId,
            roleId = loginResult.Account.RoleId,
            roleCode,
            role = roleCode,
            roleName,
            username = loginResult.Account.Username,
            fullName = loginResult.Account.FullName,
            email = loginResult.Account.Email,
            phoneNumber = loginResult.Account.PhoneNumber,
            avatar = loginResult.Account.Avatar,
            loyaltyPoints = loginResult.Account.LoyaltyPoints,
            isEmailVerified = loginResult.Account.IsEmailVerified,
            oauthProvider = loginResult.Account.OAuthProvider
        };

        string ticket = _oauthService.StoreAuthTicket(authPayload, cbResult.PollKey);

        if (!string.IsNullOrWhiteSpace(safeRedirect))
        {
            return Redirect($"{safeRedirect.TrimEnd('/')}/?oauthTicket={Uri.EscapeDataString(ticket)}");
        }

        return BuildOAuthHtmlResult(
            StatusCodes.Status200OK,
            "Đăng nhập thành công",
            "Đăng nhập thành công! Bạn có thể đóng tab trình duyệt và quay lại ứng dụng POS.",
            null);
    }

    /// <summary>
    /// GET /api/auth/oauth/poll/{pollKey} - Kiểm tra trạng thái ticket cho Desktop/Mobile loopback polling
    /// </summary>
    [HttpGet("oauth/poll/{pollKey}")]
    [AllowAnonymous]
    public IActionResult PollOAuthTicket(string pollKey)
    {
        return Ok(_oauthService.PollTicket(pollKey));
    }

    /// <summary>
    /// POST /api/auth/oauth/exchange - Đổi OAuth ticket dùng 1 lần lấy JWT & thông tin tài khoản
    /// </summary>
    [HttpPost("oauth/exchange")]
    [AllowAnonymous]
    public IActionResult ExchangeOAuthTicket([FromBody] OAuthExchangeDto? dto)
    {
        if (dto == null || string.IsNullOrWhiteSpace(dto.Ticket))
        {
            return BadRequest(new
            {
                statusCode = 400,
                success = false,
                message = "Phiên xác thực OAuth không hợp lệ hoặc đã hết hạn."
            });
        }

        var payload = _oauthService.ConsumeTicket(dto.Ticket);
        if (payload == null)
        {
            return BadRequest(new
            {
                statusCode = 400,
                success = false,
                message = "Phiên xác thực OAuth không hợp lệ hoặc đã hết hạn."
            });
        }

        return Ok(payload);
    }

    /// <summary>
    /// POST /api/auth/oauth-login (Legacy mock endpoint disabled)
    /// </summary>
    [HttpPost("oauth-login")]
    [AllowAnonymous]
    public IActionResult OAuthLogin([FromBody] OAuthLoginDto? dto = null)
    {
        return BadRequest(new
        {
            statusCode = 400,
            success = false,
            message = "Đăng nhập giả lập đã bị tắt. Vui lòng sử dụng luồng OAuth 2.0 thật qua /api/auth/oauth/{provider}/start."
        });
    }

    private static ContentResult BuildOAuthHtmlResult(int statusCode, string title, string message, string? backRedirect)
    {
        bool isError = statusCode >= 400;
        string headingColor = isError ? "#b91c1c" : "#15803d";
        string backLink = !string.IsNullOrWhiteSpace(backRedirect)
            ? $"<p style=\"margin-top:20px;\"><a href=\"{WebUtility.HtmlEncode(backRedirect)}\" style=\"color:#2563eb;text-decoration:none;font-weight:600;\">&larr; Quay lại ứng dụng POS</a></p>"
            : "";

        string html = $"""
            <!DOCTYPE html>
            <html lang="vi">
            <head><meta charset="utf-8" /><title>{WebUtility.HtmlEncode(title)}</title></head>
            <body style="font-family:Segoe UI,Arial,sans-serif;background:#f8fafc;color:#0f172a;padding:32px;">
              <div style="max-width:520px;margin:0 auto;background:#fff;border:1px solid #e2e8f0;border-radius:12px;padding:28px;">
                <h2 style="margin-top:0;color:{headingColor};">{WebUtility.HtmlEncode(title)}</h2>
                <p style="line-height:1.6;">{WebUtility.HtmlEncode(message)}</p>
                {backLink}
              </div>
            </body>
            </html>
            """;

        return new ContentResult
        {
            Content = html,
            ContentType = "text/html; charset=utf-8",
            StatusCode = statusCode
        };
    }
}
