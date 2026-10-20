using Microsoft.AspNetCore.Mvc;
using WebApi.Models;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : BaseController
{
    /// <summary>
    /// POST /api/auth/login
    /// Đăng nhập tài khoản hệ thống POS và cấp token phiên làm việc
    /// </summary>
    [HttpPost("login")]
    public IActionResult Login([FromBody] LoginRequest request)
    {
        if (request == null || string.IsNullOrWhiteSpace(request.Username) || string.IsNullOrWhiteSpace(request.Password))
        {
            return BadRequest(new { success = false, message = "Vui lòng nhập đầy đủ tên đăng nhập và mật khẩu" });
        }

        var account = Provider.Account.Login(request.Username, request.Password);
        if (account == null)
        {
            return Unauthorized(new { success = false, message = "Tên đăng nhập hoặc mật khẩu không chính xác" });
        }

        var role = Provider.Account.GetRoleById(account.RoleId);
        string roleCode = role != null ? role.RoleCode : "USER";
        string roleName = role != null ? role.RoleName : "Người dùng";

        // Tạo chuỗi token phiên làm việc
        string token = $"pos_{Guid.NewGuid():N}_{account.AccountId}";

        return Ok(new
        {
            success = true,
            message = "Đăng nhập thành công",
            token = token,
            accountId = account.AccountId,
            roleId = account.RoleId,
            username = account.Username,
            fullName = account.FullName,
            role = roleCode,
            roleName = roleName,
            email = account.Email,
            phoneNumber = account.PhoneNumber,
            avatar = account.Avatar
        });
    }

    /// <summary>
    /// POST /api/auth/register
    /// Đăng ký tài khoản người dùng / nhân viên mới
    /// </summary>
    [HttpPost("register")]
    public IActionResult Register([FromBody] RegisterRequest request)
    {
        if (request == null)
        {
            return BadRequest(new { statusCode = 400, error = "Dữ liệu đăng ký không hợp lệ" });
        }

        var result = Provider.Account.Register(
            request.Username,
            request.Password,
            request.FullName,
            request.Email,
            request.PhoneNumber,
            request.RoleId ?? 4 // Mặc định Waiter / Member
        );

        if (!result.Success)
        {
            return BadRequest(new
            {
                statusCode = 400,
                error = result.Message
            });
        }

        return Ok(new
        {
            statusCode = 200,
            message = result.Message,
            accountId = result.Account!.AccountId,
            username = result.Account.Username,
            fullName = result.Account.FullName,
            roleId = result.Account.RoleId
        });
    }

    /// <summary>
    /// POST /api/auth/change-password
    /// Đổi mật khẩu tài khoản
    /// </summary>
    [HttpPost("change-password")]
    public IActionResult ChangePassword([FromBody] ChangePasswordRequest request)
    {
        if (request == null || request.AccountId <= 0)
        {
            return BadRequest(new { success = false, message = "Thông tin đổi mật khẩu không hợp lệ" });
        }

        var result = Provider.Account.ChangePassword(request.AccountId, request.OldPassword, request.NewPassword);
        if (!result.Success)
        {
            return BadRequest(new { success = false, message = result.Message });
        }

        return Ok(new { success = true, message = result.Message });
    }

    /// <summary>
    /// GET /api/auth/profile/{id}
    /// Lấy thông tin tài khoản
    /// </summary>
    [HttpGet("profile/{id:int}")]
    public IActionResult GetProfile(int id)
    {
        var account = Provider.Account.GetById(id);
        if (account == null)
        {
            return NotFound(new { success = false, message = $"Không tìm thấy tài khoản có ID = {id}" });
        }

        var role = Provider.Account.GetRoleById(account.RoleId);

        return Ok(new
        {
            accountId = account.AccountId,
            roleId = account.RoleId,
            roleName = role?.RoleName ?? "Chưa phân quyền",
            roleCode = role?.RoleCode ?? "USER",
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
    /// Lấy danh sách toàn bộ vai trò
    /// </summary>
    [HttpGet("roles")]
    public IActionResult GetRoles()
    {
        var roles = Provider.Account.GetRoles();
        return Ok(roles);
    }
}

public class LoginRequest
{
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

public class RegisterRequest
{
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string? Email { get; set; }
    public string? PhoneNumber { get; set; }
    public int? RoleId { get; set; }
}

public class ChangePasswordRequest
{
    public int AccountId { get; set; }
    public string OldPassword { get; set; } = string.Empty;
    public string NewPassword { get; set; } = string.Empty;
}
