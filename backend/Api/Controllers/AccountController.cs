using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Models;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AccountController : BaseController
{
    [HttpGet("members")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public async Task<IActionResult> GetMembers([FromQuery] int? roleId = null)
    {
        var members = await Provider.Account.GetMembersAsync(roleId);
        return Ok(members);
    }

    [HttpPut("{id:int}/role")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public async Task<IActionResult> UpdateRole(int id, [FromBody] UpdateRoleRequest request)
    {
        if (request == null || request.RoleId <= 0)
        {
            return BadRequest(new { success = false, message = "Vui lòng chọn vai trò hợp lệ" });
        }

        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("accountId");
        int.TryParse(idClaim, out int actorAccountId);
        string actorRoleCode = User.FindFirstValue("role") ?? User.FindFirstValue(ClaimTypes.Role) ?? "";

        var result = await Provider.Account.UpdateRoleAsync(id, request.RoleId, actorAccountId, actorRoleCode);
        if (!result.Success)
        {
            if (result.Message.Contains("ADMIN", StringComparison.OrdinalIgnoreCase) ||
                result.Message.Contains("quyền", StringComparison.OrdinalIgnoreCase))
            {
                return StatusCode(StatusCodes.Status403Forbidden, new { success = false, message = result.Message });
            }
            return BadRequest(new { success = false, message = result.Message });
        }

        return Ok(new { success = true, message = result.Message });
    }

    [HttpPut("{id:int}/status")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> UpdateStatus(int id, [FromBody] UpdateAccountStatusRequest request)
    {
        if (request == null)
        {
            return BadRequest(new { success = false, message = "Dữ liệu trạng thái tài khoản không hợp lệ" });
        }

        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("accountId");
        int.TryParse(idClaim, out int actorAccountId);

        var result = await Provider.Account.UpdateStatusAsync(id, request.IsActive, actorAccountId);
        if (!result.Success)
        {
            return BadRequest(new { success = false, message = result.Message });
        }

        return Ok(new { success = true, message = result.Message, isActive = request.IsActive });
    }

    [HttpGet("profile")]
    [Authorize]
    public async Task<IActionResult> GetProfile()
    {
        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("accountId");
        Account? account = int.TryParse(idClaim, out int accountId) && accountId > 0
            ? await Provider.Account.GetByIdAsync(accountId)
            : (!string.IsNullOrEmpty(User.Identity?.Name)
                ? await Provider.Account.GetByUsernameAsync(User.Identity.Name)
                : null);

        if (account == null)
        {
            return NotFound(new { statusCode = 404, success = false, message = "Không tìm thấy thông tin tài khoản" });
        }

        var role = await Provider.Account.GetRoleByIdAsync(account.RoleId);
        return Ok(new AccountDto
        {
            AccountId = account.AccountId,
            RoleId = account.RoleId,
            RoleCode = role?.RoleCode ?? "MEMBER",
            RoleName = role?.RoleName ?? "Thành viên",
            Username = account.Username,
            FullName = account.FullName,
            Email = account.Email,
            PhoneNumber = account.PhoneNumber,
            Avatar = account.Avatar,
            IsActive = account.IsActive,
            IsEmailVerified = account.IsEmailVerified,
            OAuthProvider = account.OAuthProvider,
            LoyaltyPoints = account.LoyaltyPoints,
            CreatedAt = account.CreatedAt,
            UpdatedAt = account.UpdatedAt
        });
    }

    [HttpPut("profile")]
    [Authorize]
    public async Task<IActionResult> UpdateProfile([FromBody] UpdateProfileDto dto)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(new { success = false, message = "Thông tin hồ sơ không hợp lệ", errors = ModelState });
        }

        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("accountId");
        if (!int.TryParse(idClaim, out int accountId) || accountId <= 0)
        {
            return Unauthorized(new { success = false, message = "Không xác định được danh tính người dùng" });
        }

        var res = await Provider.Account.UpdateProfileAsync(accountId, dto);
        if (!res.Success)
        {
            return BadRequest(new { success = false, message = res.Message });
        }

        return Ok(new { success = true, message = res.Message });
    }

    [HttpGet("roles")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public async Task<IActionResult> GetRoles()
    {
        var roles = await Provider.Account.GetRolesAsync();
        return Ok(roles);
    }
}
